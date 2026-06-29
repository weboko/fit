import Foundation
import SwiftData

/// A resolved, in-memory snapshot of everything an export needs, already filtered
/// per the request. Built once by `DataExportService` and shared by the CSV and
/// JSON exporters so the model graph is only walked a single time.
struct ExportDataSet {
    let generatedAt: Date
    var workouts: [WorkoutSession]
    var sets: [WorkoutSet]
    var exercises: [Exercise]
    var exerciseAliases: [ExerciseAlias]
    var healthWorkouts: [HealthWorkout]
    var bodyWeightEntries: [BodyWeightEntry]
    var sleepEntries: [SleepEntry]
    var journalEntries: [JournalEntry]
}

/// The export engine. Fetches the requested entities from a `ModelContext`,
/// writes the chosen format into a unique temporary directory and returns the
/// produced file URLs. No SwiftUI; safe to call off the main actor as long as the
/// passed `ModelContext` is used from the appropriate actor by the caller.
final class DataExportService {

    init() {}

    // MARK: - Entry point

    func export(_ request: ExportRequest, context: ModelContext) throws -> ExportResult {
        let generatedAt = Date()
        var warnings: [String] = []

        let data = try buildDataSet(request: request, context: context, generatedAt: generatedAt)

        // Surface gentle warnings about empty optional sections.
        if data.workouts.isEmpty && data.sets.isEmpty {
            warnings.append("No workouts matched the selected filters.")
        }
        if request.includeBodyWeight && data.bodyWeightEntries.isEmpty {
            warnings.append("No body-weight entries in range.")
        }
        if request.includeSleep && data.sleepEntries.isEmpty {
            warnings.append("No sleep entries in range.")
        }
        if request.includeHealthData && data.healthWorkouts.isEmpty {
            warnings.append("No linked Apple Health workouts in range.")
        }

        let directory = try makeTempDirectory()

        switch request.format {
        case .csv:
            let urls = try writeCSVBundle(data: data, request: request, into: directory)
            return ExportResult(fileURLs: urls, generatedAt: generatedAt, format: .csv, warnings: warnings)

        case .json:
            let url = try writeJSON(data: data, request: request, into: directory)
            return ExportResult(fileURLs: [url], generatedAt: generatedAt, format: .json, warnings: warnings)

        case .zip:
            let url = try writeZip(data: data, request: request, into: directory)
            return ExportResult(fileURLs: [url], generatedAt: generatedAt, format: .zip, warnings: warnings)
        }
    }

    // MARK: - Fetching & filtering

    private func buildDataSet(request: ExportRequest, context: ModelContext, generatedAt: Date) throws -> ExportDataSet {
        // Fetch everything, then filter in memory. Filtering in memory keeps the
        // predicate logic readable and avoids #Predicate limitations around
        // optional relationships and Set-membership.
        let allWorkouts = (try? context.fetch(FetchDescriptor<WorkoutSession>(
            sortBy: [SortDescriptor(\.startTime, order: .forward)]
        ))) ?? []
        let allSets = (try? context.fetch(FetchDescriptor<WorkoutSet>())) ?? []
        let allExercises = (try? context.fetch(FetchDescriptor<Exercise>(
            sortBy: [SortDescriptor(\.canonicalName, order: .forward)]
        ))) ?? []
        let allAliases = (try? context.fetch(FetchDescriptor<ExerciseAlias>())) ?? []
        let allHealth = (try? context.fetch(FetchDescriptor<HealthWorkout>())) ?? []
        let allBodyWeight = (try? context.fetch(FetchDescriptor<BodyWeightEntry>(
            sortBy: [SortDescriptor(\.timestamp, order: .forward)]
        ))) ?? []
        let allSleep = (try? context.fetch(FetchDescriptor<SleepEntry>(
            sortBy: [SortDescriptor(\.date, order: .forward)]
        ))) ?? []
        let allJournal = (try? context.fetch(FetchDescriptor<JournalEntry>(
            sortBy: [SortDescriptor(\.timestamp, order: .forward)]
        ))) ?? []

        let selectedWorkoutSet = request.selectedWorkoutIDs.map(Set.init)
        let selectedExerciseSet = request.selectedExerciseIDs.map(Set.init)

        // Workouts: filter by date range + explicit selection.
        let workouts = allWorkouts.filter { w in
            inDateRange(w.startTime, request: request)
                && (selectedWorkoutSet?.contains(w.id) ?? true)
        }
        let workoutIDs = Set(workouts.map(\.id))

        // Sets: must belong to an included workout, and (if exercise selection is
        // active) reference a selected exercise.
        let sets = allSets.filter { s in
            guard let wid = s.workout?.id, workoutIDs.contains(wid) else { return false }
            if let selectedExerciseSet {
                guard let eid = s.exercise?.id, selectedExerciseSet.contains(eid) else { return false }
            }
            return true
        }

        // Exercises: when an explicit exercise selection exists, honour it.
        // Otherwise export the full library (it is the user's own dictionary and
        // is cheap; historical names are still preserved per-set regardless).
        let exercises: [Exercise]
        if let selectedExerciseSet {
            exercises = allExercises.filter { selectedExerciseSet.contains($0.id) }
        } else {
            exercises = allExercises
        }
        let exerciseIDs = Set(exercises.map(\.id))

        let aliases = allAliases.filter { a in
            guard let eid = a.exercise?.id else { return false }
            return exerciseIDs.contains(eid)
        }

        // Health workouts: included ones linked to an exported session, or in the
        // date range when not session-restricted.
        let healthWorkouts: [HealthWorkout]
        if request.includeHealthData {
            healthWorkouts = allHealth.filter { h in
                if let linkedID = h.linkedSession?.id {
                    return workoutIDs.contains(linkedID)
                }
                // Unlinked health workout: include only when there's no explicit
                // workout selection and it falls in range.
                guard selectedWorkoutSet == nil else { return false }
                return inDateRange(h.startTime, request: request)
            }
        } else {
            healthWorkouts = []
        }

        let bodyWeight: [BodyWeightEntry]
        if request.includeBodyWeight {
            bodyWeight = allBodyWeight.filter { inDateRange($0.timestamp, request: request) }
        } else {
            bodyWeight = []
        }

        let sleep: [SleepEntry]
        if request.includeSleep {
            sleep = allSleep.filter { inDateRange($0.date, request: request) }
        } else {
            sleep = []
        }

        let journal: [JournalEntry]
        if request.includeJournal {
            journal = allJournal.filter { j in
                if let wid = j.workout?.id { return workoutIDs.contains(wid) }
                // Standalone journal entries (no workout): include when there is
                // no explicit workout selection and they fall in range.
                guard selectedWorkoutSet == nil else { return false }
                return inDateRange(j.timestamp, request: request)
            }
        } else {
            journal = []
        }

        return ExportDataSet(
            generatedAt: generatedAt,
            workouts: workouts,
            sets: sets,
            exercises: exercises,
            exerciseAliases: aliases,
            healthWorkouts: healthWorkouts,
            bodyWeightEntries: bodyWeight,
            sleepEntries: sleep,
            journalEntries: journal
        )
    }

    /// Inclusive date-range test. Open bounds when start/end are nil.
    private func inDateRange(_ date: Date, request: ExportRequest) -> Bool {
        if let start = request.dateRangeStart, date < start { return false }
        if let end = request.dateRangeEnd, date > end { return false }
        return true
    }

    // MARK: - Writing

    private func makeTempDirectory() throws -> URL {
        let base = FileManager.default.temporaryDirectory
        let stamp = Self.folderDateFormatter.string(from: Date())
        let name = "FitExport-\(stamp)-\(UUID().uuidString.prefix(8))"
        let dir = base.appendingPathComponent(name, isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        } catch {
            throw ExportError.fileWriteFailed(error.localizedDescription)
        }
        return dir
    }

    /// Writes all CSV files + the manifest into `directory`. Returns their URLs.
    @discardableResult
    private func writeCSVBundle(data: ExportDataSet, request: ExportRequest, into directory: URL) throws -> [URL] {
        var urls: [URL] = []
        let files = CSVExporter.allFiles(for: data, request: request)
        for file in files {
            let url = directory.appendingPathComponent(file.name)
            try write(string: file.contents, to: url)
            urls.append(url)
        }

        // Data dictionary: documents every CSV column, enum and derived formula so
        // the bundle is self-describing for an external analyst/AI.
        let dictURL = directory.appendingPathComponent(ExportFileName.dataDictionary)
        try write(string: ExportSchema.markdown(), to: dictURL)
        urls.append(dictURL)

        let manifestURL = directory.appendingPathComponent(ExportFileName.manifest)
        var includedNames = files.map(\.name)
        includedNames.append(ExportFileName.dataDictionary)
        try writeManifest(into: manifestURL, request: request, data: data, includedFiles: includedNames)
        urls.append(manifestURL)
        return urls
    }

    /// Writes the single JSON document. Returns its URL.
    private func writeJSON(data: ExportDataSet, request: ExportRequest, into directory: URL) throws -> URL {
        let url = directory.appendingPathComponent(ExportFileName.json)
        let jsonData = try JSONExporter.encode(data, request: request)
        do {
            try jsonData.write(to: url, options: .atomic)
        } catch {
            throw ExportError.fileWriteFailed(error.localizedDescription)
        }
        return url
    }

    /// Builds the CSV bundle + manifest + JSON in a staging dir, then zips them.
    private func writeZip(data: ExportDataSet, request: ExportRequest, into directory: URL) throws -> URL {
        // Stage all contents inside a subdirectory so the zip has a clean root.
        let staging = directory.appendingPathComponent("fit_export", isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: staging, withIntermediateDirectories: true)
        } catch {
            throw ExportError.fileWriteFailed(error.localizedDescription)
        }

        // CSV files.
        let csvFiles = CSVExporter.allFiles(for: data, request: request)
        for file in csvFiles {
            try write(string: file.contents, to: staging.appendingPathComponent(file.name))
        }

        // Data dictionary: self-describing schema for the bundle (after the CSVs).
        try write(string: ExportSchema.markdown(), to: staging.appendingPathComponent(ExportFileName.dataDictionary))

        // JSON document.
        let jsonData = try JSONExporter.encode(data, request: request)
        do {
            try jsonData.write(to: staging.appendingPathComponent(ExportFileName.json), options: .atomic)
        } catch {
            throw ExportError.fileWriteFailed(error.localizedDescription)
        }

        // Manifest (lists the CSVs + the data dictionary + the JSON file).
        var includedNames = csvFiles.map(\.name)
        includedNames.append(ExportFileName.dataDictionary)
        includedNames.append(ExportFileName.json)
        try writeManifest(
            into: staging.appendingPathComponent(ExportFileName.manifest),
            request: request,
            data: data,
            includedFiles: includedNames
        )

        let destination = directory.appendingPathComponent("\(zipBaseName(for: request)).zip")
        return try ZipPackager.zip(directory: staging, to: destination)
    }

    private func zipBaseName(for request: ExportRequest) -> String {
        if let ids = request.selectedWorkoutIDs, ids.count == 1 {
            return "fit_workout_export"
        }
        return "fit_export"
    }

    private func write(string: String, to url: URL) throws {
        do {
            try string.data(using: .utf8)?.write(to: url, options: .atomic)
        } catch {
            throw ExportError.fileWriteFailed(error.localizedDescription)
        }
    }

    // MARK: - Manifest

    private func writeManifest(into url: URL, request: ExportRequest, data: ExportDataSet, includedFiles: [String]) throws {
        let manifest = ExportManifest(
            export_version: AppInfo.exportVersion,
            app_version: "\(AppInfo.version)+\(AppInfo.build)",
            exported_at: ExportFormatting.iso(data.generatedAt),
            date_range_start: request.dateRangeStart.map { ExportFormatting.iso($0) },
            date_range_end: request.dateRangeEnd.map { ExportFormatting.iso($0) },
            included_files: includedFiles,
            schema_version: AppInfo.exportSchemaVersion,
            units: JSONExporter.Units(weight: ExportFormatting.weightUnit),
            timezone: TimeZone.current.identifier,
            notes: "Generated by Fit. Weights are in kilograms. Timestamps are ISO-8601 with timezone."
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        do {
            let manifestData = try encoder.encode(manifest)
            try manifestData.write(to: url, options: .atomic)
        } catch {
            throw ExportError.fileWriteFailed(error.localizedDescription)
        }
    }

    private static let folderDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyyMMdd-HHmmss"
        return f
    }()
}

/// The `export_manifest.json` payload (spec §12.13).
private struct ExportManifest: Codable {
    let export_version: String
    let app_version: String
    let exported_at: String
    let date_range_start: String?
    let date_range_end: String?
    let included_files: [String]
    let schema_version: String
    let units: JSONExporter.Units
    let timezone: String
    let notes: String
}
