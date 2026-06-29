import Foundation
import SwiftData
import XCTest
@testable import Fit

/// Locks the F26 data-loss fix — the only real data-loss bug the app ever had:
/// the JSON importer upserts *by id* and must NEVER blank an already-populated
/// optional field when a re-import omits it. The importer guards every such field
/// with `if let value = dto.field { model.field = value }`, so an absent/null key
/// leaves the existing value untouched; a present key updates it.
///
/// These tests drive the REAL `DataImportService().importJSON(_:into:)` against a
/// live `ModelContext` on the single shared test container (`ModelTestSupport`).
/// Because that store is shared across the whole test process, every test uses a
/// fresh `UUID()` and asserts only on its own workout — never on global state.
///
/// The JSON payloads are hand-built dictionaries serialized with
/// `JSONSerialization`, using the exact snake_case keys from
/// `DataImportService`'s `CodingKeys` (`workout_id`, `start_time`, `title`,
/// `session_metadata.notes`). This gives precise control over which keys are
/// present vs. absent, which is the whole point of the regression.
@MainActor
final class ImportIntegrityTests: XCTestCase {

    private let service = DataImportService()

    /// Serialize a Fit-export-shaped dictionary to JSON `Data`.
    private func json(_ object: [String: Any]) throws -> Data {
        try JSONSerialization.data(withJSONObject: object, options: [])
    }

    /// A single-workout export document. `title` / `notes` are included only when
    /// non-nil, so a `nil` argument means the key is OMITTED entirely (the case
    /// that used to blank the stored value before F26).
    private func workoutDocument(
        id: UUID,
        title: String?,
        notes: String?,
        startTime: Date = Date()
    ) -> [String: Any] {
        var workout: [String: Any] = [
            "workout_id": id.uuidString,
            "start_time": ExportFormatting.iso(startTime),
        ]
        if let title { workout["title"] = title }
        if let notes {
            // `notes` lives under session_metadata in the export schema.
            workout["session_metadata"] = ["notes": notes]
        }
        return ["workouts": [workout]]
    }

    /// Fetch a workout by id from the shared store.
    private func fetchWorkout(_ id: UUID, in context: ModelContext) throws -> WorkoutSession? {
        var descriptor = FetchDescriptor<WorkoutSession>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    // MARK: - Test A: omitted fields must NOT blank existing values (the regression)

    func testReimportOmittingTitleAndNotesPreservesExistingValues() throws {
        let context = ModelTestSupport.makeContext()
        let id = UUID()

        // Seed a populated workout and save.
        let workout = WorkoutSession(id: id, title: "Leg day")
        workout.notes = "felt strong"
        context.insert(workout)
        try context.save()

        // Re-import the SAME id with title & notes ABSENT.
        let data = try json(workoutDocument(id: id, title: nil, notes: nil))
        let summary = try service.importJSON(data, into: context)

        // It matched the existing workout (an update, not an insert).
        XCTAssertEqual(summary.updatedWorkouts, 1)
        XCTAssertEqual(summary.insertedWorkouts, 0)

        // The populated values must STILL be there — not blanked.
        let reloaded = try XCTUnwrap(try fetchWorkout(id, in: context))
        XCTAssertEqual(reloaded.title, "Leg day", "Re-import omitting title must not blank it.")
        XCTAssertEqual(reloaded.notes, "felt strong", "Re-import omitting notes must not blank it.")
    }

    // MARK: - Test B: a provided field DOES update (positive control)

    func testReimportWithTitleUpdatesIt() throws {
        let context = ModelTestSupport.makeContext()
        let id = UUID()

        let workout = WorkoutSession(id: id, title: "Leg day")
        workout.notes = "felt strong"
        context.insert(workout)
        try context.save()

        // Re-import the SAME id, this time PROVIDING a new title (notes still absent).
        let data = try json(workoutDocument(id: id, title: "New title", notes: nil))
        let summary = try service.importJSON(data, into: context)

        XCTAssertEqual(summary.updatedWorkouts, 1)

        let reloaded = try XCTUnwrap(try fetchWorkout(id, in: context))
        XCTAssertEqual(reloaded.title, "New title", "A provided title must update the stored value.")
        // notes was omitted → still preserved.
        XCTAssertEqual(reloaded.notes, "felt strong", "Omitted notes must remain unchanged.")
    }

    // MARK: - Optional: the same preservation guarantee for a set's notes

    func testReimportOmittingSetNotesPreservesExistingValue() throws {
        let context = ModelTestSupport.makeContext()
        let workoutId = UUID()
        let setId = UUID()

        // Seed a workout with one set carrying notes.
        let workout = WorkoutSession(id: workoutId, title: "Push day")
        context.insert(workout)
        let set = WorkoutSet(id: setId)
        set.notes = "top set, paused"
        set.workout = workout
        context.insert(set)
        try context.save()

        // Re-import the workout + set by id, with the set's `notes` ABSENT.
        let setDict: [String: Any] = [
            "set_id": setId.uuidString,
            "set_index": 0,
        ]
        let document: [String: Any] = [
            "workouts": [[
                "workout_id": workoutId.uuidString,
                "start_time": ExportFormatting.iso(Date()),
                "sets": [setDict],
            ]],
        ]
        let summary = try service.importJSON(try json(document), into: context)
        XCTAssertEqual(summary.updatedSets, 1)

        var descriptor = FetchDescriptor<WorkoutSet>(predicate: #Predicate { $0.id == setId })
        descriptor.fetchLimit = 1
        let reloaded = try XCTUnwrap(try context.fetch(descriptor).first)
        XCTAssertEqual(reloaded.notes, "top set, paused", "Re-import omitting a set's notes must not blank it.")
    }
}
