import SwiftUI
import SwiftData

/// Edit a single already-logged `WorkoutSet`.
///
/// Covers weight mode + the relevant load fields, reps, effort, the optional
/// form/limiter/pain detail, warm-up / failed flags and a note. On save the set
/// is marked `.edited` and `touch()`ed so provenance and timestamps stay honest.
struct SetEditView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    let set: WorkoutSet

    // Editable copies; committed to the model on save.
    @State private var weightMode: WeightMode
    @State private var weightKg: Double?
    @State private var assistanceKg: Double?
    @State private var addedWeightKg: Double?
    @State private var bodyWeightKg: Double?
    @State private var reps: Int?
    @State private var effort: Int?
    @State private var formQuality: FormQuality?
    @State private var limiter: Limiter?
    @State private var painSeverity: PainSeverity?
    @State private var painLocation: PainLocation?
    @State private var isWarmup: Bool
    @State private var isFailed: Bool
    @State private var notes: String

    init(set: WorkoutSet) {
        self.set = set
        _weightMode = State(initialValue: set.weightMode)
        _weightKg = State(initialValue: set.weightKg)
        _assistanceKg = State(initialValue: set.assistanceKg)
        _addedWeightKg = State(initialValue: set.addedWeightKg)
        _bodyWeightKg = State(initialValue: set.bodyWeightKg)
        _reps = State(initialValue: set.reps)
        _effort = State(initialValue: set.effort)
        _formQuality = State(initialValue: set.formQuality)
        _limiter = State(initialValue: set.limiter)
        _painSeverity = State(initialValue: set.painSeverity)
        _painLocation = State(initialValue: set.painLocation)
        _isWarmup = State(initialValue: set.isWarmup)
        _isFailed = State(initialValue: set.isFailed)
        _notes = State(initialValue: set.notes)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text(set.exerciseNameAtTime.isEmpty
                         ? (set.exercise?.canonicalName ?? "Exercise")
                         : set.exerciseNameAtTime)
                        .font(.headline)
                    if set.source != .manual {
                        SourceBadge(text: set.source.displayName,
                                    systemImage: "pencil.circle")
                    }
                }

                Section("Load") {
                    OptionChipGroupRequired<WeightMode>("Mode", selection: $weightMode)
                    loadFields
                }

                Section("Reps") {
                    RepsStepperField(reps: $reps)
                }

                Section("Effort") {
                    ScaleSelector(
                        title: EffortScale.question,
                        range: EffortScale.range,
                        value: $effort,
                        labelProvider: EffortScale.label(for:)
                    )
                }

                Section("Detail") {
                    OptionChipGroup<FormQuality>("Form", selection: $formQuality)
                    OptionChipGroup<Limiter>("What limited the set?", selection: $limiter)
                    OptionChipGroup<PainSeverity>("Pain / discomfort", selection: $painSeverity)
                    if painSeverity != nil && painSeverity != PainSeverity.none {
                        OptionChipGroup<PainLocation>("Where?", selection: $painLocation)
                    }
                }

                Section("Flags") {
                    Toggle("Warm-up set", isOn: $isWarmup)
                    Toggle("Failed set", isOn: $isFailed)
                }

                Section("Notes") {
                    TextField("Optional note", text: $notes, axis: .vertical)
                        .lineLimit(1...4)
                }
            }
            .navigationTitle("Edit set")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") { save() }
                }
            }
        }
    }

    // MARK: Load fields depend on the weight mode

    @ViewBuilder
    private var loadFields: some View {
        switch weightMode {
        case .external, .unknown:
            WeightStepperField(weightKg: $weightKg, recentKg: recentWeights)
        case .bodyweight:
            bodyWeightField
        case .assistedBodyweight:
            bodyWeightField
            labeledStepper("Assistance", binding: $assistanceKg)
        case .addedBodyweight:
            bodyWeightField
            labeledStepper("Added weight", binding: $addedWeightKg)
        }
    }

    private var bodyWeightField: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            Text("Bodyweight")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
            WeightStepperField(weightKg: $bodyWeightKg, recentKg: recentBodyWeights)
        }
    }

    private func labeledStepper(_ title: String, binding: Binding<Double?>) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
            WeightStepperField(weightKg: binding)
        }
    }

    // MARK: Recent values (same exercise) for quick-pick

    private var recentWeights: [Double] {
        recentSets.compactMap(\.weightKg)
    }

    private var recentBodyWeights: [Double] {
        recentSets.compactMap(\.bodyWeightKg)
    }

    private var recentSets: [WorkoutSet] {
        guard let exercise = set.exercise else { return [] }
        return exercise.orderedSets
            .filter { $0.id != set.id }
            .prefix(12)
            .map { $0 }
    }

    // MARK: Save

    private func save() {
        set.weightMode = weightMode
        set.weightKg = weightKg
        set.assistanceKg = assistanceKg
        set.addedWeightKg = addedWeightKg
        set.bodyWeightKg = bodyWeightKg
        set.reps = reps
        set.effort = effort
        set.formQuality = formQuality
        set.limiter = limiter
        set.painSeverity = painSeverity
        set.painLocation = (painSeverity == nil || painSeverity == PainSeverity.none) ? nil : painLocation
        set.isWarmup = isWarmup
        set.isFailed = isFailed
        set.notes = notes
        set.source = .edited
        set.touch()
        try? context.save()
        dismiss()
    }
}

#Preview {
    let container = PersistenceController.makePreviewContainer()
    let set = (try? container.mainContext.fetch(FetchDescriptor<WorkoutSet>()))?.first
        ?? WorkoutSet()
    return SetEditView(set: set)
        .modelContainer(container)
}
