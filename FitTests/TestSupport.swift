import Foundation
import SwiftData
import XCTest
@testable import Fit

/// Shared helpers for building hermetic, in-memory SwiftData fixtures.
///
/// `WorkoutSet` and `Exercise` are `@Model` types, so even though the values we
/// assert on (`effectiveLoadKg`, `volumeKg`, …) are pure arithmetic, the objects
/// must live in a `ModelContext`. We use `PersistenceController.makePreviewContainer(seeded:false)`
/// for an empty, in-memory store (no CloudKit, no disk, no network). It is
/// `@MainActor`, so every test class that uses these helpers is `@MainActor`.
@MainActor
enum Fixture {

    /// A fresh, empty, in-memory model context for one test.
    static func emptyContext() -> ModelContext {
        let container = PersistenceController.makePreviewContainer(seeded: false)
        return container.mainContext
    }

    /// Insert an external-load `WorkoutSet` (the common barbell case) into `context`.
    /// `weightKg`/`reps`/`isWarmup` are set as properties after init, matching the
    /// real model (the initializer only takes identity + mode + source).
    @discardableResult
    static func externalSet(
        in context: ModelContext,
        weightKg: Double?,
        reps: Int?,
        isWarmup: Bool = false,
        timestamp: Date = Date(),
        exercise: Exercise? = nil
    ) -> WorkoutSet {
        let set = WorkoutSet(
            exercise: exercise,
            timestamp: timestamp,
            weightMode: .external
        )
        set.weightKg = weightKg
        set.reps = reps
        set.isWarmup = isWarmup
        context.insert(set)
        return set
    }

    /// Insert a bare `Exercise` into `context`.
    @discardableResult
    static func exercise(
        in context: ModelContext,
        name: String = "Bench Press",
        primaryMuscles: [MuscleGroup] = [.chest]
    ) -> Exercise {
        let ex = Exercise(canonicalName: name, primaryMuscles: primaryMuscles)
        context.insert(ex)
        return ex
    }
}
