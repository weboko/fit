import Foundation
import SwiftData

/// A sleep record. Either imported from Health (duration/times) or a manual
/// subjective quality note — third-party sleep apps are often more accurate
/// but not easily exportable, so both coexist (spec §11.4).
@Model
final class SleepEntry {
    var id: UUID = UUID()
    /// The night this sleep belongs to (local calendar day of waking).
    var date: Date = Date()
    var startTime: Date?
    var endTime: Date?
    var durationSeconds: Double?
    var sourceRaw: String = DataSource.manual.rawValue
    var subjectiveSleepQualityRaw: String?
    var appleHealthSampleId: String?
    var notes: String = ""

    init(
        id: UUID = UUID(),
        date: Date = Date(),
        source: DataSource = .manual
    ) {
        self.id = id
        self.date = date
        self.sourceRaw = source.rawValue
    }
}

extension SleepEntry {
    var source: DataSource {
        get { DataSource(rawValue: sourceRaw) ?? .unknown }
        set { sourceRaw = newValue.rawValue }
    }
    var subjectiveSleepQuality: SleepQuality? {
        get { subjectiveSleepQualityRaw.flatMap(SleepQuality.init(rawValue:)) }
        set { subjectiveSleepQualityRaw = newValue?.rawValue }
    }
}
