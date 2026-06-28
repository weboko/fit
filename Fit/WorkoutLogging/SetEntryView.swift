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

    @State private var didLoadDefaults = false

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
