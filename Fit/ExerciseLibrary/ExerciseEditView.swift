import SwiftUI
import SwiftData

/// Create or edit an exercise definition: name, classification, default weight
/// mode, primary/secondary muscles and aliases (spec §10.2, §10.3, §21). A
/// name-only minimum is allowed for fast capture.
struct ExerciseEditView: View {
    @Bindable var exercise: Exercise

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    // Working copies so edits only commit on Save.
    @State private var canonicalName: String
    @State private var category: ExerciseCategory?
    @State private var equipment: Equipment?
    @State private var movementPattern: MovementPattern?
    @State private var defaultWeightMode: WeightMode
    @State private var primaryMuscles: Set<MuscleGroup>
    @State private var secondaryMuscles: Set<MuscleGroup>
    @State private var notes: String

    // Alias editing buffers.
    @State private var aliasDrafts: [AliasDraft]
    @State private var newAliasName = ""
    @State private var newAliasLanguage = ""

    init(exercise: Exercise) {
        self.exercise = exercise
        _canonicalName = State(initialValue: exercise.canonicalName)
        _category = State(initialValue: exercise.category)
        _equipment = State(initialValue: exercise.equipment)
        _movementPattern = State(initialValue: exercise.movementPattern)
        _defaultWeightMode = State(initialValue: exercise.defaultWeightMode)
        _primaryMuscles = State(initialValue: Set(exercise.primaryMuscles))
        _secondaryMuscles = State(initialValue: Set(exercise.secondaryMuscles))
        _notes = State(initialValue: exercise.notes)
        let drafts = (exercise.aliases ?? []).map {
            AliasDraft(existing: $0, name: $0.aliasName, language: $0.languageOptional ?? "")
        }
        _aliasDrafts = State(initialValue: drafts)
    }

    var body: some View {
        Form {
            Section("Name") {
                TextField("Exercise name", text: $canonicalName)
                    .font(.body.weight(.medium))
            }

            Section("Classification") {
                OptionMenuPicker(title: "Category", selection: $category)
                OptionMenuPicker(title: "Equipment", selection: $equipment)
                OptionMenuPicker(title: "Movement", selection: $movementPattern)
                Picker("Default weight mode", selection: $defaultWeightMode) {
                    ForEach(Array(WeightMode.allCases)) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }
            }

            Section("Primary muscles") {
                muscleSelector(selection: $primaryMuscles)
            }

            Section("Secondary muscles") {
                muscleSelector(selection: $secondaryMuscles)
            }

            Section("Aliases") {
                if aliasDrafts.isEmpty {
                    Text("No aliases yet. Add alternative names (any language).")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach($aliasDrafts) { $draft in
                        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                            TextField("Alias", text: $draft.name)
                            TextField("Language (optional, e.g. uk)", text: $draft.language)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .textInputAutocapitalization(.never)
                        }
                    }
                    .onDelete { offsets in
                        aliasDrafts.remove(atOffsets: offsets)
                    }
                }

                VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                    TextField("Add alias", text: $newAliasName)
                    HStack {
                        TextField("Language (optional)", text: $newAliasLanguage)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .textInputAutocapitalization(.never)
                        Spacer()
                        Button {
                            addAlias()
                        } label: {
                            Label("Add", systemImage: "plus.circle.fill")
                        }
                        .disabled(trimmedNewAlias.isEmpty)
                    }
                }
            }

            Section("Notes") {
                TextField("Notes", text: $notes, axis: .vertical)
                    .lineLimit(2...6)
            }
        }
        .navigationTitle(canonicalName.isEmpty ? "New Exercise" : "Edit Exercise")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Save") { save() }
                    .disabled(trimmedName.isEmpty)
            }
        }
    }

    // MARK: - Muscle selector (multi-select, not single-select)

    private func muscleSelector(selection: Binding<Set<MuscleGroup>>) -> some View {
        FlowLayout {
            ForEach(Array(MuscleGroup.allCases)) { muscle in
                OptionChip(title: muscle.displayName,
                           isSelected: selection.wrappedValue.contains(muscle)) {
                    if selection.wrappedValue.contains(muscle) {
                        selection.wrappedValue.remove(muscle)
                    } else {
                        selection.wrappedValue.insert(muscle)
                    }
                }
            }
        }
    }

    // MARK: - Derived

    private var trimmedName: String {
        canonicalName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var trimmedNewAlias: String {
        newAliasName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Actions

    private func addAlias() {
        let name = trimmedNewAlias
        guard !name.isEmpty else { return }
        let language = newAliasLanguage.trimmingCharacters(in: .whitespacesAndNewlines)
        aliasDrafts.append(AliasDraft(existing: nil, name: name, language: language))
        newAliasName = ""
        newAliasLanguage = ""
    }

    private func save() {
        exercise.canonicalName = trimmedName

        // Stable enum ordering so storage stays deterministic.
        let order = Array(MuscleGroup.allCases)
        exercise.category = category
        exercise.equipment = equipment
        exercise.movementPattern = movementPattern
        exercise.defaultWeightMode = defaultWeightMode
        exercise.primaryMuscles = order.filter { primaryMuscles.contains($0) }
        exercise.secondaryMuscles = order.filter { secondaryMuscles.contains($0) }
        exercise.notes = notes

        syncAliases()
        exercise.touch()
        try? context.save()
        dismiss()
    }

    /// Reconcile alias drafts with the persisted alias objects: update existing,
    /// insert new, delete removed.
    private func syncAliases() {
        let existing = exercise.aliases ?? []
        let keptExisting = aliasDrafts.compactMap(\.existing)
        let keptIDs = Set(keptExisting.map(\.id))

        // Delete aliases removed from the list.
        for alias in existing where !keptIDs.contains(alias.id) {
            context.delete(alias)
        }

        for draft in aliasDrafts {
            let name = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
            let language = draft.language.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty else {
                // An emptied existing alias is dropped.
                if let existing = draft.existing { context.delete(existing) }
                continue
            }
            if let existing = draft.existing {
                existing.aliasName = name
                existing.languageOptional = language.isEmpty ? nil : language
            } else {
                let alias = ExerciseAlias(
                    aliasName: name,
                    languageOptional: language.isEmpty ? nil : language,
                    exercise: exercise
                )
                context.insert(alias)
            }
        }
    }
}

/// A mutable, identifiable draft for an alias row in the editor.
private struct AliasDraft: Identifiable {
    let id = UUID()
    let existing: ExerciseAlias?
    var name: String
    var language: String
}

#Preview {
    let container = PersistenceController.makePreviewContainer()
    let exercise = Exercise(
        canonicalName: "Lat Pulldown",
        category: .back,
        equipment: .cable,
        movementPattern: .verticalPull,
        primaryMuscles: [.lats],
        secondaryMuscles: [.biceps]
    )
    container.mainContext.insert(exercise)
    let alias = ExerciseAlias(aliasName: "тяга блока", languageOptional: "uk", exercise: exercise)
    container.mainContext.insert(alias)
    return NavigationStack {
        ExerciseEditView(exercise: exercise)
    }
    .modelContainer(container)
}
