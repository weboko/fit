import Foundation
import XCTest
@testable import Fit

/// Locks the CSV export **data contract** — the app's most important, AI-facing
/// surface (SPEC §12 "critical"). The external AI's whole analysis depends on the
/// exact CSV column names and their order (§12.4–12.13), so this suite encodes the
/// spec column lists *independently* (hard-coded below, not read from the
/// exporter) and asserts each per-file builder emits them, in order, as the start
/// of its header row. A future rename / reorder / removal of a spec column fails
/// the test even if the app still compiles.
///
/// The exporter appends documented *derived* columns after the spec ones (e.g.
/// sets.csv adds effective_load_kg…superset_group; workouts.csv adds timezone,
/// is_backfilled), so we assert the header *prefix* equals the spec list rather
/// than full equality — additive columns are allowed, reordering / dropping a
/// spec column is not.
///
/// Hermetic and context-free: empty/hand-built `ExportDataSet`s and un-inserted
/// `@Model` objects only — no `ModelContext`, no Health / network / UserDefaults.
@MainActor
final class ExportContractTests: XCTestCase {

    // MARK: - SPEC column lists (independent source of truth)

    // Hard-coded from SPEC.md §12.4–12.13. Do NOT derive these from the exporter:
    // the whole point is to catch a drift between spec and implementation.

    private static let workoutsSpec = [
        "workout_id", "start_time", "end_time", "duration_seconds", "title",
        "workout_goal", "location", "energy_before_0_5", "soreness",
        "pain_today", "sleep_quality_subjective", "stress_0_5", "food_timing",
        "caffeine", "body_weight_kg_manual", "body_weight_kg_imported",
        "apple_health_workout_id", "notes", "created_at", "updated_at",
    ]

    private static let setsSpec = [
        "set_id", "workout_id", "exercise_id", "exercise_name_at_time",
        "set_index", "timestamp", "weight_mode", "weight_kg", "body_weight_kg",
        "assistance_kg", "added_weight_kg", "reps", "effort_0_5", "reps_left",
        "form_quality", "limiter", "pain_severity", "pain_location",
        "is_warmup", "is_failed", "source", "notes", "created_at", "updated_at",
    ]

    private static let exercisesSpec = [
        "exercise_id", "canonical_name", "category", "primary_muscles",
        "secondary_muscles", "equipment", "movement_pattern",
        "default_weight_mode", "archived", "notes", "created_at", "updated_at",
    ]

    private static let exerciseAliasesSpec = [
        "alias_id", "exercise_id", "alias_name", "language_optional", "created_at",
    ]

    private static let healthWorkoutsSpec = [
        "health_workout_id", "apple_health_uuid", "workout_type", "start_time",
        "end_time", "duration_seconds", "active_energy_kcal", "total_energy_kcal",
        "avg_heart_rate_bpm", "min_heart_rate_bpm", "max_heart_rate_bpm",
        "source_name", "source_device", "imported_at",
    ]

    private static let heartRateSummarySpec = [
        "workout_id", "health_workout_id", "avg_hr_bpm", "min_hr_bpm",
        "max_hr_bpm", "hr_samples_count", "zone_1_seconds", "zone_2_seconds",
        "zone_3_seconds", "zone_4_seconds", "zone_5_seconds",
    ]

    private static let bodyWeightSpec = [
        "body_weight_entry_id", "timestamp", "weight_kg", "source",
        "apple_health_sample_id", "notes",
    ]

    private static let sleepSpec = [
        "sleep_entry_id", "date", "start_time", "end_time", "duration_seconds",
        "sleep_source", "subjective_sleep_quality", "apple_health_sample_id", "notes",
    ]

    private static let journalEntriesSpec = [
        "journal_entry_id", "workout_id", "exercise_id_optional", "set_id_optional",
        "timestamp", "entry_type", "text", "created_at", "updated_at",
    ]

    // MARK: - Helpers

    /// An empty data set — headers are emitted regardless of rows, so this is
    /// enough for header assertions.
    private func emptyDataSet() -> ExportDataSet {
        ExportDataSet(
            generatedAt: Date(),
            workouts: [],
            sets: [],
            exercises: [],
            exerciseAliases: [],
            healthWorkouts: [],
            bodyWeightEntries: [],
            sleepEntries: [],
            journalEntries: []
        )
    }

    /// Parse `document`'s header via the real `CSVParser` and assert its first
    /// `spec.count` columns equal `spec`, in order. Additive (derived) columns
    /// after the spec ones are allowed.
    private func assertHeaderPrefix(
        _ document: String,
        equals spec: [String],
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        guard let header = CSVParser.parse(document).first else {
            XCTFail("CSV document had no header row", file: file, line: line)
            return
        }
        XCTAssertGreaterThanOrEqual(
            header.count, spec.count,
            "Header has fewer columns (\(header.count)) than the spec requires (\(spec.count)).",
            file: file, line: line
        )
        XCTAssertEqual(
            Array(header.prefix(spec.count)), spec,
            "CSV header prefix does not match the SPEC column list/order.",
            file: file, line: line
        )
    }

    // MARK: - Part 1: per-file header contract

    func testWorkoutsHeaderMatchesSpec() {
        assertHeaderPrefix(CSVExporter.workouts(emptyDataSet()), equals: Self.workoutsSpec)
    }

    func testSetsHeaderMatchesSpec() {
        assertHeaderPrefix(CSVExporter.sets(emptyDataSet()), equals: Self.setsSpec)
    }

    func testExercisesHeaderMatchesSpec() {
        assertHeaderPrefix(CSVExporter.exercises(emptyDataSet()), equals: Self.exercisesSpec)
    }

    func testExerciseAliasesHeaderMatchesSpec() {
        assertHeaderPrefix(CSVExporter.exerciseAliases(emptyDataSet()), equals: Self.exerciseAliasesSpec)
    }

    func testHealthWorkoutsHeaderMatchesSpec() {
        assertHeaderPrefix(CSVExporter.healthWorkouts(emptyDataSet()), equals: Self.healthWorkoutsSpec)
    }

    func testHeartRateSummaryHeaderMatchesSpec() {
        assertHeaderPrefix(CSVExporter.heartRateSummary(emptyDataSet()), equals: Self.heartRateSummarySpec)
    }

    func testBodyWeightHeaderMatchesSpec() {
        assertHeaderPrefix(CSVExporter.bodyWeight(emptyDataSet()), equals: Self.bodyWeightSpec)
    }

    func testSleepHeaderMatchesSpec() {
        assertHeaderPrefix(CSVExporter.sleep(emptyDataSet()), equals: Self.sleepSpec)
    }

    func testJournalEntriesHeaderMatchesSpec() {
        assertHeaderPrefix(CSVExporter.journalEntries(emptyDataSet()), equals: Self.journalEntriesSpec)
    }

    /// Belt-and-braces: the spec prefix must be a *strict subset* of what the
    /// exporter emits for the files that document additive columns — i.e. the
    /// exporter genuinely appends derived columns after the spec block. Guards
    /// against someone "fixing" the prefix assertion by deleting derived columns.
    func testDerivedColumnsAreAppendedAfterSpec() {
        let data = emptyDataSet()
        let setsHeader = CSVParser.parse(CSVExporter.sets(data)).first ?? []
        XCTAssertGreaterThan(setsHeader.count, Self.setsSpec.count,
            "sets.csv should append derived columns after the spec block.")
        XCTAssertTrue(setsHeader.contains("effective_load_kg"))
        XCTAssertTrue(setsHeader.contains("superset_group"))

        let workoutsHeader = CSVParser.parse(CSVExporter.workouts(data)).first ?? []
        XCTAssertGreaterThan(workoutsHeader.count, Self.workoutsSpec.count,
            "workouts.csv should append derived columns after the spec block.")
        XCTAssertTrue(workoutsHeader.contains("timezone"))
        XCTAssertTrue(workoutsHeader.contains("is_backfilled"))
    }

    // MARK: - Part 2: round-trip data integrity

    /// Build a small, populated `ExportDataSet` by hand (no `ModelContext`) and
    /// assert that exporting `sets`/`workouts` then re-parsing with the real
    /// `CSVParser.parseKeyed` round-trips the key values: ids, weight, reps,
    /// and a notes field containing a comma (exercises the RFC-4180 quoting).
    ///
    /// Un-inserted `@Model` objects do NOT auto-populate inverse relationships,
    /// so we wire the relationships the exporter actually dereferences EXPLICITLY:
    /// `set.workout`, `set.exercise` (the sets builder reads `s.workout?.id` and
    /// `s.exercise?.id`) and, for symmetry / future-proofing, `workout.sets` and
    /// `exercise.sets`.
    func testSetsAndWorkoutsRoundTripKeyValues() {
        let exercise = Fixture.exercise(name: "Bench Press")

        let workout = WorkoutSession(title: "Push day")
        workout.notes = "felt strong, heavy, deep"   // contains a comma → must be quoted

        let set = Fixture.externalSet(
            weightKg: 102.5,
            reps: 5,
            exercise: exercise
        )
        set.effort = 4
        set.notes = "top set, paused"                // contains a comma → must be quoted

        // Wire the relationships the exporter reads (no auto-inverse off-context).
        set.workout = workout
        set.exercise = exercise
        workout.sets = [set]
        exercise.sets = [set]

        let data = ExportDataSet(
            generatedAt: Date(),
            workouts: [workout],
            sets: [set],
            exercises: [exercise],
            exerciseAliases: [],
            healthWorkouts: [],
            bodyWeightEntries: [],
            sleepEntries: [],
            journalEntries: []
        )

        // --- sets.csv ---
        let setsRows = CSVParser.parseKeyed(CSVExporter.sets(data))
        XCTAssertEqual(setsRows.count, 1)
        let setRow = setsRows[0]
        XCTAssertEqual(setRow["set_id"], set.id.uuidString)
        XCTAssertEqual(setRow["workout_id"], workout.id.uuidString)
        XCTAssertEqual(setRow["exercise_id"], exercise.id.uuidString)
        XCTAssertEqual(setRow["weight_kg"], "102.5")
        XCTAssertEqual(setRow["reps"], "5")
        XCTAssertEqual(setRow["effort_0_5"], "4")
        XCTAssertEqual(setRow["weight_mode"], WeightMode.external.rawValue)
        // Notes with a comma must survive RFC-4180 quoting byte-for-byte.
        XCTAssertEqual(setRow["notes"], "top set, paused")
        // Derived column is present and correct (effective load == external weight).
        XCTAssertEqual(setRow["effective_load_kg"], "102.5")

        // --- workouts.csv ---
        let workoutRows = CSVParser.parseKeyed(CSVExporter.workouts(data))
        XCTAssertEqual(workoutRows.count, 1)
        let workoutRow = workoutRows[0]
        XCTAssertEqual(workoutRow["workout_id"], workout.id.uuidString)
        XCTAssertEqual(workoutRow["title"], "Push day")
        XCTAssertEqual(workoutRow["notes"], "felt strong, heavy, deep")
    }

    /// The set's `workout_id` / `exercise_id` come from the *relationships*, not
    /// stored ids: when those relationships are nil the columns are empty (the
    /// exporter uses `s.workout?.id.uuidString ?? ""`). Pin that behaviour so the
    /// round-trip test above is meaningfully exercising the wiring.
    func testSetWithoutRelationshipsHasEmptyForeignKeys() {
        let set = Fixture.externalSet(weightKg: 60, reps: 8)   // no workout, no exercise
        let data = ExportDataSet(
            generatedAt: Date(),
            workouts: [],
            sets: [set],
            exercises: [],
            exerciseAliases: [],
            healthWorkouts: [],
            bodyWeightEntries: [],
            sleepEntries: [],
            journalEntries: []
        )
        let row = CSVParser.parseKeyed(CSVExporter.sets(data)).first
        XCTAssertEqual(row?["set_id"], set.id.uuidString)
        XCTAssertEqual(row?["workout_id"], "")
        XCTAssertEqual(row?["exercise_id"], "")
        XCTAssertEqual(row?["weight_kg"], "60")
        XCTAssertEqual(row?["reps"], "8")
    }
}
