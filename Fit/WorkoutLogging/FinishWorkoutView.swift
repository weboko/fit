import SwiftUI
import SwiftData

/// The finish-workout screen (spec §6, §8, §11, §19). Shows a deterministic
/// summary (duration, exercise/set counts, top sets), lets the user fill in the
/// optional session questionnaire, add a workout-level note (stored as a
/// `JournalEntry`), and link an overlapping Apple Health workout via
/// `HealthLinkSection`. No AI analysis.
struct FinishWorkoutView: View {
    @Bindable var session: WorkoutSession

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var noteText = ""
    @State private var showQuestionnaire = false
    @State private var didFinish = false

    var body: some View {
        NavigationStack {
            Form {
                summarySection
                topSetsSection

                Section {
                    DisclosureGroup(isExpanded: $showQuestionnaire) {
                        SessionQuestionnaireView(session: session, embedded: true)
                    } label: {
                        Label("How was the session?", systemImage: "heart.text.square")
                            .font(.subheadline.weight(.semibold))
                    }
                }

                notesSection

                Section {
                    HealthLinkSection(session: session)
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                }
            }
            .navigationTitle("Finish workout")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Back") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Finish") { finish() }
                        .fontWeight(.semibold)
                }
            }
            .onAppear(perform: loadExistingNote)
        }
    }

    // MARK: - Summary

    private var summarySection: some View {
        Section {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())],
                      spacing: Theme.Spacing.m) {
                StatTile(value: Format.durationCompact(currentDuration),
                         label: "Duration", systemImage: "clock")
                StatTile(value: "\(session.exercisesInOrder.count)",
                         label: "Exercises", systemImage: "dumbbell")
                StatTile(value: "\(StatsKit.totalSets(session.orderedSets, includeWarmups: true))",
                         label: "Sets", systemImage: "list.number")
                StatTile(value: Format.weight(totalVolume, includeSymbol: true),
                         label: "Volume", systemImage: "chart.bar")
            }
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)
        } header: {
            Text(session.startTime.formatted(.dateTime.weekday(.wide).month().day().hour().minute()))
        }
    }

    private var currentDuration: TimeInterval {
        max(0, Date().timeIntervalSince(session.startTime))
    }

    private var totalVolume: Double? {
        let v = StatsKit.totalVolumeKg(session.orderedSets)
        return v > 0 ? v : nil
    }

    // MARK: - Top sets

    @ViewBuilder
    private var topSetsSection: some View {
        let tops = WorkoutLoggingHelpers.topSets(in: session)
        if !tops.isEmpty {
            Section("Top sets") {
                ForEach(tops, id: \.set.id) { item in
                    HStack {
                        Text(item.exercise.canonicalName)
                            .font(.subheadline)
                        Spacer()
                        Text(Format.setSummary(item.set))
                            .font(.subheadline.weight(.semibold))
                        if let orm = item.set.estimatedOneRepMaxKg {
                            Text("~1RM \(Format.weight(orm))")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Notes

    private var notesSection: some View {
        Section {
            TextField("Anything to remember about this workout?",
                      text: $noteText, axis: .vertical)
                .lineLimit(2...6)
        } header: {
            Text("Workout note")
        } footer: {
            Text("Saved to your journal for this workout.")
        }
    }

    // MARK: - Existing note

    private func loadExistingNote() {
        if let existing = existingWorkoutNote {
            noteText = existing.text
        }
    }

    private var existingWorkoutNote: JournalEntry? {
        (session.journalEntries ?? [])
            .filter { $0.entryType == .workoutNote && $0.setIdOptional == nil && $0.exerciseIdOptional == nil }
            .sorted { $0.createdAt < $1.createdAt }
            .first
    }

    // MARK: - Finish

    private func finish() {
        guard !didFinish else { dismiss(); return }
        didFinish = true

        saveNote()
        WorkoutLoggingHelpers.finishSession(session, in: context)
        // The workout is over; drop any template link so the planned section
        // does not reappear for a future session (F4).
        TemplateSupport.clearActiveTemplate()
        dismiss()
    }

    private func saveNote() {
        let trimmed = noteText.trimmingCharacters(in: .whitespacesAndNewlines)
        if let existing = existingWorkoutNote {
            if trimmed.isEmpty {
                context.delete(existing)
            } else if existing.text != trimmed {
                existing.text = trimmed
                existing.touch()
            }
        } else if !trimmed.isEmpty {
            let entry = JournalEntry(workout: session, entryType: .workoutNote, text: trimmed)
            entry.workout = session
            context.insert(entry)
        }
        try? context.save()
    }
}

#Preview {
    let container = PersistenceController.makePreviewContainer()
    let context = container.mainContext
    let exercises = (try? context.fetch(FetchDescriptor<Exercise>())) ?? []
    let bench = exercises.first { $0.canonicalName == "Bench Press" }
    let session = WorkoutSession(title: "Today", startTime: Date().addingTimeInterval(-55 * 60))
    context.insert(session)
    if let bench {
        for (i, (w, r, e)) in [(60.0, 8, 2), (70.0, 6, 3), (80.0, 4, 4)].enumerated() {
            let s = WorkoutSet(exercise: bench, exerciseNameAtTime: bench.canonicalName, setIndex: i)
            s.weightKg = w; s.reps = r; s.effort = e; s.workout = session
            context.insert(s)
        }
    }
    try? context.save()
    return FinishWorkoutView(session: session)
        .modelContainer(container)
}
