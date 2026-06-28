import SwiftUI
import SwiftData

/// Fast set-entry sheet for the live workout. Shows recent history for the
/// exercise, big weight/reps inputs, an effort scale, a weight-mode picker that
/// reveals the right load fields (assisted / added / bodyweight), and a "More"
/// disclosure for the optional qualitative fields (spec §7, §8, §16).
///
/// Saving inserts a new `WorkoutSet` with the correct setIndex, exercise,
/// exerciseNameAtTime and workout link.
struct SetEntryView: View {
    let session: WorkoutSession
    let exercise: Exercise
    /// Optional target taken from a template item, used to pre-fill this set's
    /// weight mode / load / reps when starting a workout from a template (F4).
    /// When nil, the view falls back to its usual history-based defaults.
    var prefill: SetPrefill?

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    // Core inputs
    @State private var weightMode: WeightMode = .external
    @State private var weightKg: Double?
    @State private var addedWeightKg: Double?
    @State private var assistanceKg: Double?
    @State private var bodyWeightKg: Double?
    @State private var reps: Int?
    @State private var effort: Int?

    // "More" disclosure
    @State private var showMore = false
    @State private var repsLeft: RepsLeft?
    @State private var formQuality: FormQuality?
    @State private var limiter: Limiter?
    @State private var painSeverity: PainSeverity?
    @State private var painLocation: PainLocation?
    @State private var isWarmup = false
    @State private var note = ""
    /// Superset group for this set: nil = none, 1 = A, 2 = B, … (F10).
    @State private var supersetGroup: Int?

    @State private var didLoadDefaults = false
    @State private var showPlateCalculator = false

    var body: some View {
        NavigationStack {
            Form {
                historySection
                loadSection
                effortSection
                moreSection
            }
            .navigationTitle(exercise.canonicalName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") { save() }
                        .fontWeight(.semibold)
                        .disabled(!canSave)
                }
            }
            .onAppear(perform: loadDefaultsIfNeeded)
            .sheet(isPresented: $showPlateCalculator) {
                PlateCalculatorView(targetKg: weightKg)
            }
        }
    }

    // MARK: - Sections

    @ViewBuilder
    private var historySection: some View {
        let history = WorkoutLoggingHelpers.recentSets(for: exercise, excludingSession: session, limit: 5)
        let inSession = session.orderedSets.filter { $0.exercise?.id == exercise.id }
        Section {
            if inSession.isEmpty && history.isEmpty {
                Text("No history yet for this exercise.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                if !inSession.isEmpty {
                    ForEach(Array(inSession.enumerated()), id: \.element.id) { idx, set in
                        LoggedSetRow(set: set, indexLabel: "#\(idx + 1)")
                    }
                }
                ForEach(history) { set in
                    RecentSetHistoryRow(set: set)
                }
            }
        } header: {
            Text(inSession.isEmpty ? "Recent history" : "This workout · set \(inSession.count + 1)")
        }
    }

    @ViewBuilder
    private var loadSection: some View {
        Section("Load") {
            OptionChipGroupRequired<WeightMode>("Weight type", selection: $weightMode)
                .onChange(of: weightMode) { _, newValue in
                    handleModeChange(newValue)
                }

            switch weightMode {
            case .external:
                weightField(label: nil, binding: $weightKg)
                plateCalculatorButton
            case .bodyweight:
                Text("Pure bodyweight — just log reps below.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                bodyWeightField
            case .addedBodyweight:
                weightField(label: "Added weight (+)", binding: $addedWeightKg)
                bodyWeightField
            case .assistedBodyweight:
                weightField(label: "Assistance (−)", binding: $assistanceKg)
                bodyWeightField
            case .unknown:
                weightField(label: nil, binding: $weightKg)
            }

            VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                Text("Reps")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                RepsStepperField(reps: $reps)
            }
            .padding(.vertical, Theme.Spacing.xs)
        }
    }

    @ViewBuilder
    private var effortSection: some View {
        Section {
            ScaleSelector(
                title: EffortScale.question,
                range: EffortScale.range,
                value: $effort,
                labelProvider: EffortScale.label(for:)
            )
            Toggle("Warm-up set", isOn: $isWarmup)
        }
    }

    @ViewBuilder
    private var moreSection: some View {
        Section {
            DisclosureGroup(isExpanded: $showMore) {
                VStack(alignment: .leading, spacing: Theme.Spacing.l) {
                    OptionChipGroup<RepsLeft>(RepsLeft.question, selection: $repsLeft)
                    OptionChipGroup<FormQuality>("How did it feel / look?", selection: $formQuality)
                    OptionChipGroup<Limiter>("What stopped the set?", selection: $limiter)

                    VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                        OptionChipGroup<PainSeverity>("Pain / discomfort", selection: $painSeverity, tint: .red)
                        if let severity = painSeverity, severity != .none {
                            OptionChipGroup<PainLocation>("Where?", selection: $painLocation, tint: .red)
                        }
                    }

                    supersetPicker

                    VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                        Text("Note")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)
                        TextField("Optional note for this set", text: $note, axis: .vertical)
                            .lineLimit(1...4)
                            .textFieldStyle(.roundedBorder)
                    }
                }
                .padding(.top, Theme.Spacing.s)
            } label: {
                Label("More detail", systemImage: "slider.horizontal.3")
                    .font(.subheadline.weight(.semibold))
            }
        }
    }

    // MARK: - Superset picker (F10)

    /// Groups offered in the picker: None plus A–D (1…4). Kept short for fast
    /// entry; the model supports more (see `SupersetGroup`).
    private let supersetOptions = Array(1...4)

    private var supersetPicker: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            Text("Superset")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
            FlowLayout {
                OptionChip(title: "None",
                           isSelected: supersetGroup == nil,
                           tint: .purple) {
                    supersetGroup = nil
                }
                ForEach(supersetOptions, id: \.self) { number in
                    OptionChip(title: SupersetGroup.letter(for: number) ?? "\(number)",
                               isSelected: supersetGroup == number,
                               tint: .purple) {
                        supersetGroup = (supersetGroup == number) ? nil : number
                    }
                }
            }
        }
    }

    // MARK: - Field builders

    private func weightField(label: String?, binding: Binding<Double?>) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            if let label {
                Text(label)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            WeightStepperField(weightKg: binding,
                               recentKg: WorkoutLoggingHelpers.recentLoadsKg(for: exercise))
        }
        .padding(.vertical, Theme.Spacing.xs)
    }

    /// Opens the plate calculator pre-filled with the current external load.
    /// Only meaningful for `.external` mode (barbell-style loading).
    private var plateCalculatorButton: some View {
        Button {
            showPlateCalculator = true
        } label: {
            Label("Plate calculator", systemImage: "circle.grid.2x2")
                .font(.subheadline.weight(.medium))
        }
        .buttonStyle(.plain)
        .foregroundStyle(Theme.Palette.accent)
    }

    private var bodyWeightField: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            Text("Bodyweight")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
            WeightStepperField(weightKg: $bodyWeightKg,
                               recentKg: bodyWeightSuggestions)
        }
        .padding(.vertical, Theme.Spacing.xs)
    }

    // MARK: - Derived

    private var bodyWeightSuggestions: [Double] {
        var values: [Double] = []
        if let manual = session.bodyWeightManualKg { values.append(manual) }
        if let stored = storedBodyWeightKg { values.append(stored) }
        for set in WorkoutLoggingHelpers.recentSets(for: exercise, limit: 20) {
            if let bw = set.bodyWeightKg, bw > 0 { values.append(bw) }
        }
        var seen = Set<Double>()
        return values.filter { seen.insert($0).inserted }
    }

    private var storedBodyWeightKg: Double? {
        let v = UserDefaults.standard.double(forKey: AppSettingsKeys.lastBodyWeightKg)
        return v > 0 ? v : nil
    }

    private var canSave: Bool {
        // A set is meaningful if it has reps or some load entered.
        if let reps, reps > 0 { return true }
        return effectiveLoadEntered
    }

    private var effectiveLoadEntered: Bool {
        switch weightMode {
        case .external, .unknown: return (weightKg ?? 0) > 0
        case .addedBodyweight: return (addedWeightKg ?? 0) > 0 || (bodyWeightKg ?? 0) > 0
        case .assistedBodyweight: return (bodyWeightKg ?? 0) > 0
        case .bodyweight: return (bodyWeightKg ?? 0) > 0
        }
    }

    // MARK: - Lifecycle

    private func loadDefaultsIfNeeded() {
        guard !didLoadDefaults else { return }
        didLoadDefaults = true

        // A template target (when starting from a template) takes priority over
        // history-derived defaults, but only for the very first set of this
        // exercise in the session — later sets chain from what was just logged.
        let isFirstSetOfExercise = WorkoutLoggingHelpers.lastSetInSession(session, exercise: exercise) == nil
        if let prefill, isFirstSetOfExercise {
            applyPrefill(prefill)
            return
        }

        // Prefer the last set within this session, else the most recent ever.
        let basis = WorkoutLoggingHelpers.lastSetInSession(session, exercise: exercise)
            ?? WorkoutLoggingHelpers.lastSet(for: exercise)

        let suggestion: SetSuggestion
        if let basis {
            suggestion = SetSuggestion(from: basis)
        } else {
            suggestion = SetSuggestion(forNewExercise: exercise, lastBodyWeightKg: defaultBodyWeight)
        }

        weightMode = suggestion.weightMode == .unknown ? exercise.defaultWeightMode : suggestion.weightMode
        weightKg = suggestion.weightKg
        addedWeightKg = suggestion.addedWeightKg
        assistanceKg = suggestion.assistanceKg
        bodyWeightKg = suggestion.bodyWeightKg ?? defaultBodyWeight
        reps = suggestion.reps
        // Effort and qualitative fields are intentionally left blank for each set.

        // Keep the superset grouping for additional sets of the same exercise in
        // this session, so a superset exercise stays in its group by default.
        supersetGroup = WorkoutLoggingHelpers.lastSupersetGroup(for: exercise, in: session)
    }

    /// Applies a template-derived prefill, filling the load field that matches
    /// the target's weight mode and the rep target. History-based defaults are
    /// intentionally skipped so the planned numbers show up exactly.
    private func applyPrefill(_ prefill: SetPrefill) {
        weightMode = prefill.weightMode == .unknown ? exercise.defaultWeightMode : prefill.weightMode
        switch weightMode {
        case .external, .unknown:
            weightKg = prefill.weightKg
        case .addedBodyweight:
            addedWeightKg = prefill.weightKg
            bodyWeightKg = defaultBodyWeight
        case .assistedBodyweight:
            assistanceKg = prefill.weightKg
            bodyWeightKg = defaultBodyWeight
        case .bodyweight:
            bodyWeightKg = defaultBodyWeight
        }
        reps = prefill.reps
    }

    private var defaultBodyWeight: Double? {
        session.bodyWeightManualKg ?? storedBodyWeightKg
    }

    private func handleModeChange(_ mode: WeightMode) {
        // Ensure bodyweight is pre-filled when switching into a BW-based mode.
        if mode == .bodyweight || mode == .addedBodyweight || mode == .assistedBodyweight {
            if (bodyWeightKg ?? 0) <= 0 {
                bodyWeightKg = defaultBodyWeight
            }
        }
    }

    // MARK: - Save

    private func save() {
        let index = WorkoutLoggingHelpers.nextSetIndex(in: session)
        let set = WorkoutSet(
            exercise: exercise,
            exerciseNameAtTime: exercise.canonicalName,
            setIndex: index,
            timestamp: Date(),
            weightMode: weightMode,
            source: .manual
        )

        // Load fields by mode.
        switch weightMode {
        case .external, .unknown:
            set.weightKg = weightKg
        case .addedBodyweight:
            set.addedWeightKg = addedWeightKg
            set.bodyWeightKg = bodyWeightKg
        case .assistedBodyweight:
            set.assistanceKg = assistanceKg
            set.bodyWeightKg = bodyWeightKg
        case .bodyweight:
            set.bodyWeightKg = bodyWeightKg
        }

        set.reps = reps
        set.effort = effort
        set.isWarmup = isWarmup
        set.isFailed = (repsLeft == .failed) || (limiter == .muscleFailed)

        set.repsLeft = repsLeft
        set.formQuality = formQuality
        set.limiter = limiter
        set.painSeverity = painSeverity
        set.painLocation = (painSeverity != nil && painSeverity != PainSeverity.none) ? painLocation : nil
        set.supersetGroup = supersetGroup
        set.notes = note.trimmingCharacters(in: .whitespacesAndNewlines)

        set.workout = session

        context.insert(set)
        session.touch()

        // Remember bodyweight for next time when it was used.
        if let bw = bodyWeightKg, bw > 0,
           weightMode == .bodyweight || weightMode == .addedBodyweight || weightMode == .assistedBodyweight {
            UserDefaults.standard.set(bw, forKey: AppSettingsKeys.lastBodyWeightKg)
        }

        try? context.save()
        dismiss()
    }
}

/// A lightweight target used to pre-fill `SetEntryView` when logging a planned
/// exercise from a template (F4). `weightKg` holds the load in the field that
/// matches `weightMode` (external load, added weight, or assistance).
struct SetPrefill {
    var weightMode: WeightMode
    var weightKg: Double?
    var reps: Int?

    init(weightMode: WeightMode = .external, weightKg: Double? = nil, reps: Int? = nil) {
        self.weightMode = weightMode
        self.weightKg = weightKg
        self.reps = reps
    }

    /// Builds a prefill from a template item's targets.
    init(item: TemplateItem) {
        self.weightMode = item.weightMode
        self.weightKg = item.targetWeightKg
        self.reps = item.targetReps
    }
}

#Preview {
    let container = PersistenceController.makePreviewContainer()
    let context = container.mainContext
    let exercises = (try? context.fetch(FetchDescriptor<Exercise>())) ?? []
    let exercise = exercises.first { $0.canonicalName == "Bench Press" } ?? Exercise(canonicalName: "Bench Press")
    let session: WorkoutSession = {
        let sessions = (try? context.fetch(FetchDescriptor<WorkoutSession>())) ?? []
        if let active = sessions.first(where: { $0.endTime == nil }) { return active }
        let s = WorkoutSession()
        context.insert(s)
        return s
    }()
    return SetEntryView(session: session, exercise: exercise)
        .modelContainer(container)
}
