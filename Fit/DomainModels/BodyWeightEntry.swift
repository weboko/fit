import Foundation
import SwiftData

/// A bodyweight measurement, either entered manually or imported from Health.
@Model
final class BodyWeightEntry {
    var id: UUID = UUID()
    var timestamp: Date = Date()
    var weightKg: Double = 0
    var sourceRaw: String = DataSource.manual.rawValue
    /// HealthKit sample UUID when imported, to de-duplicate imports.
    var appleHealthSampleId: String?
    var notes: String = ""

    init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        weightKg: Double = 0,
        source: DataSource = .manual,
        appleHealthSampleId: String? = nil
    ) {
        self.id = id
        self.timestamp = timestamp
        self.weightKg = weightKg
        self.sourceRaw = source.rawValue
        self.appleHealthSampleId = appleHealthSampleId
    }
}

extension BodyWeightEntry {
    var source: DataSource {
        get { DataSource(rawValue: sourceRaw) ?? .unknown }
        set { sourceRaw = newValue.rawValue }
    }
}
