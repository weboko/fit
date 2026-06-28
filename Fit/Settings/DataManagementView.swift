import SwiftUI
import SwiftData
import UniformTypeIdentifiers

/// Data management screen (spec §23): shows how much is stored, lets the user
/// (re)seed the starter exercises, restore from a prior JSON export, and offers a
/// clearly destructive "delete all data" action behind a confirmation alert.
struct DataManagementView: View {
    @Environment(\.modelContext) private var context

    /// Live object counts per model type, refreshed on appear and after actions.
    @State private var counts = ModelCounts()
    @State private var showDeleteConfirmation = false
    @State private var statusMessage: String?
    @State private var isWorking = false

    // Import (F11) state.
    @State private var showImporter = false
    @State private var showImportConfirmation = false
    @State private var pendingImportURL: URL?
    @State private var importSummary: ImportSummary?
    @State private var importErrorMessage: String?

    var body: some View {
        Form {
            countsSection
            seedSection
            importSection
            dangerSection
            if let statusMessage {
                Section {
                    Text(statusMessage)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("Data management")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear(perform: refreshCounts)
        .fileImporter(isPresented: $showImporter, allowedContentTypes: [.json]) { result in
            handlePickedFile(result)
        }
        .alert("Restore from this file?", isPresented: $showImportConfirmation) {
            Button("Import", action: runImport)
            Button("Cancel", role: .cancel) { pendingImportURL = nil }
        } message: {
            Text("This merges the file into your data by matching on id: existing records are updated and new ones are added. Nothing is deleted. Your current data stays unless the file contains a record with the same id.")
        }
        .alert("Import complete", isPresented: importSummaryBinding) {
            Button("OK", role: .cancel) { importSummary = nil }
        } message: {
            Text(importSummaryText)
        }
        .alert("Import failed", isPresented: importErrorBinding) {
            Button("OK", role: .cancel) { importErrorMessage = nil }
        } message: {
            Text(importErrorMessage ?? "Something went wrong.")
        }
        .alert("Delete all data?", isPresented: $showDeleteConfirmation) {
            Button("Delete everything", role: .destructive, action: deleteAllData)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This permanently removes every workout, set, exercise, journal entry and imported Health record from this device (and from iCloud if syncing). This cannot be undone. Export first if you want a copy.")
        }
    }

    // MARK: - Stored counts

    private var countsSection: some View {
        Section {
            DetailRow(label: "Workouts", value: "\(counts.workoutSessions)")
            DetailRow(label: "Sets", value: "\(counts.workoutSets)")
            DetailRow(label: "Exercises", value: "\(counts.exercises)")
            DetailRow(label: "Exercise aliases", value: "\(counts.exerciseAliases)")
            DetailRow(label: "Health workouts", value: "\(counts.healthWorkouts)")
            DetailRow(label: "Body weight entries", value: "\(counts.bodyWeightEntries)")
            DetailRow(label: "Sleep entries", value: "\(counts.sleepEntries)")
            DetailRow(label: "Journal entries", value: "\(counts.journalEntries)")
        } header: {
            Text("Stored on this device")
        } footer: {
            Text("Total objects: \(counts.total)")
        }
    }

    // MARK: - Seed

    private var seedSection: some View {
        Section {
            Button {
                addStarterExercises()
            } label: {
                Label("Add starter exercises", systemImage: "plus.circle")
            }
            .disabled(isWorking)
        } header: {
            Text("Starter library")
        } footer: {
            Text("Adds the curated starter exercises. Anything you don't want can be archived or deleted afterwards. This may create duplicates if you've already seeded — use Merge in the Exercise library to tidy up.")
        }
    }

    // MARK: - Import (restore from JSON export)

    private var importSection: some View {
        Section {
            Button {
                showImporter = true
            } label: {
                Label("Import data…", systemImage: "square.and.arrow.down")
            }
            .disabled(isWorking)
        } header: {
            Text("Restore")
        } footer: {
            Text("Restores a previously exported JSON file (fit_export.json). It merges by id — existing records are updated, new ones added, and nothing is ever deleted. Everything stays on this device.")
        }
    }

    // MARK: - Danger zone

    private var dangerSection: some View {
        Section {
            Button(role: .destructive) {
                showDeleteConfirmation = true
            } label: {
                Label("Delete all data", systemImage: "trash")
            }
            .disabled(isWorking || counts.total == 0)
        } header: {
            Text("Danger zone")
        } footer: {
            Text("Removes everything. Consider exporting from the Export tab first.")
        }
    }

    // MARK: - Actions

    private func refreshCounts() {
        counts = ModelCounts(context: context)
    }

    private func addStarterExercises() {
        isWorking = true
        defer { isWorking = false }
        SeedData.addStarterExercises(to: context)
        do {
            try context.save()
            refreshCounts()
            statusMessage = "Starter exercises added."
        } catch {
            statusMessage = "Couldn't add starter exercises: \(error.localizedDescription)"
        }
    }

    // MARK: - Import actions

    /// Bindings that present the result / error alerts off the optional state.
    private var importSummaryBinding: Binding<Bool> {
        Binding(get: { importSummary != nil }, set: { if !$0 { importSummary = nil } })
    }

    private var importErrorBinding: Binding<Bool> {
        Binding(get: { importErrorMessage != nil }, set: { if !$0 { importErrorMessage = nil } })
    }

    /// Human-readable summary of the last import for the result alert.
    private var importSummaryText: String {
        guard let s = importSummary else { return "" }
        var lines = [
            "Added \(s.insertedTotal), updated \(s.updatedTotal).",
            "Workouts: +\(s.insertedWorkouts) / \(s.updatedWorkouts) updated",
            "Sets: +\(s.insertedSets) / \(s.updatedSets) updated",
            "Exercises: +\(s.insertedExercises) / \(s.updatedExercises) updated",
            "Journal: +\(s.insertedJournalEntries) / \(s.updatedJournalEntries) updated"
        ]
        if !s.warnings.isEmpty {
            let shown = s.warnings.prefix(5).joined(separator: "\n• ")
            lines.append("\nWarnings (\(s.warnings.count)):\n• \(shown)")
        }
        return lines.joined(separator: "\n")
    }

    /// Capture the picked URL and ask for confirmation before touching any data.
    private func handlePickedFile(_ result: Result<URL, Error>) {
        switch result {
        case .success(let url):
            pendingImportURL = url
            showImportConfirmation = true
        case .failure(let error):
            importErrorMessage = error.localizedDescription
        }
    }

    /// Read the confirmed file and run the merge. Runs on the main context for
    /// simplicity; the engine only inserts/updates and never deletes.
    private func runImport() {
        guard let url = pendingImportURL else { return }
        pendingImportURL = nil
        isWorking = true
        defer { isWorking = false }

        // The file lives outside the app sandbox (Files / iCloud), so we must hold
        // a security-scoped resource for the duration of the read.
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }

        do {
            let data = try Data(contentsOf: url)
            let summary = try DataImportService().importJSON(data, into: context)
            importSummary = summary
            refreshCounts()
        } catch {
            importErrorMessage = error.localizedDescription
        }
    }

    private func deleteAllData() {
        isWorking = true
        defer { isWorking = false }
        do {
            // SwiftData batch deletes per model type. Order is not significant
            // for deletion; relationships are torn down by the store.
            try context.delete(model: WorkoutSet.self)
            try context.delete(model: WorkoutSession.self)
            try context.delete(model: ExerciseAlias.self)
            try context.delete(model: Exercise.self)
            try context.delete(model: HealthWorkout.self)
            try context.delete(model: BodyWeightEntry.self)
            try context.delete(model: SleepEntry.self)
            try context.delete(model: JournalEntry.self)
            try context.save()
            refreshCounts()
            statusMessage = "All data deleted."
        } catch {
            statusMessage = "Delete failed: \(error.localizedDescription)"
            refreshCounts()
        }
    }
}

/// A snapshot of how many objects of each model type are stored. Computed with
/// `fetchCount` so it's cheap and doesn't materialise the objects themselves.
private struct ModelCounts {
    var workoutSessions = 0
    var workoutSets = 0
    var exercises = 0
    var exerciseAliases = 0
    var healthWorkouts = 0
    var bodyWeightEntries = 0
    var sleepEntries = 0
    var journalEntries = 0

    var total: Int {
        workoutSessions + workoutSets + exercises + exerciseAliases
            + healthWorkouts + bodyWeightEntries + sleepEntries + journalEntries
    }

    init() {}

    init(context: ModelContext) {
        workoutSessions = Self.count(WorkoutSession.self, context)
        workoutSets = Self.count(WorkoutSet.self, context)
        exercises = Self.count(Exercise.self, context)
        exerciseAliases = Self.count(ExerciseAlias.self, context)
        healthWorkouts = Self.count(HealthWorkout.self, context)
        bodyWeightEntries = Self.count(BodyWeightEntry.self, context)
        sleepEntries = Self.count(SleepEntry.self, context)
        journalEntries = Self.count(JournalEntry.self, context)
    }

    private static func count<T: PersistentModel>(_ type: T.Type, _ context: ModelContext) -> Int {
        (try? context.fetchCount(FetchDescriptor<T>())) ?? 0
    }
}

#Preview {
    NavigationStack {
        DataManagementView()
    }
    .modelContainer(PersistenceController.makePreviewContainer())
}
