import Foundation
import XCTest
@testable import Fit

/// Shared helpers for building hermetic test fixtures.
///
/// `WorkoutSet` and `Exercise` are `@Model` types, but the values we assert on
/// (`effectiveLoadKg`, `volumeKg`, …) are pure arithmetic over stored/computed
/// properties. SwiftData supports reading those on *un-inserted* model instances,
/// so the fixtures need no `ModelContext` and no container at all (avoiding the
/// test-host's CloudKit container entirely).
@MainActor
enum Fixture {

    /// Build an external-load `WorkoutSet` (the common barbell case).
    /// `weightKg`/`reps`/`isWarmup` are set as properties after init, matching the
    /// real model (the initializer only takes identity + mode + source).
    static func externalSet(
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
        return set
    }

    /// Build a bare `Exercise`.
    static func exercise(
        name: String = "Bench Press",
        primaryMuscles: [MuscleGroup] = [.chest]
    ) -> Exercise {
        Exercise(canonicalName: name, primaryMuscles: primaryMuscles)
    }
}
