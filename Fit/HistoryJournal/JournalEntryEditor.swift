import SwiftUI
import SwiftData

/// Create or edit a `JournalEntry` at workout / exercise / set level.
///
/// - `JournalEntryEditor(entry:)` edits an existing entry.
/// - `JournalEntryEditor(workout:exerciseId:setId:entryType:)` creates a new one,
///   optionally pre-attached to a workout / exercise / set context.
///
/// The chosen `entryType` follows the level the note is attached to. The created
/// and last-edited timestamps are shown for transparency.
struct JournalEntryEditor: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    /// The entry being edited, or nil when creating a new one.
    private let existing: JournalEntry?

    // Creation context (ignored when editing an existing entry).
    private let creationWorkout: WorkoutSession?
    private let creationExerciseId: UUID?
    private let creationSetId: UUID?

    @State private var text: String
    @State private var entryType: JournalEntryType
    @State private var timestamp: Date

    @FocusState private var textFocused: Bool

    /// Edit an existing entry.
    init(entry: JournalEntry) {
        self.existing = entry
        self.creationWorkout = nil
        self.creationExerciseId = nil
        self.creationSetId = nil
        _text = State(initialValue: entry.text)
        _entryType = State(initialValue: entry.entryType)
        _timestamp = State(initialValue: entry.timestamp)
    }

    /// Create a new entry, optionally attached to a workout / exercise / set.
    init(
        workout: WorkoutSession?,
        exerciseId: UUID? = nil,
        setId: UUID? = nil,
        entryType: JournalEntryType? = nil
    ) {
        self.existing = nil
        self.creationWorkout = workout
        self.creationExerciseId = exerciseId
        self.creationSetId = setId
        _text = State(initialValue: "")
        let defaultType: JournalEntryType = entryType ?? {
            if setId != nil { return .setNote }
            if exerciseId != nil { return .exerciseNote }
            return .workoutNote
        }()
        _entryType = State(initialValue: defaultType)
        _timestamp = State(initialValue: Date())
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextEditor(text: $text)
                        .frame(minHeight: 140)
                        .focused($textFocused)
                } header: {
                    Text("Note")
                }

                Section("Type") {
                    OptionMenuPicker(title: "Level", selection: entryTypeBinding, noneLabel: "Workout note")
                }

                Section("When") {
                    DatePicker("Timestamp", selection: $timestamp)
                }

                if let context = contextLabel {
                    Section("Attached to") {
                        DetailRow(label: "Context", value: context)
                    }
                }

                Section {
                    DetailRow(label: "Created", value: createdString)
                    if let edited = editedString {
                        DetailRow(label: "Last edited", value: edited)
                    }
                } footer: {
                    Text("Journal notes are separate from logged sets. Edit any time.")
                }
            }
            .navigationTitle(existing == nil ? "New note" : "Edit note")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") { save() }
                        .disabled(trimmedText.isEmpty)
                }
            }
            .onAppear { textFocused = existing == nil }
        }
    }

    // MARK: Bindings

    /// `OptionMenuPicker` needs an optional binding; map nil → workoutNote.
    private var entryTypeBinding: Binding<JournalEntryType?> {
        Binding(
            get: { entryType },
            set: { entryType = $0 ?? .workoutNote }
        )
    }

    // MARK: Derived display

    private var trimmedText: String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var contextLabel: String? {
        let workout = existing?.workout ?? creationWorkout
        if let workout { return workout.displayTitle() }
        return nil
    }

    private var createdString: String {
        let date = existing?.createdAt ?? Date()
        return date.formatted(date: .abbreviated, time: .shortened)
    }

    private var editedString: String? {
        guard let existing else { return nil }
        guard existing.updatedAt > existing.createdAt.addingTimeInterval(1) else { return nil }
        return existing.updatedAt.formatted(date: .abbreviated, time: .shortened)
    }

    // MARK: Save

    private func save() {
        if let entry = existing {
            entry.text = trimmedText
            entry.entryType = entryType
            entry.timestamp = timestamp
            entry.touch()
        } else {
            let entry = JournalEntry(
                workout: creationWorkout,
                exerciseIdOptional: creationExerciseId,
                setIdOptional: creationSetId,
                timestamp: timestamp,
                entryType: entryType,
                text: trimmedText
            )
            context.insert(entry)
        }
        try? context.save()
        dismiss()
    }
}

#Preview("Edit") {
    let container = PersistenceController.makePreviewContainer()
    let entry = (try? container.mainContext.fetch(FetchDescriptor<JournalEntry>()))?.first
        ?? JournalEntry(text: "Sample note")
    return JournalEntryEditor(entry: entry)
        .modelContainer(container)
}

#Preview("New") {
    JournalEntryEditor(workout: nil)
        .modelContainer(PersistenceController.makePreviewContainer())
}
