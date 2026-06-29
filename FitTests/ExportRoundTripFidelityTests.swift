import Foundation
import SwiftData
import XCTest
@testable import Fit

/// F31 — the end-to-end JSON round-trip fidelity test. This locks the app's
/// literal reason for existing (SPEC §1/§30): capture data and export it cleanly
/// so an external AI can analyze it, AND restore it without loss.
///
/// What it does:
///   1. Builds a rich dataset as **un-inserted** `@Model` objects (so it never
///      creates a second `ModelContainer` — the F16/F30 constraint). Relationships
///      are wired explicitly in BOTH directions because un-inserted inverses do
///      not auto-populate.
///   2. Runs the REAL `JSONExporter.encode(_:request:)` to produce the export
///      JSON (`ExportDataSet` + a full-coverage `ExportRequest`).
///   3. Imports that JSON into a FRESH `ModelContext` of the single shared
///      `PersistenceController.testContainer` via the REAL
///      `DataImportService().importJSON(_:into:)`. Ids are unique, so this is a
///      clean INSERT.
///   4. Fetches every entity back by its id and asserts each field equals the
///      original — ids, enums (compared via their typed accessors), kg Doubles
///      (with tolerance), reps/effort, notes, and that the set's `workout`/
///      `exercise` relationships resolve to the right ids.
///
/// Timestamps go through ISO-8601 with `.withInternetDateTime` (no fractional
/// seconds), so they are compared with a 1s tolerance rather than exact equality.
///
/// Because the shared store is NOT reset between tests, every id is a fresh
/// `UUID()` and assertions are made only on this test's own objects.
@MainActor
final class ExportRoundTripFidelityTests: XCTestCase {

    /// Tolerance for kg comparisons (export Doubles are exact, but use a small
    /// epsilon defensively for any derived arithmetic).
    private let kgAccuracy = 0.0001
    /// Timestamps round-trip through second-resolution ISO-8601.
    private let timeAccuracy: TimeInterval = 1.0

    func testFullExportImportRoundTripPreservesEveryField() throws {
        // MARK: - Ids (unique per run, the only thing we assert against)
        let exerciseId = UUID()
        let aliasId = UUID()
        let workoutId = UUID()
        let externalSetId = UUID()
        let bodyweightSetId = UUID()
        let assistedSetId = UUID()
        let addedSetId = UUID()
        let bodyWeightEntryId = UUID()
        let sleepEntryId = UUID()
        let journalId = UUID()

        // A fixed base time so the round-trip is deterministic. Truncated to whole
        // seconds so the 1s ISO-8601 comparison is comfortable.
        let base = Date(timeIntervalSince1970: 1_700_000_000) // 2023-11-14T...Z

        // MARK: - Exercise (+ alias), wired both ways (un-inserted, no context)
        let exercise = Exercise(
            id: exerciseId,
            canonicalName: "Weighted Pull-up",
            category: .back,
            equipment: .bodyweight,
            movementPattern: .verticalPull,
            defaultWeightMode: .addedBodyweight,
            primaryMuscles: [.lats, .upperBack],
            secondaryMuscles: [.biceps, .rearDelts],
            isGoalExercise: true,
            isFavorite: true
        )
        exercise.notes = "Strict, no kipping."
        exercise.archived = false

        let alias = ExerciseAlias(
            id: aliasId,
            aliasName: "Подтягивания с весом",
            languageOptional: "ru",
            exercise: exercise
        )
        // Un-inserted inverse must be wired by hand.
        exercise.aliases = [alias]

        // MARK: - Workout session with rich subjective metadata
        let workout = WorkoutSession(
            id: workoutId,
            title: "Pull day",
            startTime: base,
            endTime: base.addingTimeInterval(3600),
            timezoneIdentifier: "Europe/Prague",
            isBackfilled: true
        )
        workout.goal = .strength
        workout.location = .gym
        workout.energyBefore = 4
        workout.soreness = .mild
        workout.painToday = .yesOkay
        workout.sleepQualitySubjective = .good
        workout.stressLevel = 2
        workout.foodTiming = .ateRecently
        workout.caffeine = .coffee
        workout.bodyWeightManualKg = 81.5
        workout.notes = "Felt strong, grip held, deep reps."

        // MARK: - Sets across all four weight modes
        // .external
        let externalSet = WorkoutSet(
            id: externalSetId,
            exercise: exercise,
            exerciseNameAtTime: "Weighted Pull-up",
            setIndex: 0,
            timestamp: base.addingTimeInterval(60),
            weightMode: .external,
            source: .manual
        )
        externalSet.weightKg = 100.0
        externalSet.reps = 5
        externalSet.effort = 4
        externalSet.repsLeft = .two
        externalSet.formQuality = .good
        externalSet.limiter = .muscleFailed
        externalSet.painSeverity = .mild
        externalSet.painLocation = .elbow
        externalSet.notes = "Top set, comma, and \"quotes\"."
        externalSet.workout = workout
        externalSet.exercise = exercise

        // .bodyweight
        let bodyweightSet = WorkoutSet(
            id: bodyweightSetId,
            exercise: exercise,
            exerciseNameAtTime: "Weighted Pull-up",
            setIndex: 1,
            timestamp: base.addingTimeInterval(120),
            weightMode: .bodyweight,
            source: .manual
        )
        bodyweightSet.bodyWeightKg = 81.5
        bodyweightSet.reps = 8
        bodyweightSet.effort = 3
        bodyweightSet.formQuality = .okay
        bodyweightSet.limiter = .gripFailed
        bodyweightSet.notes = "Pure bodyweight."
        bodyweightSet.workout = workout
        bodyweightSet.exercise = exercise

        // .assistedBodyweight
        let assistedSet = WorkoutSet(
            id: assistedSetId,
            exercise: exercise,
            exerciseNameAtTime: "Weighted Pull-up",
            setIndex: 2,
            timestamp: base.addingTimeInterval(180),
            weightMode: .assistedBodyweight,
            source: .manual
        )
        assistedSet.bodyWeightKg = 81.5
        assistedSet.assistanceKg = 20.0
        assistedSet.reps = 10
        assistedSet.effort = 2
        assistedSet.formQuality = .shaky
        assistedSet.limiter = .breathCardio
        assistedSet.notes = "Band assisted."
        assistedSet.workout = workout
        assistedSet.exercise = exercise

        // .addedBodyweight
        let addedSet = WorkoutSet(
            id: addedSetId,
            exercise: exercise,
            exerciseNameAtTime: "Weighted Pull-up",
            setIndex: 3,
            timestamp: base.addingTimeInterval(240),
            weightMode: .addedBodyweight,
            source: .manual
        )
        addedSet.bodyWeightKg = 81.5
        addedSet.addedWeightKg = 15.0
        addedSet.reps = 6
        addedSet.effort = 5
        addedSet.repsLeft = .zero
        addedSet.formQuality = .good
        addedSet.limiter = .muscleFailed
        addedSet.notes = "Weighted, +15kg."
        addedSet.workout = workout
        addedSet.exercise = exercise

        let allSets = [externalSet, bodyweightSet, assistedSet, addedSet]
        // Wire the parent-side inverses by hand (un-inserted graph).
        workout.sets = allSets
        exercise.sets = allSets

        // MARK: - Body-weight, sleep, journal entries
        let bodyWeight = BodyWeightEntry(
            id: bodyWeightEntryId,
            timestamp: base.addingTimeInterval(-3600),
            weightKg: 81.5,
            source: .manual
        )
        bodyWeight.notes = "Morning, fasted."

        let sleep = SleepEntry(id: sleepEntryId, date: base.addingTimeInterval(-43200), source: .manual)
        sleep.startTime = base.addingTimeInterval(-43200)
        sleep.endTime = base.addingTimeInterval(-18000)
        sleep.durationSeconds = 25200 // 7h
        sleep.subjectiveSleepQuality = .good
        sleep.notes = "Solid night."

        let journal = JournalEntry(
            id: journalId,
            workout: workout,
            exerciseIdOptional: exerciseId,
            setIdOptional: externalSetId,
            timestamp: base.addingTimeInterval(300),
            entryType: .workoutNote,
            text: "Great session, PR on the weighted pull-up."
        )
        // The exporter nests journal entries under their workout via
        // `j.workout?.id == w.id` AND reads them from `data.journalEntries`.
        workout.journalEntries = [journal]

        // MARK: - Build the ExportDataSet + a full-coverage ExportRequest
        let dataSet = ExportDataSet(
            generatedAt: base,
            workouts: [workout],
            sets: allSets,
            exercises: [exercise],
            exerciseAliases: [alias],
            healthWorkouts: [],
            bodyWeightEntries: [bodyWeight],
            sleepEntries: [sleep],
            journalEntries: [journal]
        )

        let request = ExportRequest(
            dateRangeStart: base.addingTimeInterval(-86400),
            dateRangeEnd: base.addingTimeInterval(86400),
            format: .json,
            includeHealthData: true,
            includeJournal: true,
            includeBodyWeight: true,
            includeSleep: true
        )

        // MARK: - Export → JSON (the real exporter)
        let json = try JSONExporter.encode(dataSet, request: request)
        XCTAssertFalse(json.isEmpty, "Exporter produced empty JSON.")

        // MARK: - Import into a FRESH context of the shared container
        let ctx = ModelContext(PersistenceController.testContainer)
        let summary = try DataImportService().importJSON(json, into: ctx)

        // Fresh inserts (ids are unique and not yet in the shared store).
        XCTAssertGreaterThanOrEqual(summary.insertedWorkouts, 1, "Workout should be inserted.")
        XCTAssertGreaterThanOrEqual(summary.insertedSets, 4, "All four sets should be inserted.")
        XCTAssertGreaterThanOrEqual(summary.insertedExercises, 1, "Exercise should be inserted.")
        XCTAssertGreaterThanOrEqual(summary.insertedAliases, 1, "Alias should be inserted.")
        XCTAssertGreaterThanOrEqual(summary.insertedBodyWeightEntries, 1, "Body-weight entry should be inserted.")
        XCTAssertGreaterThanOrEqual(summary.insertedSleepEntries, 1, "Sleep entry should be inserted.")
        XCTAssertGreaterThanOrEqual(summary.insertedJournalEntries, 1, "Journal entry should be inserted.")

        // MARK: - Fidelity: Exercise (+ alias)
        let rtExercise = try XCTUnwrap(fetchOne(Exercise.self, id: exerciseId, in: ctx), "Exercise not found.")
        XCTAssertEqual(rtExercise.canonicalName, "Weighted Pull-up")
        XCTAssertEqual(rtExercise.category, .back)
        XCTAssertEqual(rtExercise.equipment, .bodyweight)
        XCTAssertEqual(rtExercise.movementPattern, .verticalPull)
        XCTAssertEqual(rtExercise.defaultWeightMode, .addedBodyweight)
        XCTAssertEqual(Set(rtExercise.primaryMuscles), [.lats, .upperBack])
        XCTAssertEqual(Set(rtExercise.secondaryMuscles), [.biceps, .rearDelts])
        XCTAssertEqual(rtExercise.notes, "Strict, no kipping.")
        XCTAssertTrue(rtExercise.isGoalExercise)
        XCTAssertTrue(rtExercise.isFavorite)
        XCTAssertFalse(rtExercise.archived)

        let rtAlias = try XCTUnwrap((rtExercise.aliases ?? []).first { $0.id == aliasId }, "Alias not found.")
        XCTAssertEqual(rtAlias.aliasName, "Подтягивания с весом")
        XCTAssertEqual(rtAlias.languageOptional, "ru")
        XCTAssertEqual(rtAlias.exercise?.id, exerciseId, "Alias should resolve back to its exercise.")

        // MARK: - Fidelity: Workout + session metadata
        let rtWorkout = try XCTUnwrap(fetchOne(WorkoutSession.self, id: workoutId, in: ctx), "Workout not found.")
        XCTAssertEqual(rtWorkout.title, "Pull day")
        XCTAssertEqual(rtWorkout.goal, .strength)
        XCTAssertEqual(rtWorkout.location, .gym)
        XCTAssertEqual(rtWorkout.energyBefore, 4)
        XCTAssertEqual(rtWorkout.soreness, .mild)
        XCTAssertEqual(rtWorkout.painToday, .yesOkay)
        XCTAssertEqual(rtWorkout.sleepQualitySubjective, .good)
        XCTAssertEqual(rtWorkout.stressLevel, 2)
        XCTAssertEqual(rtWorkout.foodTiming, .ateRecently)
        XCTAssertEqual(rtWorkout.caffeine, .coffee)
        XCTAssertEqual(rtWorkout.bodyWeightManualKg ?? .nan, 81.5, accuracy: kgAccuracy)
        XCTAssertEqual(rtWorkout.notes, "Felt strong, grip held, deep reps.")
        XCTAssertEqual(rtWorkout.timezoneIdentifier, "Europe/Prague")
        XCTAssertTrue(rtWorkout.isBackfilled)
        XCTAssertEqual(rtWorkout.startTime.timeIntervalSince1970, base.timeIntervalSince1970, accuracy: timeAccuracy)
        XCTAssertEqual(
            (rtWorkout.endTime ?? .distantPast).timeIntervalSince1970,
            base.addingTimeInterval(3600).timeIntervalSince1970,
            accuracy: timeAccuracy
        )

        // MARK: - Fidelity: each set
        try assertSet(
            id: externalSetId, in: ctx, expectedWorkoutId: workoutId, expectedExerciseId: exerciseId,
            mode: .external, nameAtTime: "Weighted Pull-up", setIndex: 0,
            weightKg: 100.0, bodyWeightKg: nil, assistanceKg: nil, addedWeightKg: nil,
            reps: 5, effort: 4, repsLeft: .two, formQuality: .good, limiter: .muscleFailed,
            painSeverity: .mild, painLocation: .elbow,
            notes: "Top set, comma, and \"quotes\"."
        )
        try assertSet(
            id: bodyweightSetId, in: ctx, expectedWorkoutId: workoutId, expectedExerciseId: exerciseId,
            mode: .bodyweight, nameAtTime: "Weighted Pull-up", setIndex: 1,
            weightKg: nil, bodyWeightKg: 81.5, assistanceKg: nil, addedWeightKg: nil,
            reps: 8, effort: 3, repsLeft: nil, formQuality: .okay, limiter: .gripFailed,
            painSeverity: nil, painLocation: nil,
            notes: "Pure bodyweight."
        )
        try assertSet(
            id: assistedSetId, in: ctx, expectedWorkoutId: workoutId, expectedExerciseId: exerciseId,
            mode: .assistedBodyweight, nameAtTime: "Weighted Pull-up", setIndex: 2,
            weightKg: nil, bodyWeightKg: 81.5, assistanceKg: 20.0, addedWeightKg: nil,
            reps: 10, effort: 2, repsLeft: nil, formQuality: .shaky, limiter: .breathCardio,
            painSeverity: nil, painLocation: nil,
            notes: "Band assisted."
        )
        try assertSet(
            id: addedSetId, in: ctx, expectedWorkoutId: workoutId, expectedExerciseId: exerciseId,
            mode: .addedBodyweight, nameAtTime: "Weighted Pull-up", setIndex: 3,
            weightKg: nil, bodyWeightKg: 81.5, assistanceKg: nil, addedWeightKg: 15.0,
            reps: 6, effort: 5, repsLeft: .zero, formQuality: .good, limiter: .muscleFailed,
            painSeverity: nil, painLocation: nil,
            notes: "Weighted, +15kg."
        )

        // MARK: - Fidelity: body weight
        let rtBodyWeight = try XCTUnwrap(fetchOne(BodyWeightEntry.self, id: bodyWeightEntryId, in: ctx), "Body-weight not found.")
        XCTAssertEqual(rtBodyWeight.weightKg, 81.5, accuracy: kgAccuracy)
        XCTAssertEqual(rtBodyWeight.source, .manual)
        XCTAssertEqual(rtBodyWeight.notes, "Morning, fasted.")
        XCTAssertEqual(
            rtBodyWeight.timestamp.timeIntervalSince1970,
            base.addingTimeInterval(-3600).timeIntervalSince1970,
            accuracy: timeAccuracy
        )

        // MARK: - Fidelity: sleep
        let rtSleep = try XCTUnwrap(fetchOne(SleepEntry.self, id: sleepEntryId, in: ctx), "Sleep not found.")
        XCTAssertEqual(rtSleep.durationSeconds ?? .nan, 25200, accuracy: 0.5)
        XCTAssertEqual(rtSleep.subjectiveSleepQuality, .good)
        XCTAssertEqual(rtSleep.source, .manual)
        XCTAssertEqual(rtSleep.notes, "Solid night.")

        // MARK: - Fidelity: journal
        let rtJournal = try XCTUnwrap(fetchOne(JournalEntry.self, id: journalId, in: ctx), "Journal not found.")
        XCTAssertEqual(rtJournal.entryType, .workoutNote)
        XCTAssertEqual(rtJournal.text, "Great session, PR on the weighted pull-up.")
        XCTAssertEqual(rtJournal.workout?.id, workoutId, "Journal should resolve back to its workout.")
        XCTAssertEqual(rtJournal.exerciseIdOptional, exerciseId)
        XCTAssertEqual(rtJournal.setIdOptional, externalSetId)
    }

    // MARK: - Helpers

    /// Per-type `#Predicate` fetch by `id`. SwiftData's `#Predicate` needs the
    /// concrete keypath, so dispatch on the concrete type.
    private func fetchOne<T: PersistentModel>(_ type: T.Type, id: UUID, in ctx: ModelContext) -> T? {
        switch type {
        case is Exercise.Type:
            var d = FetchDescriptor<Exercise>(predicate: #Predicate { $0.id == id }); d.fetchLimit = 1
            return (try? ctx.fetch(d))?.first as? T
        case is WorkoutSession.Type:
            var d = FetchDescriptor<WorkoutSession>(predicate: #Predicate { $0.id == id }); d.fetchLimit = 1
            return (try? ctx.fetch(d))?.first as? T
        case is WorkoutSet.Type:
            var d = FetchDescriptor<WorkoutSet>(predicate: #Predicate { $0.id == id }); d.fetchLimit = 1
            return (try? ctx.fetch(d))?.first as? T
        case is BodyWeightEntry.Type:
            var d = FetchDescriptor<BodyWeightEntry>(predicate: #Predicate { $0.id == id }); d.fetchLimit = 1
            return (try? ctx.fetch(d))?.first as? T
        case is SleepEntry.Type:
            var d = FetchDescriptor<SleepEntry>(predicate: #Predicate { $0.id == id }); d.fetchLimit = 1
            return (try? ctx.fetch(d))?.first as? T
        case is JournalEntry.Type:
            var d = FetchDescriptor<JournalEntry>(predicate: #Predicate { $0.id == id }); d.fetchLimit = 1
            return (try? ctx.fetch(d))?.first as? T
        default:
            return nil
        }
    }

    /// Fetch a set by id and assert every round-tripped field. Mode-irrelevant kg
    /// fields are asserted nil so we also catch a mode mixing up its load fields.
    private func assertSet(
        id: UUID,
        in ctx: ModelContext,
        expectedWorkoutId: UUID,
        expectedExerciseId: UUID,
        mode: WeightMode,
        nameAtTime: String,
        setIndex: Int,
        weightKg: Double?,
        bodyWeightKg: Double?,
        assistanceKg: Double?,
        addedWeightKg: Double?,
        reps: Int?,
        effort: Int?,
        repsLeft: RepsLeft?,
        formQuality: FormQuality?,
        limiter: Limiter?,
        painSeverity: PainSeverity?,
        painLocation: PainLocation?,
        notes: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws {
        let set = try XCTUnwrap(fetchOne(WorkoutSet.self, id: id, in: ctx), "Set \(id) not found.", file: file, line: line)

        XCTAssertEqual(set.weightMode, mode, "weightMode", file: file, line: line)
        XCTAssertEqual(set.exerciseNameAtTime, nameAtTime, "exerciseNameAtTime", file: file, line: line)
        XCTAssertEqual(set.setIndex, setIndex, "setIndex", file: file, line: line)

        assertOptionalDouble(set.weightKg, weightKg, "weightKg", file: file, line: line)
        assertOptionalDouble(set.bodyWeightKg, bodyWeightKg, "bodyWeightKg", file: file, line: line)
        assertOptionalDouble(set.assistanceKg, assistanceKg, "assistanceKg", file: file, line: line)
        assertOptionalDouble(set.addedWeightKg, addedWeightKg, "addedWeightKg", file: file, line: line)

        XCTAssertEqual(set.reps, reps, "reps", file: file, line: line)
        XCTAssertEqual(set.effort, effort, "effort", file: file, line: line)
        XCTAssertEqual(set.repsLeft, repsLeft, "repsLeft", file: file, line: line)
        XCTAssertEqual(set.formQuality, formQuality, "formQuality", file: file, line: line)
        XCTAssertEqual(set.limiter, limiter, "limiter", file: file, line: line)
        XCTAssertEqual(set.painSeverity, painSeverity, "painSeverity", file: file, line: line)
        XCTAssertEqual(set.painLocation, painLocation, "painLocation", file: file, line: line)
        XCTAssertEqual(set.notes, notes, "notes", file: file, line: line)
        XCTAssertEqual(set.source, .manual, "source", file: file, line: line)

        XCTAssertEqual(set.workout?.id, expectedWorkoutId, "set.workout.id", file: file, line: line)
        XCTAssertEqual(set.exercise?.id, expectedExerciseId, "set.exercise.id", file: file, line: line)
    }

    private func assertOptionalDouble(
        _ actual: Double?,
        _ expected: Double?,
        _ label: String,
        file: StaticString,
        line: UInt
    ) {
        switch (actual, expected) {
        case (nil, nil):
            break
        case let (a?, e?):
            XCTAssertEqual(a, e, accuracy: kgAccuracy, label, file: file, line: line)
        default:
            XCTFail("\(label): expected \(String(describing: expected)) but got \(String(describing: actual))", file: file, line: line)
        }
    }
}
