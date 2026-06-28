import SwiftUI
import SwiftData

/// Log a workout that happened in the past.
///
/// The user picks a past date/time, adds exercises (shared `ExercisePickerView`)
/// and, under each, a few sets via a small local set-entry subview. Effort / form
/// / pain are optional for backfill. On save the session is marked
/// `isBackfilled = true` and every created set gets `source = .backfilled`.
struct BackfillWorkoutView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var startTime: Date = Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date()
    @State private var hasEnd = true
    @State private var endTime: Date = Calendar.current.date(byAdding: .day, value: -1, to: Date())?
        .addingTimeInterval(60 * 60) ?? Date()
    @State private var approximateNote = ""

    /// In-memory draft of the workout before it is committed to SwiftData.
    @State private var draftExercises: [DraftExercise] = []

    @State private var showingPicker = false

    var body: some View {
        NavigationStack {
            Form {
                Section("When") {
                    TextField("Title (optional)", text: $title)
                    DatePicker("Start", selection: $startTime)
                    Toggle("Has end time", isOn: $hasEnd)
                    if hasEnd {
                        DatePicker("End", selection: $endTime, in: startTime...)
                    }
                }

                ForEach($draftExercises) { $draft in
                    Section(draft.name) {
                        ForEach($draft.sets) { $draftSet in
                            DraftSetEntry(set: $draftSet, defaultMode: draft.defaultMode)
                        }
                        .onDelete { offsets in
                            draft.sets.remove(atOffsets: offsets)
                        }
                        Button {
                            addSet(to: $draft)
                        } label: {
                            Label("Add set", systemImage: "plus.circle")
                        }
                    }
                }

                Section {
                    Button {
                        showingPicker = true
                    } label: {
                        Label("Add exercise", systemImage: "plus.circle.fill")
                    }
                }

                Section("Approximate?") {
                    TextField("e.g. \"weights approximate\"", text: $approximateNote, axis: .vertical)
                        .lineLimit(1...3)
                } footer: {
                    Text("Backfilled workouts are tagged so you can tell them from live logs.")
                }
            }
            .navigationTitle("Backfill workout")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") { save() }
                        .disabled(!canSave)
                }
            }
            .onChange(of: startTime) { _, newStart in
                if endTime < newStart { endTime = newStart }
            }
            .sheet(isPresented: $showingPicker) {
                ExercisePickerView { exercise in
                    addExercise(exercise)
                }
            }
        }
    }

    private var canSave: Bool {
        draftExercises.contains { !$0.sets.isEmpty }
    }

    // MARK: Draft mutation

    private func addExercise(_ exercise: Exercise) {
        var draft = DraftExercise(
            exerciseId: exercise.id,
            name: exercise.canonicalName,
            defaultMode: exercise.defaultWeightMode
        )
        draft.sets.append(DraftSet(mode: exercise.defaultWeightMode))
        draftExercises.append(draft)
    }

    private func addSet(to draft: Binding<DraftExercise>) {
        // Pre-fill from the previous set in this exercise for speed.
        let previous = draft.wrappedValue.sets.last
        var newSet = DraftSet(mode: previous?.mode ?? draft.wrappedValue.defaultMode)
        newSet.weightKg = previous?.weightKg
        newSet.reps = previous?.reps
        newSet.bodyWeightKg = previous?.bodyWeightKg
        newSet.assistanceKg = previous?.assistanceKg
        newSet.addedWeightKg = previous?.addedWeightKg
        draft.wrappedValue.sets.append(newSet)
    }

    // MARK: Save

    private func save() {
        let session = WorkoutSession(
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            startTime: startTime,
            endTime: hasEnd ? max(endTime, startTime) : nil,
            isBackfilled: true
        )
        context.insert(session)

        // Resolve exercises once by id.
        let allExercises = (try? context.fetch(FetchDescriptor<Exercise>())) ?? []
        let byId = Dictionary(uniqueKeysWithValues: allExercises.map { ($0.id, $0) })

        var index = 0
        for draft in draftExercises {
            let exercise = byId[draft.exerciseId]
            for draftSet in draft.sets {
                let set = WorkoutSet(
                    exercise: exercise,
                    exerciseNameAtTime: exercise?.canonicalName ?? draft.name,
                    setIndex: index,
                    timestamp: startTime.addingTimeInterval(Double(index) * 60),
                    weightMode: draftSet.mode,
                    source: .backfilled
                )
                set.weightKg = draftSet.weightKg
                set.bodyWeightKg = draftSet.bodyWeightKg
                set.assistanceKg = draftSet.assistanceKg
                set.addedWeightKg = draftSet.addedWeightKg
                set.reps = draftSet.reps
                set.workout = session
                context.insert(set)
                index += 1
            }
        }

        let note = approximateNote.trimmingCharacters(in: .whitespacesAndNewlines)
        if !note.isEmpty {
            let journal = JournalEntry(
                workout: session,
                timestamp: startTime,
                entryType: .workoutNote,
                text: note
            )
            context.insert(journal)
        }

        try? context.save()
        dismiss()
    }
}

// MARK: - In-memory draft models

/// One exercise being backfilled, holding its draft sets.
private struct DraftExercise: Identifiable {
    let id = UUID()
    let exerciseId: UUID
    let name: String
    let defaultMode: WeightMode
    var sets: [DraftSet] = []
}

/// One draft set; load fields kept generic so any weight mode can be expressed.
private struct DraftSet: Identifiable {
    let id = UUID()
    var mode: WeightMode
    var weightKg: Double?
    var bodyWeightKg: Double?
    var assistanceKg: Double?
    var addedWeightKg: Double?
    var reps: Int?
}

// MARK: - Local set entry subview (own, not WorkoutLogging's)

/// A compact set-entry row for backfill. Mode chips + the relevant load field(s)
/// + reps. Effort/form/pain are intentionally skipped for fast backfill.
private struct DraftSetEntry: View {
    @Binding var set: DraftSet
    let defaultMode: WeightMode

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            OptionChipGroupRequired<WeightMode>("Mode", selection: $set.mode)

            switch set.mode {
            case .external, .unknown:
                labeled("Weight") { WeightStepperField(weightKg: $set.weightKg) }
            case .bodyweight:
                labeled("Bodyweight") { WeightStepperField(weightKg: $set.bodyWeightKg) }
            case .assistedBodyweight:
                labeled("Bodyweight") { WeightStepperField(weightKg: $set.bodyWeightKg) }
                labeled("Assistance") { WeightStepperField(weightKg: $set.assistanceKg) }
            case .addedBodyweight:
                labeled("Bodyweight") { WeightStepperField(weightKg: $set.bodyWeightKg) }
                labeled("Added weight") { WeightStepperField(weightKg: $set.addedWeightKg) }
            }

            labeled("Reps") { RepsStepperField(reps: $set.reps) }
        }
        .padding(.vertical, Theme.Spacing.xs)
    }

    private func labeled<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
            content()
        }
    }
}

#Preview {
    BackfillWorkoutView()
        .modelContainer(PersistenceController.makePreviewContainer())
}
