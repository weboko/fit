import Foundation

/// The tiny, self-contained data contract shared between the Fit app and this
/// WidgetKit extension. The app and the widget are separate modules (there is no
/// shared framework), so this Codable shape is intentionally **duplicated** in
/// `Fit/Shared/WidgetSnapshotWriter.swift`. Keep the two in sync: same property
/// names + JSON keys.
///
/// The widget never touches SwiftData/CloudKit — it reads only this snapshot
/// from a shared App Group `UserDefaults`.
struct WidgetSnapshot: Codable {
    /// Title (or date-derived title) of the most recently finished workout.
    var lastWorkoutTitle: String?
    /// When that workout started.
    var lastWorkoutDate: Date?
    /// Consecutive ISO weeks (counting back from the current week) that each
    /// contain at least one finished workout.
    var weeklyStreak: Int
    /// A compact "best set" line for the last workout, e.g. "Bench Press 80 kg × 6".
    var topSetSummary: String?
}

/// Reads the shared snapshot written by the app. Self-contained: `Foundation`
/// only, no app-module dependency.
enum SharedStore {
    /// App Group identifier (must match the app target's entitlement + writer).
    static let suiteName = "group.com.weboko.fit"
    /// The single key under which the JSON-encoded `WidgetSnapshot` is stored.
    static let snapshotKey = "widgetSnapshot.v1"

    /// Loads + decodes the latest snapshot, or `nil` if none has been written
    /// yet (or the App Group is unavailable / the payload is corrupt).
    static func load() -> WidgetSnapshot? {
        guard let defaults = UserDefaults(suiteName: suiteName),
              let data = defaults.data(forKey: snapshotKey) else { return nil }
        return try? JSONDecoder.snapshot.decode(WidgetSnapshot.self, from: data)
    }
}

extension JSONDecoder {
    /// Decoder matching the app-side encoder (ISO-8601 dates).
    static var snapshot: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
