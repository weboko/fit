import Foundation

/// Builds `data_dictionary.md` — the human/AI-readable schema that ships inside
/// the CSV and ZIP export bundles. The export exists so an external AI can
/// analyze the data "cleanly" (SPEC §12, §30); the column *names* are stable but
/// their *semantics* are not self-evident, so this dictionary documents every
/// emitted column, every enum's raw string values, the subjective 0–5 scales and
/// the derived-column formulas.
///
/// Pure value-out (no SwiftUI, no SwiftData). The contents must stay accurate to
/// the columns `CSVExporter` actually emits and to the real enum raw values in
/// `Enums.swift` — `ExportSchemaTests` ties this doc to the export contract the
/// same way `ExportContractTests` (F28) locks the CSV headers.
enum ExportSchema {

    /// The filename used inside the export bundle.
    static let fileName = ExportFileName.dataDictionary

    /// The full data dictionary as Markdown.
    static func markdown() -> String {
        var out = ""
        out += intro()
        out += workoutsSection()
        out += setsSection()
        out += exercisesSection()
        out += exerciseAliasesSection()
        out += healthWorkoutsSection()
        out += heartRateSummarySection()
        out += bodyWeightSection()
        out += sleepSection()
        out += journalEntriesSection()
        out += scalesSection()
        out += derivedSection()
        return out
    }

    // MARK: - Intro

    private static func intro() -> String {
        """
        # Fit — Export Data Dictionary

        This document describes every file and column in this export bundle so the
        data can be interpreted unambiguously.

        **Conventions**

        - **Weights** are in **kilograms (kg)**.
        - **Durations** are in **seconds** unless a column name says otherwise.
        - **Timestamps** are **ISO-8601 with timezone offset** (e.g.
          `2026-06-28T18:30:00+02:00`). The bundle's `export_manifest.json` records
          the exporting device's `timezone`.
        - **Empty cell** = the value was not recorded / not applicable (CSV uses an
          empty string for nil).
        - **Booleans** are the literal strings `true` / `false`.
        - **IDs** are UUID strings; foreign-key columns reference another file's id.
        - **Only `weight` and `reps` are ever meaningful for a logged set** — every
          other field is optional and may be empty. Nothing beyond weight + reps is
          required.
        - Files whose names end in `.csv` are RFC-4180 CSV (fields with commas,
          quotes or newlines are double-quoted; internal quotes are doubled).
        - The set of files present depends on the export options chosen; the
          authoritative list for *this* bundle is `export_manifest.json` →
          `included_files`.


        """
    }

    // MARK: - Per-file sections

    private static func workoutsSection() -> String {
        section(
            title: "workouts.csv",
            blurb: "One row per workout session.",
            rows: [
                ("workout_id", "Unique id of the session.", "UUID"),
                ("start_time", "When the session started.", "ISO-8601 timestamp"),
                ("end_time", "When the session ended.", "ISO-8601 timestamp (may be empty)"),
                ("duration_seconds", "Session duration.", "number, seconds (may be empty)"),
                ("title", "User-given session title.", "text"),
                ("workout_goal", "Goal for the session.", enumValues(WorkoutGoal.self)),
                ("location", "Where it was performed.", enumValues(WorkoutLocation.self)),
                ("energy_before_0_5", "Subjective readiness to train before the session.", "integer 0–5 (see Scales)"),
                ("soreness", "Pre-session muscle soreness.", enumValues(Soreness.self)),
                ("pain_today", "Whether pain affected training today.", enumValues(PainToday.self)),
                ("sleep_quality_subjective", "Subjective sleep quality reported for the session.", enumValues(SleepQuality.self)),
                ("stress_0_5", "Subjective stress level today.", "integer 0–5 (see Scales)"),
                ("food_timing", "Eating state before training.", enumValues(FoodTiming.self)),
                ("caffeine", "Caffeine taken before training.", enumValues(Caffeine.self)),
                ("body_weight_kg_manual", "Manually entered body weight for the session.", "number, kg (may be empty)"),
                ("body_weight_kg_imported", "Nearest same-day Apple Health body-weight reading.", "number, kg (may be empty)"),
                ("apple_health_workout_id", "Apple Health UUID of the linked health workout, if any.", "text (may be empty)"),
                ("notes", "Free-text session notes.", "text"),
                ("created_at", "When the record was created.", "ISO-8601 timestamp"),
                ("updated_at", "When the record was last modified.", "ISO-8601 timestamp"),
                ("timezone", "IANA timezone identifier the session was logged in.", "text, e.g. `Europe/Prague`"),
                ("is_backfilled", "Whether the session was entered after the fact.", "boolean")
            ]
        )
    }

    private static func setsSection() -> String {
        section(
            title: "sets.csv",
            blurb: "One row per logged set. Only `weight_kg`/`body_weight_kg` and `reps` are guaranteed meaningful; all other fields are optional.",
            rows: [
                ("set_id", "Unique id of the set.", "UUID"),
                ("workout_id", "Session this set belongs to.", "UUID → workouts.csv (may be empty)"),
                ("exercise_id", "Exercise performed.", "UUID → exercises.csv (may be empty)"),
                ("exercise_name_at_time", "Exercise name as it was when the set was logged (preserved against later renames).", "text"),
                ("set_index", "Order of the set within the session.", "integer"),
                ("timestamp", "When the set was logged.", "ISO-8601 timestamp"),
                ("weight_mode", "How the load is expressed (drives the derived load — see Derived columns).", enumValues(WeightMode.self)),
                ("weight_kg", "External / added weight on the implement.", "number, kg (may be empty)"),
                ("body_weight_kg", "Body weight used for bodyweight-based modes.", "number, kg (may be empty)"),
                ("assistance_kg", "Assistance removed (assisted bodyweight mode).", "number, kg (may be empty)"),
                ("added_weight_kg", "Extra load added (added-bodyweight mode).", "number, kg (may be empty)"),
                ("reps", "Repetitions performed.", "integer (may be empty)"),
                ("effort_0_5", "How hard the set felt.", "integer 0–5 (see Scales)"),
                ("reps_left", "Estimated reps left in the tank (RIR).", enumValues(RepsLeft.self)),
                ("form_quality", "Subjective technique quality.", enumValues(FormQuality.self)),
                ("limiter", "What limited / stopped the set.", enumValues(Limiter.self)),
                ("pain_severity", "Pain/discomfort severity (tracking only, not medical).", enumValues(PainSeverity.self)),
                ("pain_location", "Where pain/discomfort was felt.", enumValues(PainLocation.self)),
                ("is_warmup", "Whether this was a warm-up set.", "boolean"),
                ("is_failed", "Whether the set failed.", "boolean"),
                ("source", "Provenance of the record.", enumValues(RecordSource.self)),
                ("notes", "Free-text set notes.", "text"),
                ("created_at", "When the record was created.", "ISO-8601 timestamp"),
                ("updated_at", "When the record was last modified.", "ISO-8601 timestamp"),
                ("effective_load_kg", "Derived single load figure (see Derived columns).", "number, kg (may be empty)"),
                ("volume_kg", "Derived volume load (see Derived columns).", "number, kg (may be empty)"),
                ("estimated_1rm_kg", "Derived Epley one-rep-max estimate (see Derived columns).", "number, kg (may be empty)"),
                ("superset_group", "Numeric group id linking sets performed as a superset.", "integer (may be empty)")
            ]
        )
    }

    private static func exercisesSection() -> String {
        section(
            title: "exercises.csv",
            blurb: "The user's exercise library (one row per exercise).",
            rows: [
                ("exercise_id", "Unique id of the exercise.", "UUID"),
                ("canonical_name", "Primary name of the exercise.", "text"),
                ("category", "Broad muscle/category grouping.", enumValues(ExerciseCategory.self)),
                ("primary_muscles", "Primary muscles worked.", "`;`-separated list of: " + enumValuesInline(MuscleGroup.self)),
                ("secondary_muscles", "Secondary muscles worked.", "`;`-separated list (same values as primary_muscles)"),
                ("equipment", "Equipment used.", enumValues(Equipment.self)),
                ("movement_pattern", "Movement pattern classification.", enumValues(MovementPattern.self)),
                ("default_weight_mode", "Default weight mode for new sets of this exercise.", enumValues(WeightMode.self)),
                ("archived", "Whether the exercise is archived/hidden.", "boolean"),
                ("notes", "Free-text exercise notes.", "text"),
                ("created_at", "When the record was created.", "ISO-8601 timestamp"),
                ("updated_at", "When the record was last modified.", "ISO-8601 timestamp"),
                ("is_goal_exercise", "Whether the exercise has a tracked goal.", "boolean"),
                ("is_favorite", "Whether the exercise is marked favourite.", "boolean")
            ]
        )
    }

    private static func exerciseAliasesSection() -> String {
        section(
            title: "exercise_aliases.csv",
            blurb: "Alternative names for exercises (one row per alias).",
            rows: [
                ("alias_id", "Unique id of the alias.", "UUID"),
                ("exercise_id", "Exercise this alias belongs to.", "UUID → exercises.csv (may be empty)"),
                ("alias_name", "The alternative name.", "text"),
                ("language_optional", "Optional language tag for the alias.", "text (may be empty)"),
                ("created_at", "When the record was created.", "ISO-8601 timestamp")
            ]
        )
    }

    private static func healthWorkoutsSection() -> String {
        section(
            title: "health_workouts.csv",
            blurb: "Apple Health workouts imported into the app (one row per imported workout).",
            rows: [
                ("health_workout_id", "Unique id of the imported record.", "UUID"),
                ("apple_health_uuid", "Apple Health's own UUID for the workout.", "text"),
                ("workout_type", "Apple Health activity type name.", "text"),
                ("start_time", "Workout start.", "ISO-8601 timestamp"),
                ("end_time", "Workout end.", "ISO-8601 timestamp"),
                ("duration_seconds", "Workout duration.", "number, seconds"),
                ("active_energy_kcal", "Active energy burned.", "number, kcal (may be empty)"),
                ("total_energy_kcal", "Total energy burned.", "number, kcal (may be empty)"),
                ("avg_heart_rate_bpm", "Average heart rate.", "number, bpm (may be empty)"),
                ("min_heart_rate_bpm", "Minimum heart rate.", "number, bpm (may be empty)"),
                ("max_heart_rate_bpm", "Maximum heart rate.", "number, bpm (may be empty)"),
                ("source_name", "Name of the source app/device.", "text (may be empty)"),
                ("source_device", "Recording device description.", "text (may be empty)"),
                ("imported_at", "When the workout was imported.", "ISO-8601 timestamp"),
                ("linked_workout_id", "Fit session this health workout is linked to, if any.", "UUID → workouts.csv (may be empty)")
            ]
        )
    }

    private static func heartRateSummarySection() -> String {
        section(
            title: "heart_rate_summary.csv",
            blurb: "Per-imported-workout heart-rate summary, including time-in-zone. Zone columns are blank for workouts imported before zone tracking existed.",
            rows: [
                ("workout_id", "Linked Fit session, if any.", "UUID → workouts.csv (may be empty)"),
                ("health_workout_id", "Imported health workout this summary belongs to.", "UUID → health_workouts.csv"),
                ("avg_hr_bpm", "Average heart rate.", "number, bpm (may be empty)"),
                ("min_hr_bpm", "Minimum heart rate.", "number, bpm (may be empty)"),
                ("max_hr_bpm", "Maximum heart rate.", "number, bpm (may be empty)"),
                ("hr_samples_count", "Number of heart-rate samples.", "integer (may be empty)"),
                ("zone_1_seconds", "Time in HR zone 1 (~50–60% of max HR).", "number, seconds (may be empty)"),
                ("zone_2_seconds", "Time in HR zone 2 (~60–70% of max HR).", "number, seconds (may be empty)"),
                ("zone_3_seconds", "Time in HR zone 3 (~70–80% of max HR).", "number, seconds (may be empty)"),
                ("zone_4_seconds", "Time in HR zone 4 (~80–90% of max HR).", "number, seconds (may be empty)"),
                ("zone_5_seconds", "Time in HR zone 5 (≥90% of max HR).", "number, seconds (may be empty)")
            ]
        )
    }

    private static func bodyWeightSection() -> String {
        section(
            title: "body_weight.csv",
            blurb: "Body-weight log (one row per entry).",
            rows: [
                ("body_weight_entry_id", "Unique id of the entry.", "UUID"),
                ("timestamp", "When the weight was recorded.", "ISO-8601 timestamp"),
                ("weight_kg", "Recorded body weight.", "number, kg"),
                ("source", "Where the entry came from.", enumValues(DataSource.self)),
                ("apple_health_sample_id", "Apple Health sample id, when imported.", "text (may be empty)"),
                ("notes", "Free-text notes.", "text")
            ]
        )
    }

    private static func sleepSection() -> String {
        section(
            title: "sleep.csv",
            blurb: "Sleep log (one row per night/entry).",
            rows: [
                ("sleep_entry_id", "Unique id of the entry.", "UUID"),
                ("date", "Calendar date the entry is attributed to.", "ISO-8601 timestamp"),
                ("start_time", "Sleep start.", "ISO-8601 timestamp (may be empty)"),
                ("end_time", "Sleep end.", "ISO-8601 timestamp (may be empty)"),
                ("duration_seconds", "Total sleep duration.", "number, seconds (may be empty)"),
                ("sleep_source", "Where the entry came from.", enumValues(DataSource.self)),
                ("subjective_sleep_quality", "Subjective sleep quality.", enumValues(SleepQuality.self)),
                ("apple_health_sample_id", "Apple Health sample id, when imported.", "text (may be empty)"),
                ("notes", "Free-text notes.", "text")
            ]
        )
    }

    private static func journalEntriesSection() -> String {
        section(
            title: "journal_entries.csv",
            blurb: "Free-text journal notes attached to workouts/exercises/sets (one row per note).",
            rows: [
                ("journal_entry_id", "Unique id of the entry.", "UUID"),
                ("workout_id", "Session the note is attached to, if any.", "UUID → workouts.csv (may be empty)"),
                ("exercise_id_optional", "Exercise the note is attached to, if any.", "UUID → exercises.csv (may be empty)"),
                ("set_id_optional", "Set the note is attached to, if any.", "UUID → sets.csv (may be empty)"),
                ("timestamp", "When the note was written.", "ISO-8601 timestamp"),
                ("entry_type", "What the note is about.", enumValues(JournalEntryType.self)),
                ("text", "The note text.", "text"),
                ("created_at", "When the record was created.", "ISO-8601 timestamp"),
                ("updated_at", "When the record was last modified.", "ISO-8601 timestamp")
            ]
        )
    }

    // MARK: - Scales

    private static func scalesSection() -> String {
        let effort = (0...5).map { "| \($0) | \(EffortScale.label(for: $0)) |" }.joined(separator: "\n")
        let energy = (0...5).map { "| \($0) | \(EnergyScale.label(for: $0)) |" }.joined(separator: "\n")
        let stress = (0...5).map { "| \($0) | \(StressScale.label(for: $0)) |" }.joined(separator: "\n")
        return """
        ## Scales (0–5)

        Three subjective 0–5 scales are used. Higher numbers mean *more* of the
        named quality.

        ### effort_0_5 (per set) — "\(EffortScale.question)"

        | value | meaning |
        | --- | --- |
        \(effort)

        ### energy_before_0_5 (per session) — "\(EnergyScale.question)"

        | value | meaning |
        | --- | --- |
        \(energy)

        ### stress_0_5 (per session) — "\(StressScale.question)"

        | value | meaning |
        | --- | --- |
        \(stress)


        """
    }

    // MARK: - Derived columns

    private static func derivedSection() -> String {
        """
        ## Derived columns

        These `sets.csv` columns are computed by the app, not entered by the user.
        They are convenience figures; the source columns (`weight_kg`,
        `body_weight_kg`, `assistance_kg`, `added_weight_kg`, `reps`,
        `weight_mode`) remain authoritative.

        ### effective_load_kg

        A single load figure that collapses the four weight modes:

        - `external` → `weight_kg`
        - `bodyweight` → `body_weight_kg`
        - `assistedBodyweight` → `body_weight_kg − assistance_kg`
        - `addedBodyweight` → `body_weight_kg + added_weight_kg` (falls back to
          `weight_kg` when body weight is unknown)
        - `unknown` → `weight_kg`, else `body_weight_kg`

        Empty when the inputs needed for the mode are missing.

        ### volume_kg

        `effective_load_kg × reps`. Empty when either input is missing.

        ### estimated_1rm_kg

        Epley one-rep-max estimate, only for `external` and `addedBodyweight`
        modes with a positive load and reps:

        - `reps == 1` → `effective_load_kg`
        - otherwise → `effective_load_kg × (1 + reps / 30)`

        Empty otherwise. This is an estimate, not a measured max.
        """
    }

    // MARK: - Formatting helpers

    /// Render one `## file` section with a column table.
    private static func section(title: String, blurb: String, rows: [(String, String, String)]) -> String {
        var out = "## \(title)\n\n\(blurb)\n\n"
        out += "| column | meaning | type / units / allowed values |\n"
        out += "| --- | --- | --- |\n"
        for (column, meaning, type) in rows {
            out += "| `\(column)` | \(meaning) | \(type) |\n"
        }
        out += "\n\n"
        return out
    }

    /// "`raw` (display), …" for every case of an option enum, for an "allowed
    /// values" cell. Reads the real raw values from the enum so the dictionary
    /// cannot drift from the source of truth.
    private static func enumValues<T: DisplayableOption>(_ type: T.Type) -> String where T.AllCases: Sequence {
        "one of: " + type.allCases.map { "`\($0.rawValue)` (\($0.displayName))" }.joined(separator: ", ")
    }

    /// Inline list of just the raw values, for embedding inside a sentence.
    private static func enumValuesInline<T: DisplayableOption>(_ type: T.Type) -> String where T.AllCases: Sequence {
        type.allCases.map { "`\($0.rawValue)`" }.joined(separator: ", ")
    }
}
