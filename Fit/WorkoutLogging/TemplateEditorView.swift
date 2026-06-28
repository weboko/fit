import SwiftUI
import SwiftData

/// Edits one `WorkoutTemplate`: its name/notes and an ordered list of planned
/// items. Items can be added via the shared `ExercisePickerView`, given a target
/// sets / reps / weight, reordered and deleted (spec F4). Changes are written
/// straight to the model context and the template is `touch()`-ed on save.
struct TemplateEditorView: View {
    @Bindable var template: WorkoutTemplate

    @Environment(\.modelContext) private var context

    @State private var showPicker = false

    var body: some View {
        Form {
            detailsSection
            itemsSection
        }
        .navigationTitle("Edit template")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                EditButton()
            }
        }
        .sheet(isPresented: $showPicker) {
            ExercisePickerView { exercise in
                addItem(exercise)
            }
        }
        .onDisappear(perform: persist)
    }

    // MARK: - Sections

    private var detailsSection: some View {
        Section("Details") {
            TextField("Template name", text: $template.name)
                .onChange(of: template.name) { _, _ in persist() }
            TextField("Notes (optional)", text: $template.notes, axis: .vertical)
                .lineLimit(1...4)
                .onChange(of: template.notes) { _, _ in persist() }
        }
    }

    @ViewBuilder
    private var itemsSection: some View {
        let items = template.orderedItems
        Section {
            if items.isEmpty {
                Text("No exercises yet. Add one below.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(items) { item in
                    TemplateItemRow(item: item, onChange: persist)
                }
                .onMove(perform: move)
                .onDelete(perform: delete)
            }
        } header: {
            Text("Exercises")
        } footer: {
            Text("Targets pre-fill the set entry when you start a workout from this template.")
        }

        Section {
            Button {
                showPicker = true
            } label: {
                Label("Add exercise", systemImage: "plus.circle.fill")
            }
        }
    }

    // MARK: - Actions

    private func addItem(_ exercise: Exercise) {
        let nextOrder = (template.orderedItems.map(\.order).max() ?? -1) + 1
        let item = TemplateItem(
            order: nextOrder,
            targetSets: 3,
            targetReps: nil,
            targetWeightKg: nil,
            weightMode: exercise.defaultWeightMode,
            exercise: exercise,
            exerciseNameAtTime: exercise.canonicalName
        )
        item.template = template
        context.insert(item)
        var existing = template.items ?? []
        existing.append(item)
        template.items = existing
        persist()
    }

    private func move(from offsets: IndexSet, to destination: Int) {
        var ordered = template.orderedItems
        ordered.move(fromOffsets: offsets, toOffset: destination)
        for (index, item) in ordered.enumerated() {
            item.order = index
        }
        persist()
    }

    private func delete(at offsets: IndexSet) {
        let ordered = template.orderedItems
        for index in offsets {
            context.delete(ordered[index])
        }
        // Re-pack order on the survivors so it stays a dense 0-based sequence.
        for (index, item) in template.orderedItems.enumerated() {
            item.order = index
        }
        persist()
    }

    private func persist() {
        template.touch()
        try? context.save()
    }
}

/// One editable row in the template editor: target sets stepper plus optional
/// reps and weight fields, with a weight-mode picker.
private struct TemplateItemRow: View {
    @Bindable var item: TemplateItem
    var onChange: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            Text(item.displayName)
                .font(.headline)

            Stepper(value: $item.targetSets, in: 1...20) {
                HStack {
                    Text("Target sets")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("\(item.targetSets)")
                        .font(.body.weight(.semibold))
                }
            }
            .onChange(of: item.targetSets) { _, _ in onChange() }

            Picker("Weight type", selection: weightModeBinding) {
                ForEach(WeightMode.allCases.filter { $0 != .unknown }) { mode in
                    Text(mode.displayName).tag(mode)
                }
            }
            .pickerStyle(.menu)

            VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                Text("Target reps (optional)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                RepsStepperField(reps: $item.targetReps)
                    .onChange(of: item.targetReps) { _, _ in onChange() }
            }

            if item.weightMode != .bodyweight {
                VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                    Text(weightLabel)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                    WeightStepperField(weightKg: $item.targetWeightKg)
                        .onChange(of: item.targetWeightKg) { _, _ in onChange() }
                }
            }
        }
        .padding(.vertical, Theme.Spacing.xs)
    }

    private var weightLabel: String {
        switch item.weightMode {
        case .addedBodyweight: return "Target added weight (optional)"
        case .assistedBodyweight: return "Target assistance (optional)"
        default: return "Target weight (optional)"
        }
    }

    /// A binding to the item's weight mode that also persists on change.
    private var weightModeBinding: Binding<WeightMode> {
        Binding(
            get: { item.weightMode },
            set: { newValue in
                item.weightMode = newValue
                onChange()
            }
        )
    }
}

#Preview {
    let container = PersistenceController.makePreviewContainer()
    let context = container.mainContext
    let exercises = (try? context.fetch(FetchDescriptor<Exercise>())) ?? []
    let template = WorkoutTemplate(name: "Push day")
    context.insert(template)
    if let bench = exercises.first(where: { $0.canonicalName == "Bench Press" }) {
        let item = TemplateItem(order: 0, targetSets: 4, targetReps: 8, targetWeightKg: 60,
                                weightMode: .external, exercise: bench,
                                exerciseNameAtTime: bench.canonicalName)
        item.template = template
        context.insert(item)
        template.items = [item]
    }
    try? context.save()
    return NavigationStack {
        TemplateEditorView(template: template)
    }
    .modelContainer(container)
}
