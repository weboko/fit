import Foundation
import SwiftData

/// Restores the multi-CSV export (the files produced by `CSVExporter`) back into
/// the SwiftData store. This is the CSV counterpart to `DataImportService`'s JSON
/// restore and shares its `ImportSummary` / `ImportError` types.
///
/// SAFETY: like the JSON path, the import only ever INSERTS or UPDATES. It matches
/// every row against any existing object with the same `id` and updates it in
/// place, or inserts a new object with that id. It never deletes existing objects,
/// never clears relationships it cannot resolve, and continues past per-row
/// problems (recording a warning) rather than aborting the whole restore. Unknown
/// enum raw values fall back to each model's default via the typed accessors. No
/// SwiftUI here — a plain engine, safe to run on a background `ModelContext`.
final class CSVImportService {

    init() {}

    /// ISO-8601 parsing shared with the JSON path's conventions: the exporter uses
    /// `.withInternetDateTime` (no fractional seconds), but fractional seconds are
    /// also accepted so files from other tools / future versions still load.
    private enum DateParsing {
        static let iso8601: ISO8601DateFormatter = {
            let f = ISO8601DateFormatter()
            f.formatOptions = [.withInternetDateTime]
            return f
        }()
        static let iso8601Fractional: ISO8601DateFormatter = {
            let f = ISO8601DateFormatter()
            f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            return f
        }()

        static func date(_ string: String?) -> Date? {
            guard let string, !string.isEmpty else { return nil }
            if let d = iso8601.date(from: string) { return d }
            if let d = iso8601Fractional.date(from: string) { return d }
            return nil
        }
    }

    // MARK: - Public entry point

    /// Upsert the contents of the supplied CSV files into `context`, merging by id.
    /// `files` maps a filename (e.g. "sets.csv") → its raw text. Missing files are
    /// simply skipped. Throws only when no recognised file is present at all;
    /// per-row problems are collected as warnings. Saves the context on success.
    func importCSVFiles(_ files: [String: String], into context: ModelContext) throws -> ImportSummary {
        // Key the supplied files case-insensitively by their base filename.
        var byName: [String: String] = [:]
        for (name, text) in files {
            byName[name.lowercased()] = text
        }

        let recognised = [
            ExportFileName.exercises, ExportFileName.exerciseAliases,
            ExportFileName.healthWorkouts, ExportFileName.bodyWeight,
            ExportFileName.sleep, ExportFileName.workouts, ExportFileName.sets,
            ExportFileName.journalEntries
        ]
        guard recognised.contains(where: { byName[$0] != nil }) else {
            throw ImportError.unreadable("No recognised Fit CSV files were found in the selection.")
        }

        var summary = ImportSummary()

        // Surface (but do not skip) rows whose field count differs from the
        // header's: `parseKeyed` pads/truncates such rows, so the upsert still
        // runs, but a mismatch hints at a malformed file worth flagging.
        for name in recognised where byName[name] != nil {
            let malformed = malformedRowCount(byName[name]!)
            if malformed > 0 {
                summary.warnings.append("\(name): \(malformed) row(s) had a column count that did not match the header.")
            }
        }

        // Caches keyed by id, used to resolve relationships and avoid re-fetching.
        var exercisesById: [UUID: Exercise] = [:]
        var workoutsById: [UUID: WorkoutSession] = [:]
        // Health workouts indexed by their Apple Health UUID, since workouts.csv
        // links to a health workout by `apple_health_workout_id` (its HK UUID).
        var healthByAppleUUID: [String: HealthWorkout] = [:]

        // Upsert in dependency order so relationships always resolve to a present
        // object: exercises → aliases → health workouts → body weight / sleep →
        // workouts → sets → journal entries.
        if let text = byName[ExportFileName.exercises] {
            importExercises(rows(text), into: context, cache: &exercisesById, summary: &summary)
        }
        if let text = byName[ExportFileName.exerciseAliases] {
            importAliases(rows(text), into: context, exercisesById: exercisesById, summary: &summary)
        }
        if let text = byName[ExportFileName.healthWorkouts] {
            importHealthWorkouts(rows(text), into: context, cache: &healthByAppleUUID, summary: &summary)
        }
        if let text = byName[ExportFileName.bodyWeight] {
            importBodyWeight(rows(text), into: context, summary: &summary)
        }
        if let text = byName[ExportFileName.sleep] {
            importSleep(rows(text), into: context, summary: &summary)
        }
        if let text = byName[ExportFileName.workouts] {
            importWorkouts(rows(text), into: context, cache: &workoutsById, healthByAppleUUID: healthByAppleUUID, summary: &summary)
        }
        if let text = byName[ExportFileName.sets] {
            importSets(rows(text), into: context, workoutsById: workoutsById, exercisesById: exercisesById, summary: &summary)
        }
        if let text = byName[ExportFileName.journalEntries] {
            importJournal(rows(text), into: context, workoutsById: workoutsById, summary: &summary)
        }

        do {
            try context.save()
        } catch {
            summary.warnings.append("Some changes could not be saved: \(error.localizedDescription)")
        }

        return summary
    }

    // MARK: - Parsing helpers

    private func rows(_ text: String) -> [[String: String]] {
        CSVParser.parseKeyed(text)
    }

    /// Count data rows whose raw field count differs from the header's. Uses the
    /// raw `parse` output (not `parseKeyed`, which pads/truncates) so a genuine
    /// column-count mismatch can be reported as a warning without changing how
    /// the rows themselves are imported.
    private func malformedRowCount(_ text: String) -> Int {
        let raw = CSVParser.parse(text)
        guard let header = raw.first else { return 0 }
        return raw.dropFirst().reduce(into: 0) { count, row in
            if row.count != header.count { count += 1 }
        }
    }

    /// The raw string for a column, or nil when the column is missing or empty.
    /// Values are not trimmed: the exporter does not trim, so a round-trip keeps
    /// any meaningful leading/trailing whitespace in notes / names intact.
    private func string(_ row: [String: String], _ key: String) -> String? {
        guard let raw = row[key] else { return nil }
        return raw.isEmpty ? nil : raw
    }

    private func int(_ row: [String: String], _ key: String) -> Int? {
        guard let s = string(row, key) else { return nil }
        return Int(s)
    }

    private func double(_ row: [String: String], _ key: String) -> Double? {
        guard let s = string(row, key) else { return nil }
        return Double(s)
    }

    /// Parse a boolean column. Accepts "true"/"false" (the exporter's output) plus
    /// a few tolerant spellings; unknown values → nil.
    private func bool(_ row: [String: String], _ key: String) -> Bool? {
        guard let s = string(row, key)?.lowercased() else { return nil }
        switch s {
        case "true", "1", "yes": return true
        case "false", "0", "no": return false
        default: return nil
        }
    }

    private func date(_ row: [String: String], _ key: String) -> Date? {
        DateParsing.date(row[key])
    }

    private func uuid(_ row: [String: String], _ key: String) -> UUID? {
        guard let s = string(row, key) else { return nil }
        return UUID(uuidString: s)
    }

    // MARK: - Generic fetch-by-id

    private func fetchExisting<T: PersistentModel>(_ type: T.Type, in context: ModelContext, predicate: Predicate<T>) -> T? {
        var descriptor = FetchDescriptor<T>(predicate: predicate)
        descriptor.fetchLimit = 1
        return (try? context.fetch(descriptor))?.first
    }

    // MARK: - Exercises

    private func importExercises(_ rows: [[String: String]], into context: ModelContext, cache: inout [UUID: Exercise], summary: inout ImportSummary) {
        for row in rows {
            guard let id = uuid(row, "exercise_id") else {
                summary.warnings.append("Skipped an exercise with an invalid or missing id.")
                continue
            }
            let existing = fetchExisting(Exercise.self, in: context, predicate: #Predicate { $0.id == id })
            let exercise: Exercise
            if let existing {
                exercise = existing
                summary.updatedExercises += 1
            } else {
                exercise = Exercise(id: id)
                context.insert(exercise)
                summary.insertedExercises += 1
            }

            if let name = string(row, "canonical_name") { exercise.canonicalName = name }
            exercise.category = string(row, "category").flatMap(ExerciseCategory.init(rawValue:))
            exercise.equipment = string(row, "equipment").flatMap(Equipment.init(rawValue:))
            exercise.movementPattern = string(row, "movement_pattern").flatMap(MovementPattern.init(rawValue:))
            if let mode = string(row, "default_weight_mode").flatMap(WeightMode.init(rawValue:)) {
                exercise.defaultWeightMode = mode
            }
            if let primary = string(row, "primary_muscles") { exercise.primaryMusclesRaw = splitList(primary) }
            if let secondary = string(row, "secondary_muscles") { exercise.secondaryMusclesRaw = splitList(secondary) }
            if let notes = string(row, "notes") { exercise.notes = notes }
            if let archived = bool(row, "archived") { exercise.archived = archived }
            if let goal = bool(row, "is_goal_exercise") { exercise.isGoalExercise = goal }
            if let favorite = bool(row, "is_favorite") { exercise.isFavorite = favorite }
            if let created = date(row, "created_at") { exercise.createdAt = created }
            if let updated = date(row, "updated_at") { exercise.updatedAt = updated }

            cache[id] = exercise
        }
    }

    /// Split a `;`-joined muscle list (the exporter's format), dropping blanks.
    private func splitList(_ value: String) -> [String] {
        value.split(separator: ";", omittingEmptySubsequences: true).map(String.init)
    }

    // MARK: - Exercise aliases

    private func importAliases(_ rows: [[String: String]], into context: ModelContext, exercisesById: [UUID: Exercise], summary: inout ImportSummary) {
        for row in rows {
            guard let id = uuid(row, "alias_id") else {
                summary.warnings.append("Skipped an alias with an invalid or missing id.")
                continue
            }
            let existing = fetchExisting(ExerciseAlias.self, in: context, predicate: #Predicate { $0.id == id })
            let alias: ExerciseAlias
            if let existing {
                alias = existing
                summary.updatedAliases += 1
            } else {
                alias = ExerciseAlias(id: id)
                context.insert(alias)
                summary.insertedAliases += 1
            }
            if let name = string(row, "alias_name") { alias.aliasName = name }
            alias.languageOptional = string(row, "language_optional")
            if let created = date(row, "created_at") { alias.createdAt = created }

            // Resolve the parent exercise by id from the cache, else fetch it.
            if let exId = uuid(row, "exercise_id") {
                if let exercise = exercisesById[exId] {
                    alias.exercise = exercise
                } else if let exercise = fetchExisting(Exercise.self, in: context, predicate: #Predicate { $0.id == exId }) {
                    alias.exercise = exercise
                }
            }
        }
    }

    // MARK: - Health workouts

    private func importHealthWorkouts(_ rows: [[String: String]], into context: ModelContext, cache: inout [String: HealthWorkout], summary: inout ImportSummary) {
        for row in rows {
            guard let id = uuid(row, "health_workout_id") else {
                summary.warnings.append("Skipped a Health workout with an invalid or missing id.")
                continue
            }
            let existing = fetchExisting(HealthWorkout.self, in: context, predicate: #Predicate { $0.id == id })
            let health: HealthWorkout
            if let existing {
                health = existing
                summary.updatedHealthWorkouts += 1
            } else {
                health = HealthWorkout(id: id)
                context.insert(health)
                summary.insertedHealthWorkouts += 1
            }

            if let appleUUID = string(row, "apple_health_uuid") { health.appleHealthUUID = appleUUID }
            if let type = string(row, "workout_type") { health.workoutType = type }
            if let start = date(row, "start_time") { health.startTime = start }
            if let end = date(row, "end_time") { health.endTime = end }
            if let duration = double(row, "duration_seconds") { health.durationSeconds = duration }
            health.activeEnergyKcal = double(row, "active_energy_kcal")
            health.totalEnergyKcal = double(row, "total_energy_kcal")
            health.avgHeartRateBpm = double(row, "avg_heart_rate_bpm")
            health.minHeartRateBpm = double(row, "min_heart_rate_bpm")
            health.maxHeartRateBpm = double(row, "max_heart_rate_bpm")
            health.sourceName = string(row, "source_name")
            health.sourceDevice = string(row, "source_device")
            if let imported = date(row, "imported_at") { health.importedAt = imported }

            if !health.appleHealthUUID.isEmpty {
                cache[health.appleHealthUUID] = health
            }
        }
    }

    // MARK: - Body weight

    private func importBodyWeight(_ rows: [[String: String]], into context: ModelContext, summary: inout ImportSummary) {
        for row in rows {
            guard let id = uuid(row, "body_weight_entry_id") else {
                summary.warnings.append("Skipped a body-weight entry with an invalid or missing id.")
                continue
            }
            let existing = fetchExisting(BodyWeightEntry.self, in: context, predicate: #Predicate { $0.id == id })
            let entry: BodyWeightEntry
            if let existing {
                entry = existing
                summary.updatedBodyWeightEntries += 1
            } else {
                entry = BodyWeightEntry(id: id)
                context.insert(entry)
                summary.insertedBodyWeightEntries += 1
            }
            if let ts = date(row, "timestamp") { entry.timestamp = ts }
            if let weight = double(row, "weight_kg") { entry.weightKg = weight }
            if let source = string(row, "source").flatMap(DataSource.init(rawValue:)) { entry.source = source }
            entry.appleHealthSampleId = string(row, "apple_health_sample_id")
            if let notes = string(row, "notes") { entry.notes = notes }
        }
    }

    // MARK: - Sleep

    private func importSleep(_ rows: [[String: String]], into context: ModelContext, summary: inout ImportSummary) {
        for row in rows {
            guard let id = uuid(row, "sleep_entry_id") else {
                summary.warnings.append("Skipped a sleep entry with an invalid or missing id.")
                continue
            }
            let existing = fetchExisting(SleepEntry.self, in: context, predicate: #Predicate { $0.id == id })
            let entry: SleepEntry
            if let existing {
                entry = existing
                summary.updatedSleepEntries += 1
            } else {
                entry = SleepEntry(id: id)
                context.insert(entry)
                summary.insertedSleepEntries += 1
            }
            if let d = date(row, "date") { entry.date = d }
            entry.startTime = date(row, "start_time")
            entry.endTime = date(row, "end_time")
            entry.durationSeconds = double(row, "duration_seconds")
            if let source = string(row, "sleep_source").flatMap(DataSource.init(rawValue:)) { entry.source = source }
            entry.subjectiveSleepQuality = string(row, "subjective_sleep_quality").flatMap(SleepQuality.init(rawValue:))
            entry.appleHealthSampleId = string(row, "apple_health_sample_id")
            if let notes = string(row, "notes") { entry.notes = notes }
        }
    }

    // MARK: - Workouts

    private func importWorkouts(_ rows: [[String: String]], into context: ModelContext, cache: inout [UUID: WorkoutSession], healthByAppleUUID: [String: HealthWorkout], summary: inout ImportSummary) {
        for row in rows {
            guard let id = uuid(row, "workout_id") else {
                summary.warnings.append("Skipped a workout with an invalid or missing id.")
                continue
            }
            let existing = fetchExisting(WorkoutSession.self, in: context, predicate: #Predicate { $0.id == id })
            let workout: WorkoutSession
            if let existing {
                workout = existing
                summary.updatedWorkouts += 1
            } else {
                workout = WorkoutSession(id: id)
                context.insert(workout)
                summary.insertedWorkouts += 1
            }

            if let title = string(row, "title") { workout.title = title }
            if let start = date(row, "start_time") { workout.startTime = start }
            workout.endTime = date(row, "end_time")
            if let tz = string(row, "timezone") { workout.timezoneIdentifier = tz }
            if let backfilled = bool(row, "is_backfilled") { workout.isBackfilled = backfilled }

            workout.goal = string(row, "workout_goal").flatMap(WorkoutGoal.init(rawValue:))
            workout.location = string(row, "location").flatMap(WorkoutLocation.init(rawValue:))
            workout.energyBefore = int(row, "energy_before_0_5")
            workout.soreness = string(row, "soreness").flatMap(Soreness.init(rawValue:))
            workout.painToday = string(row, "pain_today").flatMap(PainToday.init(rawValue:))
            workout.sleepQualitySubjective = string(row, "sleep_quality_subjective").flatMap(SleepQuality.init(rawValue:))
            workout.stressLevel = int(row, "stress_0_5")
            workout.foodTiming = string(row, "food_timing").flatMap(FoodTiming.init(rawValue:))
            workout.caffeine = string(row, "caffeine").flatMap(Caffeine.init(rawValue:))
            workout.bodyWeightManualKg = double(row, "body_weight_kg_manual")
            if let notes = string(row, "notes") { workout.notes = notes }

            // Link the Apple Health workout by its HK UUID (workouts.csv stores the
            // health workout's `appleHealthUUID` in `apple_health_workout_id`).
            if let appleUUID = string(row, "apple_health_workout_id"),
               let health = healthByAppleUUID[appleUUID] {
                workout.linkedHealthWorkout = health
            }

            if let created = date(row, "created_at") { workout.createdAt = created }
            if let updated = date(row, "updated_at") { workout.updatedAt = updated }

            cache[id] = workout
        }
    }

    // MARK: - Sets

    private func importSets(_ rows: [[String: String]], into context: ModelContext, workoutsById: [UUID: WorkoutSession], exercisesById: [UUID: Exercise], summary: inout ImportSummary) {
        for row in rows {
            guard let id = uuid(row, "set_id") else {
                summary.warnings.append("Skipped a set with an invalid or missing id.")
                continue
            }
            let existing = fetchExisting(WorkoutSet.self, in: context, predicate: #Predicate { $0.id == id })
            let set: WorkoutSet
            if let existing {
                set = existing
                summary.updatedSets += 1
            } else {
                set = WorkoutSet(id: id)
                context.insert(set)
                summary.insertedSets += 1
            }

            if let name = string(row, "exercise_name_at_time") { set.exerciseNameAtTime = name }
            if let index = int(row, "set_index") { set.setIndex = index }
            if let ts = date(row, "timestamp") { set.timestamp = ts }
            if let mode = string(row, "weight_mode").flatMap(WeightMode.init(rawValue:)) { set.weightMode = mode }
            set.weightKg = double(row, "weight_kg")
            set.bodyWeightKg = double(row, "body_weight_kg")
            set.assistanceKg = double(row, "assistance_kg")
            set.addedWeightKg = double(row, "added_weight_kg")
            set.reps = int(row, "reps")
            set.effort = int(row, "effort_0_5")
            set.repsLeft = string(row, "reps_left").flatMap(RepsLeft.init(rawValue:))
            set.formQuality = string(row, "form_quality").flatMap(FormQuality.init(rawValue:))
            set.limiter = string(row, "limiter").flatMap(Limiter.init(rawValue:))
            set.painSeverity = string(row, "pain_severity").flatMap(PainSeverity.init(rawValue:))
            set.painLocation = string(row, "pain_location").flatMap(PainLocation.init(rawValue:))
            if let warmup = bool(row, "is_warmup") { set.isWarmup = warmup }
            if let failed = bool(row, "is_failed") { set.isFailed = failed }
            set.supersetGroup = int(row, "superset_group")
            if let source = string(row, "source").flatMap(RecordSource.init(rawValue:)) { set.source = source }
            if let notes = string(row, "notes") { set.notes = notes }
            if let created = date(row, "created_at") { set.createdAt = created }
            if let updated = date(row, "updated_at") { set.updatedAt = updated }

            // Resolve relationships by id from the caches built earlier.
            if let workoutId = uuid(row, "workout_id"), let workout = workoutsById[workoutId] {
                set.workout = workout
            }
            if let exId = uuid(row, "exercise_id"), let exercise = exercisesById[exId] {
                set.exercise = exercise
            }
        }
    }

    // MARK: - Journal entries

    private func importJournal(_ rows: [[String: String]], into context: ModelContext, workoutsById: [UUID: WorkoutSession], summary: inout ImportSummary) {
        for row in rows {
            guard let id = uuid(row, "journal_entry_id") else {
                summary.warnings.append("Skipped a journal entry with an invalid or missing id.")
                continue
            }
            let existing = fetchExisting(JournalEntry.self, in: context, predicate: #Predicate { $0.id == id })
            let entry: JournalEntry
            if let existing {
                entry = existing
                summary.updatedJournalEntries += 1
            } else {
                entry = JournalEntry(id: id)
                context.insert(entry)
                summary.insertedJournalEntries += 1
            }

            if let ts = date(row, "timestamp") { entry.timestamp = ts }
            if let type = string(row, "entry_type").flatMap(JournalEntryType.init(rawValue:)) { entry.entryType = type }
            if let text = string(row, "text") { entry.text = text }
            entry.exerciseIdOptional = uuid(row, "exercise_id_optional")
            entry.setIdOptional = uuid(row, "set_id_optional")
            if let created = date(row, "created_at") { entry.createdAt = created }
            if let updated = date(row, "updated_at") { entry.updatedAt = updated }

            if let workoutId = uuid(row, "workout_id"), let workout = workoutsById[workoutId] {
                entry.workout = workout
            }
        }
    }
}
