import Foundation

/// Builds the CSV files for an export. Pure value-in / string-out — no SwiftUI,
/// no SwiftData fetching (the service hands it a resolved `ExportDataSet`).
///
/// CSV dialect: RFC-4180. Fields containing a comma, double-quote or newline are
/// wrapped in double-quotes, and any internal double-quotes are doubled. Empty
/// string is used for nil. Timestamps are ISO-8601 with timezone. Weights are kg.
enum CSVExporter {

    // MARK: - Field escaping

    /// Escape one CSV field per RFC-4180.
    static func escape(_ value: String) -> String {
        let needsQuoting = value.contains(",")
            || value.contains("\"")
            || value.contains("\n")
            || value.contains("\r")
        guard needsQuoting else { return value }
        let doubled = value.replacingOccurrences(of: "\"", with: "\"\"")
        return "\"\(doubled)\""
    }

    /// Join a row of already-stringified fields, escaping each.
    static func row(_ fields: [String]) -> String {
        fields.map(escape).joined(separator: ",")
    }

    /// Build a full CSV document from a header row and value rows. Uses CRLF line
    /// endings (RFC-4180) and a trailing newline.
    static func document(header: [String], rows: [[String]]) -> String {
        var lines: [String] = [row(header)]
        lines.append(contentsOf: rows.map(row))
        return lines.joined(separator: "\r\n") + "\r\n"
    }

    // MARK: - Value helpers

    private static func str(_ value: Int?) -> String { value.map(String.init) ?? "" }
    private static func str(_ value: Bool) -> String { value ? "true" : "false" }
    private static func str(_ value: Double?) -> String {
        guard let value else { return "" }
        // Plain, locale-independent number with up to 4 decimals, trimming zeros.
        return trimmedNumber(value)
    }
    private static func trimmedNumber(_ value: Double) -> String {
        if value == value.rounded() && abs(value) < 1e15 {
            return String(Int(value.rounded()))
        }
        var s = String(format: "%.4f", value)
        while s.hasSuffix("0") { s.removeLast() }
        if s.hasSuffix(".") { s.removeLast() }
        return s
    }

    // MARK: - Per-file builders

    /// workouts.csv — spec §12.4 column order; trailing `timezone`/`is_backfilled`
    /// are additive (not in the spec list but useful and harmless).
    static func workouts(_ data: ExportDataSet) -> String {
        let header = [
            "workout_id", "start_time", "end_time", "duration_seconds", "title",
            "workout_goal", "location", "energy_before_0_5", "soreness",
            "pain_today", "sleep_quality_subjective", "stress_0_5", "food_timing",
            "caffeine", "body_weight_kg_manual", "body_weight_kg_imported",
            "apple_health_workout_id", "notes", "created_at", "updated_at",
            "timezone", "is_backfilled"
        ]
        let rows = data.workouts.map { w -> [String] in
            [
                w.id.uuidString,
                ExportFormatting.iso(w.startTime),
                ExportFormatting.iso(w.endTime),
                w.duration.map { trimmedNumber($0) } ?? "",
                w.title,
                w.goal?.rawValue ?? "",
                w.location?.rawValue ?? "",
                str(w.energyBefore),
                w.soreness?.rawValue ?? "",
                w.painToday?.rawValue ?? "",
                w.sleepQualitySubjective?.rawValue ?? "",
                str(w.stressLevel),
                w.foodTiming?.rawValue ?? "",
                w.caffeine?.rawValue ?? "",
                str(w.bodyWeightManualKg),
                importedBodyWeight(forWorkoutStart: w.startTime, in: data),
                w.linkedHealthWorkout?.appleHealthUUID ?? "",
                w.notes,
                ExportFormatting.iso(w.createdAt),
                ExportFormatting.iso(w.updatedAt),
                w.timezoneIdentifier,
                str(w.isBackfilled)
            ]
        }
        return document(header: header, rows: rows)
    }

    /// The kg weight of the Health-imported body-weight entry recorded on the same
    /// calendar day as `workoutStart`, choosing the one closest in time to it.
    /// Empty string when none exists (or when body-weight entries are excluded
    /// from the export, in which case `data.bodyWeightEntries` is empty).
    /// Formatted with the same helper as `body_weight_kg_manual`.
    private static func importedBodyWeight(forWorkoutStart workoutStart: Date, in data: ExportDataSet) -> String {
        let calendar = Calendar.current
        let workoutDay = calendar.startOfDay(for: workoutStart)
        let nearest = data.bodyWeightEntries
            .filter { $0.source == .healthImport
                && calendar.startOfDay(for: $0.timestamp) == workoutDay }
            .min { lhs, rhs in
                abs(lhs.timestamp.timeIntervalSince(workoutStart))
                    < abs(rhs.timestamp.timeIntervalSince(workoutStart))
            }
        guard let nearest else { return "" }
        return str(nearest.weightKg)
    }

    /// sets.csv
    static func sets(_ data: ExportDataSet) -> String {
        // Spec §12.5 order first; derived metrics appended as additive columns.
        let header = [
            "set_id", "workout_id", "exercise_id", "exercise_name_at_time",
            "set_index", "timestamp", "weight_mode", "weight_kg", "body_weight_kg",
            "assistance_kg", "added_weight_kg", "reps", "effort_0_5", "reps_left",
            "form_quality", "limiter", "pain_severity", "pain_location",
            "is_warmup", "is_failed", "source", "notes", "created_at", "updated_at",
            "effective_load_kg", "volume_kg", "estimated_1rm_kg", "superset_group"
        ]
        let rows = data.sets.map { s -> [String] in
            [
                s.id.uuidString,
                s.workout?.id.uuidString ?? "",
                s.exercise?.id.uuidString ?? "",
                s.exerciseNameAtTime,
                String(s.setIndex),
                ExportFormatting.iso(s.timestamp),
                s.weightMode.rawValue,
                str(s.weightKg),
                str(s.bodyWeightKg),
                str(s.assistanceKg),
                str(s.addedWeightKg),
                str(s.reps),
                str(s.effort),
                s.repsLeft?.rawValue ?? "",
                s.formQuality?.rawValue ?? "",
                s.limiter?.rawValue ?? "",
                s.painSeverity?.rawValue ?? "",
                s.painLocation?.rawValue ?? "",
                str(s.isWarmup),
                str(s.isFailed),
                s.source.rawValue,
                s.notes,
                ExportFormatting.iso(s.createdAt),
                ExportFormatting.iso(s.updatedAt),
                str(s.effectiveLoadKg),
                str(s.volumeKg),
                str(s.estimatedOneRepMaxKg),
                str(s.supersetGroup)
            ]
        }
        return document(header: header, rows: rows)
    }

    /// exercises.csv
    static func exercises(_ data: ExportDataSet) -> String {
        // Spec §12.6 order; is_goal_exercise/is_favorite appended as additive.
        let header = [
            "exercise_id", "canonical_name", "category", "primary_muscles",
            "secondary_muscles", "equipment", "movement_pattern",
            "default_weight_mode", "archived", "notes", "created_at", "updated_at",
            "is_goal_exercise", "is_favorite"
        ]
        let rows = data.exercises.map { e -> [String] in
            [
                e.id.uuidString,
                e.canonicalName,
                e.category?.rawValue ?? "",
                e.primaryMusclesRaw.joined(separator: ";"),
                e.secondaryMusclesRaw.joined(separator: ";"),
                e.equipment?.rawValue ?? "",
                e.movementPattern?.rawValue ?? "",
                e.defaultWeightMode.rawValue,
                str(e.archived),
                e.notes,
                ExportFormatting.iso(e.createdAt),
                ExportFormatting.iso(e.updatedAt),
                str(e.isGoalExercise),
                str(e.isFavorite)
            ]
        }
        return document(header: header, rows: rows)
    }

    /// exercise_aliases.csv
    static func exerciseAliases(_ data: ExportDataSet) -> String {
        let header = ["alias_id", "exercise_id", "alias_name", "language_optional", "created_at"]
        let rows = data.exerciseAliases.map { a -> [String] in
            [
                a.id.uuidString,
                a.exercise?.id.uuidString ?? "",
                a.aliasName,
                a.languageOptional ?? "",
                ExportFormatting.iso(a.createdAt)
            ]
        }
        return document(header: header, rows: rows)
    }

    /// health_workouts.csv
    static func healthWorkouts(_ data: ExportDataSet) -> String {
        // Spec §12.8 order incl. the avg/min/max HR columns; linked_workout_id additive.
        let header = [
            "health_workout_id", "apple_health_uuid", "workout_type",
            "start_time", "end_time", "duration_seconds",
            "active_energy_kcal", "total_energy_kcal",
            "avg_heart_rate_bpm", "min_heart_rate_bpm", "max_heart_rate_bpm",
            "source_name", "source_device", "imported_at",
            "linked_workout_id"
        ]
        let rows = data.healthWorkouts.map { h -> [String] in
            [
                h.id.uuidString,
                h.appleHealthUUID,
                h.workoutType,
                ExportFormatting.iso(h.startTime),
                ExportFormatting.iso(h.endTime),
                trimmedNumber(h.durationSeconds),
                str(h.activeEnergyKcal),
                str(h.totalEnergyKcal),
                str(h.avgHeartRateBpm),
                str(h.minHeartRateBpm),
                str(h.maxHeartRateBpm),
                h.sourceName ?? "",
                h.sourceDevice ?? "",
                ExportFormatting.iso(h.importedAt),
                h.linkedSession?.id.uuidString ?? ""
            ]
        }
        return document(header: header, rows: rows)
    }

    /// heart_rate_summary.csv — zone_*_seconds are filled from the per-zone time
    /// computed at Health import (F13); blank for records imported before that
    /// feature, where the zone fields are still nil.
    static func heartRateSummary(_ data: ExportDataSet) -> String {
        // Spec §12.9 order: leading workout_id (linked session) then HR summary.
        let header = [
            "workout_id", "health_workout_id", "avg_hr_bpm", "min_hr_bpm",
            "max_hr_bpm", "hr_samples_count",
            "zone_1_seconds", "zone_2_seconds", "zone_3_seconds",
            "zone_4_seconds", "zone_5_seconds"
        ]
        let rows = data.healthWorkouts.map { h -> [String] in
            [
                h.linkedSession?.id.uuidString ?? "",
                h.id.uuidString,
                str(h.avgHeartRateBpm),
                str(h.minHeartRateBpm),
                str(h.maxHeartRateBpm),
                str(h.heartRateSampleCount),
                str(h.zone1Seconds),
                str(h.zone2Seconds),
                str(h.zone3Seconds),
                str(h.zone4Seconds),
                str(h.zone5Seconds)
            ]
        }
        return document(header: header, rows: rows)
    }

    /// body_weight.csv
    static func bodyWeight(_ data: ExportDataSet) -> String {
        let header = [
            "body_weight_entry_id", "timestamp", "weight_kg", "source",
            "apple_health_sample_id", "notes"
        ]
        let rows = data.bodyWeightEntries.map { b -> [String] in
            [
                b.id.uuidString,
                ExportFormatting.iso(b.timestamp),
                trimmedNumber(b.weightKg),
                b.source.rawValue,
                b.appleHealthSampleId ?? "",
                b.notes
            ]
        }
        return document(header: header, rows: rows)
    }

    /// sleep.csv
    static func sleep(_ data: ExportDataSet) -> String {
        let header = [
            "sleep_entry_id", "date", "start_time", "end_time", "duration_seconds",
            "sleep_source", "subjective_sleep_quality", "apple_health_sample_id", "notes"
        ]
        let rows = data.sleepEntries.map { s -> [String] in
            [
                s.id.uuidString,
                ExportFormatting.iso(s.date),
                ExportFormatting.iso(s.startTime),
                ExportFormatting.iso(s.endTime),
                str(s.durationSeconds),
                s.source.rawValue,
                s.subjectiveSleepQuality?.rawValue ?? "",
                s.appleHealthSampleId ?? "",
                s.notes
            ]
        }
        return document(header: header, rows: rows)
    }

    /// journal_entries.csv
    static func journalEntries(_ data: ExportDataSet) -> String {
        let header = [
            "journal_entry_id", "workout_id", "exercise_id_optional", "set_id_optional",
            "timestamp", "entry_type", "text", "created_at", "updated_at"
        ]
        let rows = data.journalEntries.map { j -> [String] in
            [
                j.id.uuidString,
                j.workout?.id.uuidString ?? "",
                j.exerciseIdOptional?.uuidString ?? "",
                j.setIdOptional?.uuidString ?? "",
                ExportFormatting.iso(j.timestamp),
                j.entryType.rawValue,
                j.text,
                ExportFormatting.iso(j.createdAt),
                ExportFormatting.iso(j.updatedAt)
            ]
        }
        return document(header: header, rows: rows)
    }

    // MARK: - Driver

    /// One produced CSV file: its filename and contents.
    struct File {
        let name: String
        let contents: String
    }

    /// Build all CSV files that the request asks for. Always includes workouts,
    /// sets, exercises and exercise_aliases; the rest depend on include flags.
    static func allFiles(for data: ExportDataSet, request: ExportRequest) -> [File] {
        var files: [File] = [
            File(name: ExportFileName.workouts, contents: workouts(data)),
            File(name: ExportFileName.sets, contents: sets(data)),
            File(name: ExportFileName.exercises, contents: exercises(data)),
            File(name: ExportFileName.exerciseAliases, contents: exerciseAliases(data))
        ]
        if request.includeHealthData {
            files.append(File(name: ExportFileName.healthWorkouts, contents: healthWorkouts(data)))
            files.append(File(name: ExportFileName.heartRateSummary, contents: heartRateSummary(data)))
        }
        if request.includeBodyWeight {
            files.append(File(name: ExportFileName.bodyWeight, contents: bodyWeight(data)))
        }
        if request.includeSleep {
            files.append(File(name: ExportFileName.sleep, contents: sleep(data)))
        }
        if request.includeJournal {
            files.append(File(name: ExportFileName.journalEntries, contents: journalEntries(data)))
        }
        return files
    }
}
