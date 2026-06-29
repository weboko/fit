import Foundation

// MARK: - Export format

/// The supported export container formats. The engine is format-agnostic beyond
/// these three; adding a new format means adding a case here plus an exporter.
enum ExportFormat: String, CaseIterable, Identifiable, Sendable {
    /// One CSV file per entity type plus an `export_manifest.json`.
    case csv
    /// A single nested `.json` document.
    case json
    /// A single `.zip` bundling the CSV set, the manifest and the JSON document.
    case zip

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .csv: return "CSV (spreadsheet)"
        case .json: return "JSON (single file)"
        case .zip: return "ZIP (everything)"
        }
    }

    /// Short label for compact pickers.
    var shortLabel: String {
        switch self {
        case .csv: return "CSV"
        case .json: return "JSON"
        case .zip: return "ZIP"
        }
    }

    /// File extension produced for single-file formats (csv produces many files).
    var fileExtension: String {
        switch self {
        case .csv: return "csv"
        case .json: return "json"
        case .zip: return "zip"
        }
    }
}

// MARK: - Options

/// What to include in an export. Kept as a distinct value type so callers can
/// build options independently of the date range / format wrapper.
struct ExportOptions: Equatable, Sendable {
    /// Include linked Apple Health workouts + heart-rate summaries.
    var includeHealthData: Bool
    /// Include journal entries (workout/exercise/set notes).
    var includeJournal: Bool
    /// Include the body-weight log.
    var includeBodyWeight: Bool
    /// Include sleep entries.
    var includeSleep: Bool

    init(
        includeHealthData: Bool = true,
        includeJournal: Bool = true,
        includeBodyWeight: Bool = true,
        includeSleep: Bool = true
    ) {
        self.includeHealthData = includeHealthData
        self.includeJournal = includeJournal
        self.includeBodyWeight = includeBodyWeight
        self.includeSleep = includeSleep
    }

    /// Everything on — the default for a "full backup" style export.
    static let everything = ExportOptions()
}

// MARK: - Request

/// A complete description of a single export operation.
struct ExportRequest: Sendable {
    /// Inclusive lower bound on a workout's `startTime`. `nil` means no lower bound.
    var dateRangeStart: Date?
    /// Inclusive upper bound on a workout's `startTime`. `nil` means no upper bound.
    var dateRangeEnd: Date?

    var format: ExportFormat

    var includeHealthData: Bool
    var includeJournal: Bool
    var includeBodyWeight: Bool
    var includeSleep: Bool

    /// When non-nil, only these exercises (and their sets) are exported.
    var selectedExerciseIDs: [UUID]?
    /// When non-nil, only these workouts (and their sets/journal) are exported.
    var selectedWorkoutIDs: [UUID]?

    init(
        dateRangeStart: Date? = nil,
        dateRangeEnd: Date? = nil,
        format: ExportFormat = .zip,
        includeHealthData: Bool = true,
        includeJournal: Bool = true,
        includeBodyWeight: Bool = true,
        includeSleep: Bool = true,
        selectedExerciseIDs: [UUID]? = nil,
        selectedWorkoutIDs: [UUID]? = nil
    ) {
        self.dateRangeStart = dateRangeStart
        self.dateRangeEnd = dateRangeEnd
        self.format = format
        self.includeHealthData = includeHealthData
        self.includeJournal = includeJournal
        self.includeBodyWeight = includeBodyWeight
        self.includeSleep = includeSleep
        self.selectedExerciseIDs = selectedExerciseIDs
        self.selectedWorkoutIDs = selectedWorkoutIDs
    }

    /// Build a request from an `ExportOptions` value + range/format.
    init(
        dateRangeStart: Date?,
        dateRangeEnd: Date?,
        format: ExportFormat,
        options: ExportOptions,
        selectedExerciseIDs: [UUID]? = nil,
        selectedWorkoutIDs: [UUID]? = nil
    ) {
        self.init(
            dateRangeStart: dateRangeStart,
            dateRangeEnd: dateRangeEnd,
            format: format,
            includeHealthData: options.includeHealthData,
            includeJournal: options.includeJournal,
            includeBodyWeight: options.includeBodyWeight,
            includeSleep: options.includeSleep,
            selectedExerciseIDs: selectedExerciseIDs,
            selectedWorkoutIDs: selectedWorkoutIDs
        )
    }

    /// The include-flags as an `ExportOptions` value.
    var options: ExportOptions {
        ExportOptions(
            includeHealthData: includeHealthData,
            includeJournal: includeJournal,
            includeBodyWeight: includeBodyWeight,
            includeSleep: includeSleep
        )
    }

    /// A request that exports a single workout as a zip — used by `WorkoutShareButton`.
    static func singleWorkout(_ id: UUID, format: ExportFormat = .zip) -> ExportRequest {
        ExportRequest(format: format, selectedWorkoutIDs: [id])
    }
}

// MARK: - Result

/// The outcome of a successful export.
struct ExportResult: Sendable {
    /// The files produced (one for json/zip, several for csv). All live in a
    /// unique temporary directory and are safe to hand to the share sheet.
    let fileURLs: [URL]
    let generatedAt: Date
    let format: ExportFormat
    /// Non-fatal notes (e.g. "no body-weight entries in range").
    let warnings: [String]

    init(fileURLs: [URL], generatedAt: Date = Date(), format: ExportFormat, warnings: [String] = []) {
        self.fileURLs = fileURLs
        self.generatedAt = generatedAt
        self.format = format
        self.warnings = warnings
    }
}

// MARK: - Errors

/// Errors the export engine can throw.
enum ExportError: LocalizedError {
    case nothingToExport
    case fileWriteFailed(String)
    case zipFailed(String)

    var errorDescription: String? {
        switch self {
        case .nothingToExport:
            return "There is no data to export for the chosen filters."
        case .fileWriteFailed(let detail):
            return "Could not write the export files: \(detail)"
        case .zipFailed(let detail):
            return "Could not create the zip archive: \(detail)"
        }
    }
}

// MARK: - Shared export utilities

/// Internal helpers shared by the exporters. No SwiftUI.
enum ExportFormatting {
    /// ISO-8601 formatter including the timezone offset (`.withInternetDateTime`).
    /// Stored statically because `ISO8601DateFormatter` is relatively expensive
    /// to create.
    static let iso8601: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    /// ISO-8601 string for a non-optional date.
    static func iso(_ date: Date) -> String {
        iso8601.string(from: date)
    }

    /// ISO-8601 string for an optional date, empty string when nil.
    static func iso(_ date: Date?) -> String {
        guard let date else { return "" }
        return iso8601.string(from: date)
    }

    /// The canonical weight unit string used throughout exports (storage is kg).
    static let weightUnit = "kg"
}

/// The set of CSV filenames the engine emits, in a stable order.
enum ExportFileName {
    static let workouts = "workouts.csv"
    static let sets = "sets.csv"
    static let exercises = "exercises.csv"
    static let exerciseAliases = "exercise_aliases.csv"
    static let healthWorkouts = "health_workouts.csv"
    static let heartRateSummary = "heart_rate_summary.csv"
    static let bodyWeight = "body_weight.csv"
    static let sleep = "sleep.csv"
    static let journalEntries = "journal_entries.csv"
    static let manifest = "export_manifest.json"
    static let json = "fit_export.json"
    static let dataDictionary = "data_dictionary.md"
}
