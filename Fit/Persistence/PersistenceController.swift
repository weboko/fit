import Foundation
import SwiftData

/// Central place that builds the SwiftData `ModelContainer`.
///
/// Storage model (spec §4): local-first with iCloud/CloudKit sync. We try to
/// build a CloudKit-backed container first; if that fails (no iCloud account,
/// no entitlement in a dev build, simulator without iCloud, etc.) we fall back
/// to a purely local store so the app is always usable offline.
enum PersistenceController {

    /// The full schema. Every `@Model` type must be listed here.
    static let schema = Schema([
        WorkoutSession.self,
        WorkoutSet.self,
        Exercise.self,
        ExerciseAlias.self,
        HealthWorkout.self,
        BodyWeightEntry.self,
        SleepEntry.self,
        JournalEntry.self,
    ])

    /// Builds the shared container used by the app.
    static func makeSharedContainer() -> ModelContainer {
        // 1. Preferred: local + CloudKit mirroring.
        if let container = try? makeContainer(cloudKit: true) {
            return container
        }
        // 2. Fallback: local-only. If even this fails the app cannot run, so we
        //    surface the error loudly rather than silently losing data.
        do {
            return try makeContainer(cloudKit: false)
        } catch {
            fatalError("Failed to create local ModelContainer: \(error)")
        }
    }

    /// Builds an in-memory container for previews and tests.
    static func makePreviewContainer(seeded: Bool = true) -> ModelContainer {
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: schema, configurations: [config])
        if seeded {
            SeedData.seedIfNeeded(in: container.mainContext)
            PreviewData.populate(container.mainContext)
        }
        return container
    }

    private static func makeContainer(cloudKit: Bool) throws -> ModelContainer {
        let config: ModelConfiguration
        if cloudKit {
            config = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: false,
                cloudKitDatabase: .automatic
            )
        } else {
            config = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: false,
                cloudKitDatabase: .none
            )
        }
        return try ModelContainer(for: schema, configurations: [config])
    }
}
