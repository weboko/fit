import Foundation
import SwiftData

/// Restores a previously exported `fit_export.json` back into the SwiftData store.
///
/// This is the read counterpart to `JSONExporter`: the Decodable DTOs below mirror
/// the exact snake_case schema that `JSONExporter.ExportDocument` emits. Importing
/// is a *merge by id* — every record is matched against any existing object with
/// the same `id` and either updated in place or inserted fresh with that id.
///
/// SAFETY: the import only ever INSERTS or UPDATES. It never deletes existing
/// objects, never clears relationships it cannot resolve, and continues past
/// per-record problems (recording a warning) rather than aborting the whole
/// restore. Unknown enum raw values fall back to each model's default via the
/// typed accessors. No SwiftUI here — this is a plain engine, safe to run on a
/// background `ModelContext`.
enum ImportError: LocalizedError {
    case unreadable(String)

    var errorDescription: String? {
        switch self {
        case .unreadable(let detail):
            return "The file could not be read as a Fit export: \(detail)"
        }
    }
}

// MARK: - Summary

/// Per-entity counts plus any non-fatal warnings produced by a restore.
struct ImportSummary {
    var insertedExercises = 0
    var updatedExercises = 0
    var insertedAliases = 0
    var updatedAliases = 0
    var insertedHealthWorkouts = 0
    var updatedHealthWorkouts = 0
    var insertedBodyWeightEntries = 0
    var updatedBodyWeightEntries = 0
    var insertedSleepEntries = 0
    var updatedSleepEntries = 0
    var insertedWorkouts = 0
    var updatedWorkouts = 0
    var insertedSets = 0
    var updatedSets = 0
    var insertedJournalEntries = 0
    var updatedJournalEntries = 0
    var warnings: [String] = []

    /// Total objects inserted or updated across all entity types.
    var totalChanged: Int {
        insertedExercises + updatedExercises
            + insertedAliases + updatedAliases
            + insertedHealthWorkouts + updatedHealthWorkouts
            + insertedBodyWeightEntries + updatedBodyWeightEntries
            + insertedSleepEntries + updatedSleepEntries
            + insertedWorkouts + updatedWorkouts
            + insertedSets + updatedSets
            + insertedJournalEntries + updatedJournalEntries
    }

    var insertedTotal: Int {
        insertedExercises + insertedAliases + insertedHealthWorkouts
            + insertedBodyWeightEntries + insertedSleepEntries
            + insertedWorkouts + insertedSets + insertedJournalEntries
    }

    var updatedTotal: Int {
        updatedExercises + updatedAliases + updatedHealthWorkouts
            + updatedBodyWeightEntries + updatedSleepEntries
            + updatedWorkouts + updatedSets + updatedJournalEntries
    }
}

// MARK: - Date parsing

/// Parses ISO-8601 strings produced by `ExportFormatting.iso`. The exporter uses
/// `.withInternetDateTime` (no fractional seconds), but we also accept fractional
/// seconds so files from other tools / future versions still load.
private enum ImportFormatting {
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

    /// Parse a required date string, trying both plain and fractional ISO-8601.
    static func date(_ string: String) -> Date? {
        if let d = iso8601.date(from: string) { return d }
        if let d = iso8601Fractional.date(from: string) { return d }
        return nil
    }

    /// Parse an optional date string. Empty / nil / unparseable → nil.
    static func date(_ string: String?) -> Date? {
        guard let string, !string.isEmpty else { return nil }
        return date(string)
    }
}

// MARK: - Decodable DTOs (mirror JSONExporter's export schema §12.14)

/// Top-level export document. Optional collections so partial / older files load.
struct ImportRoot: Decodable {
    let workouts: [ImportWorkout]?
    let exercises: [ImportExercise]?
    let bodyWeightEntries: [ImportBodyWeight]?
    let sleepEntries: [ImportSleep]?

    enum CodingKeys: String, CodingKey {
        case workouts
        case exercises
        case bodyWeightEntries = "body_weight_entries"
        case sleepEntries = "sleep_entries"
    }
}

struct ImportWorkout: Decodable {
    let workoutId: String
    let title: String?
    let startTime: String
    let endTime: String?
    let timezone: String?
    let isBackfilled: Bool?
    let sessionMetadata: ImportSessionMetadata?
    let sets: [ImportSet]?
    let linkedHealthWorkout: ImportHealthWorkout?
    let journalEntries: [ImportJournal]?
    let createdAt: String?
    let updatedAt: String?

    enum CodingKeys: String, CodingKey {
        case workoutId = "workout_id"
        case title
        case startTime = "start_time"
        case endTime = "end_time"
        case timezone
        case isBackfilled = "is_backfilled"
        case sessionMetadata = "session_metadata"
        case sets
        case linkedHealthWorkout = "linked_health_workout"
        case journalEntries = "journal_entries"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct ImportSessionMetadata: Decodable {
    let goal: String?
    let location: String?
    let energyBefore: Int?
    let soreness: String?
    let painToday: String?
    let sleepQualitySubjective: String?
    let stressLevel: Int?
    let foodTiming: String?
    let caffeine: String?
    let bodyWeightManualKg: Double?
    let notes: String?

    enum CodingKeys: String, CodingKey {
        case goal
        case location
        case energyBefore = "energy_before"
        case soreness
        case painToday = "pain_today"
        case sleepQualitySubjective = "sleep_quality_subjective"
        case stressLevel = "stress_level"
        case foodTiming = "food_timing"
        case caffeine
        case bodyWeightManualKg = "body_weight_manual_kg"
        case notes
    }
}

struct ImportSet: Decodable {
    let setId: String
    let exerciseId: String?
    let exerciseNameAtTime: String?
    let setIndex: Int?
    let timestamp: String?
    let weightMode: String?
    let weightKg: Double?
    let bodyWeightKg: Double?
    let assistanceKg: Double?
    let addedWeightKg: Double?
    let reps: Int?
    let effort: Int?
    let repsLeft: String?
    let formQuality: String?
    let limiter: String?
    let painSeverity: String?
    let painLocation: String?
    let isWarmup: Bool?
    let isFailed: Bool?
    let supersetGroup: Int?
    let source: String?
    let notes: String?
    let createdAt: String?
    let updatedAt: String?

    enum CodingKeys: String, CodingKey {
        case setId = "set_id"
        case exerciseId = "exercise_id"
        case exerciseNameAtTime = "exercise_name_at_time"
        case setIndex = "set_index"
        case timestamp
        case weightMode = "weight_mode"
        case weightKg = "weight_kg"
        case bodyWeightKg = "body_weight_kg"
        case assistanceKg = "assistance_kg"
        case addedWeightKg = "added_weight_kg"
        case reps
        case effort
        case repsLeft = "reps_left"
        case formQuality = "form_quality"
        case limiter
        case painSeverity = "pain_severity"
        case painLocation = "pain_location"
        case isWarmup = "is_warmup"
        case isFailed = "is_failed"
        case supersetGroup = "superset_group"
        case source
        case notes
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct ImportHealthWorkout: Decodable {
    let healthWorkoutId: String
    let appleHealthUuid: String?
    let workoutType: String?
    let startTime: String?
    let endTime: String?
    let durationSeconds: Double?
    let activeEnergyKcal: Double?
    let totalEnergyKcal: Double?
    let avgHeartRateBpm: Double?
    let minHeartRateBpm: Double?
    let maxHeartRateBpm: Double?
    let heartRateSampleCount: Int?
    let sourceName: String?
    let sourceDevice: String?
    let importedAt: String?

    enum CodingKeys: String, CodingKey {
        case healthWorkoutId = "health_workout_id"
        case appleHealthUuid = "apple_health_uuid"
        case workoutType = "workout_type"
        case startTime = "start_time"
        case endTime = "end_time"
        case durationSeconds = "duration_seconds"
        case activeEnergyKcal = "active_energy_kcal"
        case totalEnergyKcal = "total_energy_kcal"
        case avgHeartRateBpm = "avg_heart_rate_bpm"
        case minHeartRateBpm = "min_heart_rate_bpm"
        case maxHeartRateBpm = "max_heart_rate_bpm"
        case heartRateSampleCount = "heart_rate_sample_count"
        case sourceName = "source_name"
        case sourceDevice = "source_device"
        case importedAt = "imported_at"
    }
}

struct ImportJournal: Decodable {
    let entryId: String
    let workoutId: String?
    let exerciseId: String?
    let setId: String?
    let timestamp: String?
    let entryType: String?
    let text: String?
    let createdAt: String?
    let updatedAt: String?

    enum CodingKeys: String, CodingKey {
        case entryId = "entry_id"
        case workoutId = "workout_id"
        case exerciseId = "exercise_id"
        case setId = "set_id"
        case timestamp
        case entryType = "entry_type"
        case text
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct ImportExercise: Decodable {
    let exerciseId: String
    let canonicalName: String?
    let category: String?
    let equipment: String?
    let movementPattern: String?
    let defaultWeightMode: String?
    let primaryMuscles: [String]?
    let secondaryMuscles: [String]?
    let aliases: [ImportAlias]?
    let notes: String?
    let archived: Bool?
    let isGoalExercise: Bool?
    let isFavorite: Bool?
    let createdAt: String?
    let updatedAt: String?

    enum CodingKeys: String, CodingKey {
        case exerciseId = "exercise_id"
        case canonicalName = "canonical_name"
        case category
        case equipment
        case movementPattern = "movement_pattern"
        case defaultWeightMode = "default_weight_mode"
        case primaryMuscles = "primary_muscles"
        case secondaryMuscles = "secondary_muscles"
        case aliases
        case notes
        case archived
        case isGoalExercise = "is_goal_exercise"
        case isFavorite = "is_favorite"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct ImportAlias: Decodable {
    let aliasId: String
    let aliasName: String?
    let language: String?
    let createdAt: String?

    enum CodingKeys: String, CodingKey {
        case aliasId = "alias_id"
        case aliasName = "alias_name"
        case language
        case createdAt = "created_at"
    }
}

struct ImportBodyWeight: Decodable {
    let entryId: String
    let timestamp: String?
    let weightKg: Double?
    let source: String?
    let appleHealthSampleId: String?
    let notes: String?

    enum CodingKeys: String, CodingKey {
        case entryId = "entry_id"
        case timestamp
        case weightKg = "weight_kg"
        case source
        case appleHealthSampleId = "apple_health_sample_id"
        case notes
    }
}

struct ImportSleep: Decodable {
    let entryId: String
    let date: String?
    let startTime: String?
    let endTime: String?
    let durationSeconds: Double?
    let source: String?
    let subjectiveSleepQuality: String?
    let appleHealthSampleId: String?
    let notes: String?

    enum CodingKeys: String, CodingKey {
        case entryId = "entry_id"
        case date
        case startTime = "start_time"
        case endTime = "end_time"
        case durationSeconds = "duration_seconds"
        case source
        case subjectiveSleepQuality = "subjective_sleep_quality"
        case appleHealthSampleId = "apple_health_sample_id"
        case notes
    }
}

// MARK: - Import engine

final class DataImportService {

    init() {}

    /// Decode the export JSON and upsert its contents into `context`, merging by
    /// id. Throws only when the file itself is unparseable; per-record problems
    /// are collected as warnings. Saves the context on success.
    func importJSON(_ data: Data, into context: ModelContext) throws -> ImportSummary {
        let root: ImportRoot
        do {
            root = try JSONDecoder().decode(ImportRoot.self, from: data)
        } catch {
            throw ImportError.unreadable(error.localizedDescription)
        }

        var summary = ImportSummary()

        // In-memory caches keyed by id, used both to resolve relationships and to
        // avoid re-fetching the same object more than once per run.
        var exercisesById: [UUID: Exercise] = [:]
        var healthById: [UUID: HealthWorkout] = [:]
        var workoutsById: [UUID: WorkoutSession] = [:]

        // Upsert in dependency order so relationships always resolve to a present
        // object: exercises → health workouts → body weight / sleep → workouts →
        // sets → journal entries.
        importExercises(root.exercises ?? [], into: context, cache: &exercisesById, summary: &summary)
        importHealthWorkouts(workoutsHealth(root), into: context, cache: &healthById, summary: &summary)
        importBodyWeight(root.bodyWeightEntries ?? [], into: context, summary: &summary)
        importSleep(root.sleepEntries ?? [], into: context, summary: &summary)
        importWorkouts(
            root.workouts ?? [],
            into: context,
            cache: &workoutsById,
            healthCache: &healthById,
            summary: &summary
        )
        importSets(
            root.workouts ?? [],
            into: context,
            workoutsById: workoutsById,
            exercisesById: exercisesById,
            summary: &summary
        )
        importJournal(
            root.workouts ?? [],
            into: context,
            workoutsById: workoutsById,
            summary: &summary
        )

        do {
            try context.save()
        } catch {
            summary.warnings.append("Some changes could not be saved: \(error.localizedDescription)")
        }

        return summary
    }

    /// Flatten the health workouts embedded in workouts (the export only nests
    /// them under their linked session).
    private func workoutsHealth(_ root: ImportRoot) -> [ImportHealthWorkout] {
        (root.workouts ?? []).compactMap { $0.linkedHealthWorkout }
    }

    // MARK: - Generic upsert helper

    /// Fetch a single existing model by `id`, or nil. Uses a tiny `FetchDescriptor`
    /// with a `#Predicate` on `id`.
    private func fetchExisting<T: PersistentModel>(_ type: T.Type, id: UUID, in context: ModelContext, predicate: Predicate<T>) -> T? {
        var descriptor = FetchDescriptor<T>(predicate: predicate)
        descriptor.fetchLimit = 1
        return (try? context.fetch(descriptor))?.first
    }

    // MARK: - Exercises (+ aliases)

    private func importExercises(_ dtos: [ImportExercise], into context: ModelContext, cache: inout [UUID: Exercise], summary: inout ImportSummary) {
        for dto in dtos {
            guard let id = UUID(uuidString: dto.exerciseId) else {
                summary.warnings.append("Skipped an exercise with an invalid id (\(dto.exerciseId)).")
                continue
            }

            let existing = fetchExisting(Exercise.self, id: id, in: context, predicate: #Predicate { $0.id == id })
            let exercise: Exercise
            if let existing {
                exercise = existing
                summary.updatedExercises += 1
            } else {
                exercise = Exercise(id: id)
                context.insert(exercise)
                summary.insertedExercises += 1
            }

            if let name = dto.canonicalName { exercise.canonicalName = name }
            exercise.category = dto.category.flatMap(ExerciseCategory.init(rawValue:))
            exercise.equipment = dto.equipment.flatMap(Equipment.init(rawValue:))
            exercise.movementPattern = dto.movementPattern.flatMap(MovementPattern.init(rawValue:))
            if let mode = dto.defaultWeightMode.flatMap(WeightMode.init(rawValue:)) {
                exercise.defaultWeightMode = mode
            }
            if let primary = dto.primaryMuscles { exercise.primaryMusclesRaw = primary }
            if let secondary = dto.secondaryMuscles { exercise.secondaryMusclesRaw = secondary }
            if let notes = dto.notes { exercise.notes = notes }
            if let archived = dto.archived { exercise.archived = archived }
            if let goal = dto.isGoalExercise { exercise.isGoalExercise = goal }
            if let favorite = dto.isFavorite { exercise.isFavorite = favorite }
            if let created = ImportFormatting.date(dto.createdAt) { exercise.createdAt = created }
            if let updated = ImportFormatting.date(dto.updatedAt) { exercise.updatedAt = updated }

            cache[id] = exercise

            reconcileAliases(dto.aliases ?? [], for: exercise, into: context, summary: &summary)
        }
    }

    /// Upsert each alias by id and attach it to its parent exercise. Existing
    /// aliases are never deleted (additive, no destructive reconciliation).
    private func reconcileAliases(_ dtos: [ImportAlias], for exercise: Exercise, into context: ModelContext, summary: inout ImportSummary) {
        for dto in dtos {
            guard let id = UUID(uuidString: dto.aliasId) else {
                summary.warnings.append("Skipped an alias with an invalid id (\(dto.aliasId)).")
                continue
            }
            let existing = fetchExisting(ExerciseAlias.self, id: id, in: context, predicate: #Predicate { $0.id == id })
            let alias: ExerciseAlias
            if let existing {
                alias = existing
                summary.updatedAliases += 1
            } else {
                alias = ExerciseAlias(id: id)
                context.insert(alias)
                summary.insertedAliases += 1
            }
            if let name = dto.aliasName { alias.aliasName = name }
            alias.languageOptional = dto.language
            if let created = ImportFormatting.date(dto.createdAt) { alias.createdAt = created }
            alias.exercise = exercise
        }
    }

    // MARK: - Health workouts

    private func importHealthWorkouts(_ dtos: [ImportHealthWorkout], into context: ModelContext, cache: inout [UUID: HealthWorkout], summary: inout ImportSummary) {
        for dto in dtos {
            guard let id = UUID(uuidString: dto.healthWorkoutId) else {
                summary.warnings.append("Skipped a Health workout with an invalid id (\(dto.healthWorkoutId)).")
                continue
            }
            // The same health workout may appear under several caches in theory;
            // de-dupe within a run.
            if cache[id] != nil { continue }

            let existing = fetchExisting(HealthWorkout.self, id: id, in: context, predicate: #Predicate { $0.id == id })
            let health: HealthWorkout
            if let existing {
                health = existing
                summary.updatedHealthWorkouts += 1
            } else {
                health = HealthWorkout(id: id)
                context.insert(health)
                summary.insertedHealthWorkouts += 1
            }

            if let uuid = dto.appleHealthUuid { health.appleHealthUUID = uuid }
            if let type = dto.workoutType { health.workoutType = type }
            if let start = ImportFormatting.date(dto.startTime) { health.startTime = start }
            if let end = ImportFormatting.date(dto.endTime) { health.endTime = end }
            if let duration = dto.durationSeconds { health.durationSeconds = duration }
            health.activeEnergyKcal = dto.activeEnergyKcal
            health.totalEnergyKcal = dto.totalEnergyKcal
            health.avgHeartRateBpm = dto.avgHeartRateBpm
            health.minHeartRateBpm = dto.minHeartRateBpm
            health.maxHeartRateBpm = dto.maxHeartRateBpm
            health.heartRateSampleCount = dto.heartRateSampleCount
            health.sourceName = dto.sourceName
            health.sourceDevice = dto.sourceDevice
            if let imported = ImportFormatting.date(dto.importedAt) { health.importedAt = imported }

            cache[id] = health
        }
    }

    // MARK: - Body weight

    private func importBodyWeight(_ dtos: [ImportBodyWeight], into context: ModelContext, summary: inout ImportSummary) {
        for dto in dtos {
            guard let id = UUID(uuidString: dto.entryId) else {
                summary.warnings.append("Skipped a body-weight entry with an invalid id (\(dto.entryId)).")
                continue
            }
            let existing = fetchExisting(BodyWeightEntry.self, id: id, in: context, predicate: #Predicate { $0.id == id })
            let entry: BodyWeightEntry
            if let existing {
                entry = existing
                summary.updatedBodyWeightEntries += 1
            } else {
                entry = BodyWeightEntry(id: id)
                context.insert(entry)
                summary.insertedBodyWeightEntries += 1
            }
            if let ts = ImportFormatting.date(dto.timestamp) { entry.timestamp = ts }
            if let weight = dto.weightKg { entry.weightKg = weight }
            if let source = dto.source.flatMap(DataSource.init(rawValue:)) { entry.source = source }
            entry.appleHealthSampleId = dto.appleHealthSampleId
            if let notes = dto.notes { entry.notes = notes }
        }
    }

    // MARK: - Sleep

    private func importSleep(_ dtos: [ImportSleep], into context: ModelContext, summary: inout ImportSummary) {
        for dto in dtos {
            guard let id = UUID(uuidString: dto.entryId) else {
                summary.warnings.append("Skipped a sleep entry with an invalid id (\(dto.entryId)).")
                continue
            }
            let existing = fetchExisting(SleepEntry.self, id: id, in: context, predicate: #Predicate { $0.id == id })
            let entry: SleepEntry
            if let existing {
                entry = existing
                summary.updatedSleepEntries += 1
            } else {
                entry = SleepEntry(id: id)
                context.insert(entry)
                summary.insertedSleepEntries += 1
            }
            if let date = ImportFormatting.date(dto.date) { entry.date = date }
            entry.startTime = ImportFormatting.date(dto.startTime)
            entry.endTime = ImportFormatting.date(dto.endTime)
            entry.durationSeconds = dto.durationSeconds
            if let source = dto.source.flatMap(DataSource.init(rawValue:)) { entry.source = source }
            entry.subjectiveSleepQuality = dto.subjectiveSleepQuality.flatMap(SleepQuality.init(rawValue:))
            entry.appleHealthSampleId = dto.appleHealthSampleId
            if let notes = dto.notes { entry.notes = notes }
        }
    }

    // MARK: - Workouts

    private func importWorkouts(_ dtos: [ImportWorkout], into context: ModelContext, cache: inout [UUID: WorkoutSession], healthCache: inout [UUID: HealthWorkout], summary: inout ImportSummary) {
        for dto in dtos {
            guard let id = UUID(uuidString: dto.workoutId) else {
                summary.warnings.append("Skipped a workout with an invalid id (\(dto.workoutId)).")
                continue
            }
            let existing = fetchExisting(WorkoutSession.self, id: id, in: context, predicate: #Predicate { $0.id == id })
            let workout: WorkoutSession
            if let existing {
                workout = existing
                summary.updatedWorkouts += 1
            } else {
                workout = WorkoutSession(id: id)
                context.insert(workout)
                summary.insertedWorkouts += 1
            }

            if let title = dto.title { workout.title = title }
            if let start = ImportFormatting.date(dto.startTime) { workout.startTime = start }
            workout.endTime = ImportFormatting.date(dto.endTime)
            if let tz = dto.timezone { workout.timezoneIdentifier = tz }
            if let backfilled = dto.isBackfilled { workout.isBackfilled = backfilled }

            if let meta = dto.sessionMetadata {
                workout.goal = meta.goal.flatMap(WorkoutGoal.init(rawValue:))
                workout.location = meta.location.flatMap(WorkoutLocation.init(rawValue:))
                workout.energyBefore = meta.energyBefore
                workout.soreness = meta.soreness.flatMap(Soreness.init(rawValue:))
                workout.painToday = meta.painToday.flatMap(PainToday.init(rawValue:))
                workout.sleepQualitySubjective = meta.sleepQualitySubjective.flatMap(SleepQuality.init(rawValue:))
                workout.stressLevel = meta.stressLevel
                workout.foodTiming = meta.foodTiming.flatMap(FoodTiming.init(rawValue:))
                workout.caffeine = meta.caffeine.flatMap(Caffeine.init(rawValue:))
                workout.bodyWeightManualKg = meta.bodyWeightManualKg
                if let notes = meta.notes { workout.notes = notes }
            }

            // Link the embedded health workout by id (already upserted earlier).
            if let healthDto = dto.linkedHealthWorkout,
               let healthId = UUID(uuidString: healthDto.healthWorkoutId),
               let health = healthCache[healthId] {
                workout.linkedHealthWorkout = health
            }

            if let created = ImportFormatting.date(dto.createdAt) { workout.createdAt = created }
            if let updated = ImportFormatting.date(dto.updatedAt) { workout.updatedAt = updated }

            cache[id] = workout
        }
    }

    // MARK: - Sets

    private func importSets(_ workouts: [ImportWorkout], into context: ModelContext, workoutsById: [UUID: WorkoutSession], exercisesById: [UUID: Exercise], summary: inout ImportSummary) {
        for workoutDto in workouts {
            let parentId = UUID(uuidString: workoutDto.workoutId)
            for dto in workoutDto.sets ?? [] {
                guard let id = UUID(uuidString: dto.setId) else {
                    summary.warnings.append("Skipped a set with an invalid id (\(dto.setId)).")
                    continue
                }
                let existing = fetchExisting(WorkoutSet.self, id: id, in: context, predicate: #Predicate { $0.id == id })
                let set: WorkoutSet
                if let existing {
                    set = existing
                    summary.updatedSets += 1
                } else {
                    set = WorkoutSet(id: id)
                    context.insert(set)
                    summary.insertedSets += 1
                }

                if let name = dto.exerciseNameAtTime { set.exerciseNameAtTime = name }
                if let index = dto.setIndex { set.setIndex = index }
                if let ts = ImportFormatting.date(dto.timestamp) { set.timestamp = ts }
                if let mode = dto.weightMode.flatMap(WeightMode.init(rawValue:)) { set.weightMode = mode }
                set.weightKg = dto.weightKg
                set.bodyWeightKg = dto.bodyWeightKg
                set.assistanceKg = dto.assistanceKg
                set.addedWeightKg = dto.addedWeightKg
                set.reps = dto.reps
                set.effort = dto.effort
                set.repsLeft = dto.repsLeft.flatMap(RepsLeft.init(rawValue:))
                set.formQuality = dto.formQuality.flatMap(FormQuality.init(rawValue:))
                set.limiter = dto.limiter.flatMap(Limiter.init(rawValue:))
                set.painSeverity = dto.painSeverity.flatMap(PainSeverity.init(rawValue:))
                set.painLocation = dto.painLocation.flatMap(PainLocation.init(rawValue:))
                if let warmup = dto.isWarmup { set.isWarmup = warmup }
                if let failed = dto.isFailed { set.isFailed = failed }
                set.supersetGroup = dto.supersetGroup
                if let source = dto.source.flatMap(RecordSource.init(rawValue:)) { set.source = source }
                if let notes = dto.notes { set.notes = notes }
                if let created = ImportFormatting.date(dto.createdAt) { set.createdAt = created }
                if let updated = ImportFormatting.date(dto.updatedAt) { set.updatedAt = updated }

                // Resolve relationships by id. The `set_id`'s own export nested it
                // under its workout, so prefer that parent; fall back to nothing.
                if let parentId, let workout = workoutsById[parentId] {
                    set.workout = workout
                }
                if let exId = dto.exerciseId.flatMap(UUID.init(uuidString:)), let exercise = exercisesById[exId] {
                    set.exercise = exercise
                }
            }
        }
    }

    // MARK: - Journal entries

    private func importJournal(_ workouts: [ImportWorkout], into context: ModelContext, workoutsById: [UUID: WorkoutSession], summary: inout ImportSummary) {
        for workoutDto in workouts {
            for dto in workoutDto.journalEntries ?? [] {
                guard let id = UUID(uuidString: dto.entryId) else {
                    summary.warnings.append("Skipped a journal entry with an invalid id (\(dto.entryId)).")
                    continue
                }
                let existing = fetchExisting(JournalEntry.self, id: id, in: context, predicate: #Predicate { $0.id == id })
                let entry: JournalEntry
                if let existing {
                    entry = existing
                    summary.updatedJournalEntries += 1
                } else {
                    entry = JournalEntry(id: id)
                    context.insert(entry)
                    summary.insertedJournalEntries += 1
                }

                if let ts = ImportFormatting.date(dto.timestamp) { entry.timestamp = ts }
                if let type = dto.entryType.flatMap(JournalEntryType.init(rawValue:)) { entry.entryType = type }
                if let text = dto.text { entry.text = text }
                entry.exerciseIdOptional = dto.exerciseId.flatMap(UUID.init(uuidString:))
                entry.setIdOptional = dto.setId.flatMap(UUID.init(uuidString:))
                if let created = ImportFormatting.date(dto.createdAt) { entry.createdAt = created }
                if let updated = ImportFormatting.date(dto.updatedAt) { entry.updatedAt = updated }

                // Link the parent workout: prefer the explicit workout_id, else the
                // workout this entry was nested under in the export.
                let linkId = dto.workoutId.flatMap(UUID.init(uuidString:))
                    ?? UUID(uuidString: workoutDto.workoutId)
                if let linkId, let workout = workoutsById[linkId] {
                    entry.workout = workout
                }
            }
        }
    }
}
