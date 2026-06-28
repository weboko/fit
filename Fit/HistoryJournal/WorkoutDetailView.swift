import SwiftUI
import SwiftData

/// Full detail of one `WorkoutSession`: metadata, exercises with their sets,
/// linked Apple Health, journal notes for this session, plus edit/export.
///
/// Consumes two cross-module symbols (provided elsewhere, used here as-is):
/// - `HealthLinkSection(session:)` from HealthImport.
/// - `WorkoutShareButton(session:)` from Export.
struct WorkoutDetailView: View {
    @Environment(\.modelContext) private var context

    let session: WorkoutSession

    @State private var showingEdit = false
    @State private var editingSet: WorkoutSet?
    @State private var addingNote = false
    @State private var editingNote: JournalEntry?

    // F4: save-as-template confirmation.
    @State private var savedTemplateName: String?
    @State private var showSavedTemplateAlert = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.l) {
                header
                metadataCard
                exercisesCard
                HealthLinkSection(session: session)
                journalCard
            }
            .padding(Theme.Spacing.l)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(session.displayTitle())
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        showingEdit = true
                    } label: {
                        Label("Edit workout", systemImage: "pencil")
                    }
                    Button {
                        saveAsTemplate()
                    } label: {
                        Label("Save as template", systemImage: "list.bullet.rectangle.portrait")
                    }
                    .disabled(session.exercisesInOrder.isEmpty)
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                WorkoutShareButton(session: session)
            }
        }
        .alert("Template saved", isPresented: $showSavedTemplateAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(savedTemplateMessage)
        }
        .sheet(isPresented: $showingEdit) {
            WorkoutEditView(session: session)
        }
        .sheet(item: $editingSet) { set in
            SetEditView(set: set)
        }
        .sheet(isPresented: $addingNote) {
            JournalEntryEditor(workout: session)
        }
        .sheet(item: $editingNote) { note in
            JournalEntryEditor(entry: note)
        }
    }

    // MARK: Header

    private var header: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            HStack {
                Text(Format.relativeDay(session.startTime))
                    .font(.title3.weight(.bold))
                Spacer()
                if session.isBackfilled {
                    SourceBadge(text: "Backfilled", systemImage: "clock.arrow.circlepath")
                }
                if session.isActive {
                    SourceBadge(text: "In progress", systemImage: "record.circle", tint: .red)
                }
            }
            HStack(spacing: Theme.Spacing.s) {
                StatTile(value: timeRangeString, label: "Time", systemImage: "clock")
                StatTile(value: Format.durationCompact(session.duration), label: "Duration", systemImage: "timer")
                StatTile(value: "\(workingSetCount)", label: "Working sets", systemImage: "list.number")
            }
        }
    }

    private var timeRangeString: String {
        let start = session.startTime.formatted(date: .omitted, time: .shortened)
        guard let end = session.endTime else { return start }
        return "\(start)–\(end.formatted(date: .omitted, time: .shortened))"
    }

    private var workingSetCount: Int {
        session.workingSets.count
    }

    // MARK: Metadata

    @ViewBuilder
    private var metadataCard: some View {
        if hasMetadata {
            SectionCard("Session", systemImage: "doc.text") {
                VStack(spacing: Theme.Spacing.s) {
                    if let goal = session.goal { DetailRow(label: "Goal", value: goal.displayName) }
                    if let location = session.location { DetailRow(label: "Location", value: location.displayName) }
                    if let energy = session.energyBefore {
                        DetailRow(label: "Energy", value: EnergyScale.label(for: energy))
                    }
                    if let soreness = session.soreness { DetailRow(label: "Soreness", value: soreness.displayName) }
                    if let pain = session.painToday { DetailRow(label: "Pain today", value: pain.displayName) }
                    if let sleep = session.sleepQualitySubjective {
                        DetailRow(label: "Sleep", value: sleep.displayName)
                    }
                    if let stress = session.stressLevel {
                        DetailRow(label: "Stress", value: StressScale.label(for: stress))
                    }
                    if let food = session.foodTiming { DetailRow(label: "Food timing", value: food.displayName) }
                    if let caffeine = session.caffeine { DetailRow(label: "Caffeine", value: caffeine.displayName) }
                    if let bw = session.bodyWeightManualKg {
                        DetailRow(label: "Bodyweight", value: Format.weight(bw))
                    }
                }
            }
        }
    }

    private var hasMetadata: Bool {
        session.goal != nil || session.location != nil || session.energyBefore != nil ||
        session.soreness != nil || session.painToday != nil || session.sleepQualitySubjective != nil ||
        session.stressLevel != nil || session.foodTiming != nil || session.caffeine != nil ||
        session.bodyWeightManualKg != nil
    }

    // MARK: Exercises + sets

    @ViewBuilder
    private var exercisesCard: some View {
        let exercises = session.exercisesInOrder
        SectionCard("Exercises", systemImage: "dumbbell") {
            if exercises.isEmpty {
                Text("No sets logged.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                VStack(alignment: .leading, spacing: Theme.Spacing.l) {
                    ForEach(exercises) { exercise in
                        exerciseBlock(exercise)
                    }
                }
            }
        }
    }

    private func exerciseBlock(_ exercise: Exercise) -> some View {
        let sets = session.orderedSets.filter { $0.exercise?.id == exercise.id }
        return VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            Text(exercise.canonicalName)
                .font(.headline)
            ForEach(sets) { set in
                Button {
                    editingSet = set
                } label: {
                    setRow(set)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func setRow(_ set: WorkoutSet) -> some View {
        let prKinds = PersonalRecords.kinds(for: set, in: set.exercise?.sets ?? [])
        return HStack(spacing: Theme.Spacing.m) {
            if set.isWarmup {
                Image(systemName: "flame")
                    .foregroundStyle(.orange)
                    .font(.caption)
            }
            Text(Format.setSummary(set))
                .font(.body.monospacedDigit())
            PRBadge(kinds: prKinds)
            SupersetBadge(group: set.supersetGroup)
            Spacer(minLength: Theme.Spacing.s)
            if let effort = set.effort {
                Text(EffortScale.shortLabel(for: effort))
                    .font(.caption)
                    .foregroundStyle(Theme.Palette.intensity(effort))
            }
            if set.isFailed {
                Image(systemName: "xmark.circle").foregroundStyle(.red).font(.caption)
            }
            if set.source == .edited || set.source == .backfilled {
                SourceBadge(text: set.source.displayName, systemImage: "pencil.circle")
            }
            Image(systemName: "chevron.right")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .contentShape(Rectangle())
        .padding(.vertical, 2)
    }

    // MARK: Journal notes for this session

    private var journalCard: some View {
        SectionCard("Notes", systemImage: "note.text") {
            VStack(alignment: .leading, spacing: Theme.Spacing.m) {
                if sessionNotes.isEmpty {
                    Text("No notes for this workout yet.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(sessionNotes) { note in
                        Button {
                            editingNote = note
                        } label: {
                            noteRow(note)
                        }
                        .buttonStyle(.plain)
                    }
                }
                Button {
                    addingNote = true
                } label: {
                    Label("Add note", systemImage: "plus.circle")
                }
            }
        }
    }

    private func noteRow(_ note: JournalEntry) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            HStack {
                Text(note.entryType.displayName)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Text(note.timestamp.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Text(note.text.isEmpty ? "(empty note)" : note.text)
                .font(.body)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Theme.Spacing.m)
        .background(Theme.Palette.subtle)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Size.cornerRadius, style: .continuous))
    }

    private var sessionNotes: [JournalEntry] {
        (session.journalEntries ?? []).sorted { $0.timestamp > $1.timestamp }
    }

    // MARK: - Save as template (F4)

    /// Builds a template from this session — one item per distinct exercise with
    /// target sets/reps/weight from a representative top set — inserts it and
    /// confirms with an alert.
    private func saveAsTemplate() {
        guard !session.exercisesInOrder.isEmpty else { return }
        let template = TemplateSupport.makeTemplate(from: session)
        context.insert(template)
        for item in template.items ?? [] {
            context.insert(item)
        }
        try? context.save()
        savedTemplateName = template.displayName
        showSavedTemplateAlert = true
    }

    private var savedTemplateMessage: String {
        let name = savedTemplateName ?? "Template"
        return "“\(name)” was saved. Start a workout from it on the Today screen."
    }
}

#Preview {
    let container = PersistenceController.makePreviewContainer()
    let session = (try? container.mainContext.fetch(FetchDescriptor<WorkoutSession>()))?.first
        ?? WorkoutSession(title: "Sample")
    return NavigationStack {
        WorkoutDetailView(session: session)
    }
    .modelContainer(container)
}
