import Foundation

/// UserDefaults keys shared across modules. Keeping them in one place avoids
/// typos between the Settings UI, formatting helpers and export metadata.
enum AppSettingsKeys {
    static let weightUnit = "fit.settings.weightUnit"
    static let lastBodyWeightKg = "fit.settings.lastBodyWeightKg"
    static let defaultExportIncludesHealth = "fit.settings.export.includeHealth"
    static let defaultExportIncludesJournal = "fit.settings.export.includeJournal"
    static let defaultRestSeconds = "fit.settings.defaultRestSeconds"
    static let restAlertsEnabled = "fit.settings.restAlertsEnabled"
    /// Per-exercise rest override (F20): keyed by `exercise.id.uuidString`
    /// appended to this prefix. Stored in seconds; an absent/0 value means the
    /// exercise uses the global default rest length.
    static let exerciseRestPrefix = "fit.rest.exercise."
    /// Plate calculator (F8): default bar weight in kg, and the comma-joined
    /// list of enabled per-side plate sizes in kg.
    static let barWeightKg = "fit.settings.barWeightKg"
    static let enabledPlatesCSV = "fit.settings.enabledPlatesCSV"
    /// Repeat last workout (F9): the id of the single auto-managed "quick start"
    /// template so we refresh that one template instead of creating clutter.
    static let quickStartTemplateId = "fit.quickStart.templateId"
    /// First-run onboarding (F15): set to `true` once the user has completed or
    /// skipped the onboarding flow so it is only ever shown on first launch.
    static let hasOnboarded = "fit.settings.hasOnboarded"
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
