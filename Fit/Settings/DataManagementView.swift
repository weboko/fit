import SwiftUI
import SwiftData

/// Data management screen (spec §23): shows how much is stored, lets the user
/// (re)seed the starter exercises, and offers a clearly destructive
/// "delete all data" action behind a confirmation alert.
struct DataManagementView: View {
    @Environment(\.modelContext) private var context

    /// Live object counts per model type, refreshed on appear and after actions.
    @State private var counts = ModelCounts()
    @State private var showDeleteConfirmation = false
    @State private var statusMessage: String?
    @State private var isWorking = false

    var body: some View {
        Form {
            countsSection
            seedSection
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
