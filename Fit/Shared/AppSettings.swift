import Foundation

/// UserDefaults keys shared across modules. Keeping them in one place avoids
/// typos between the Settings UI, formatting helpers and export metadata.
enum AppSettingsKeys {
    static let weightUnit = "fit.settings.weightUnit"
    static let lastBodyWeightKg = "fit.settings.lastBodyWeightKg"
    static let defaultExportIncludesHealth = "fit.settings.export.includeHealth"
    static let defaultExportIncludesJournal = "fit.settings.export.includeJournal"
    static let defaultRestSeconds = "fit.settings.defaultRestSeconds"
}

/// App-level metadata used in exports and the Settings screen.
enum AppInfo {
    static var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
    }
    static var build: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
    }
    /// Schema version of the exported data format. Bump when export columns change.
    static let exportSchemaVersion = "1.0"
    static let exportVersion = "1.0"
}
