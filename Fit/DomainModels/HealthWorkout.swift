import Foundation
import SwiftData

/// A workout imported from Apple Health / Apple Watch. Stored separately from
/// the manual `WorkoutSession` and optionally linked to one (spec §11).
@Model
final class HealthWorkout {
    var id: UUID = UUID()

    /// The HealthKit object UUID, used to avoid importing duplicates.
    var appleHealthUUID: String = ""

    var workoutType: String = ""
    var startTime: Date = Date()
    var endTime: Date = Date()
    var durationSeconds: Double = 0

    var activeEnergyKcal: Double?
    var totalEnergyKcal: Double?

    var avgHeartRateBpm: Double?
    var minHeartRateBpm: Double?
    var maxHeartRateBpm: Double?
    var heartRateSampleCount: Int?

    var sourceName: String?
    var sourceDevice: String?

    var importedAt: Date = Date()

    /// Inverse of `WorkoutSession.linkedHealthWorkout`.
    var linkedSession: WorkoutSession?

    init(
        id: UUID = UUID(),
        appleHealthUUID: String = "",
        workoutType: String = "",
        startTime: Date = Date(),
        endTime: Date = Date(),
        durationSeconds: Double = 0
    ) {
        self.id = id
        self.appleHealthUUID = appleHealthUUID
        self.workoutType = workoutType
        self.startTime = startTime
        self.endTime = endTime
        self.durationSeconds = durationSeconds
        self.importedAt = Date()
    }
}

extension HealthWorkout {
    var isLinked: Bool { linkedSession != nil }

    /// Whether this health workout's time window overlaps the given session.
    func overlaps(session: WorkoutSession) -> Bool {
        let sessionEnd = session.endTime ?? session.startTime.addingTimeInterval(2 * 60 * 60)
        return startTime < sessionEnd && endTime > session.startTime
    }
}
