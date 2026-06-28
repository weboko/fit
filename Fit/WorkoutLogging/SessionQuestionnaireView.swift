import SwiftUI
import SwiftData

/// Optional once-per-workout subjective questionnaire (spec §8). All fields are
/// optional and write straight back to the session via its typed accessors.
/// First-priority metadata is shown by default; second-priority lives behind a
/// "More" disclosure to keep the gym flow fast.
///
/// Used standalone (presented as a sheet during a workout) and embedded inside
/// `FinishWorkoutView`.
struct SessionQuestionnaireView: View {
    @Bindable var session: WorkoutSession

    /// When embedded (e.g. in the finish screen) we hide the navigation chrome
    /// and the standalone Done button.
    var embedded: Bool = false

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    @State private var showSecondary = false

    var body: some View {
        if embedded {
            // Embedded inside another Form/Section (e.g. the finish screen):
            // use plain stacked fields, never nested Sections.
            VStack(alignment: .leading, spacing: Theme.Spacing.l) {
                Text("All of this is optional — log what's useful to you.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                goalFields
                readinessFields
                secondaryDisclosure
            }
            .padding(.vertical, Theme.Spacing.s)
        } else {
            Form {
                Section {
                    goalFields
                } header: {
                    Text("Goal")
                } footer: {
                    Text("All of this is optional — log what's useful to you.")
                }
                Section("Readiness") {
                    readinessFields
                }
                Section {
                    secondaryDisclosure
                }
            }
            .navigationTitle("How are you feeling?")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        persist()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
            .onDisappear(perform: persist)
        }
    }

    // MARK: - Field groups

    private var goalFields: some View {
        OptionChipGroup<WorkoutGoal>("Today's focus", selection: bind(\.goal))
    }

    private var readinessFields: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.l) {
            ScaleSelector(
                title: EnergyScale.question,
                range: EnergyScale.range,
                value: $session.energyBefore,
                labelProvider: EnergyScale.label(for:)
            )
            OptionChipGroup<Soreness>("Muscle soreness", selection: bind(\.soreness))
            OptionChipGroup<SleepQuality>("How did you sleep?", selection: bind(\.sleepQualitySubjective))
            OptionChipGroup<PainToday>("Any pain today?", selection: bind(\.painToday), tint: .red)
        }
    }

    private var secondaryDisclosure: some View {
        DisclosureGroup("More (optional)", isExpanded: $showSecondary) {
            VStack(alignment: .leading, spacing: Theme.Spacing.l) {
                ScaleSelector(
                    title: StressScale.question,
                    range: StressScale.range,
                    value: $session.stressLevel,
                    labelProvider: StressScale.label(for:)
                )
                OptionChipGroup<WorkoutLocation>("Where are you training?", selection: bind(\.location))
                OptionChipGroup<FoodTiming>("Food before training", selection: bind(\.foodTiming))
                OptionChipGroup<Caffeine>("Caffeine", selection: bind(\.caffeine))

                VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                    Text("Bodyweight today (optional)")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                    WeightStepperField(weightKg: $session.bodyWeightManualKg,
                                       recentKg: bodyWeightSuggestions)
                }
            }
            .padding(.top, Theme.Spacing.s)
        }
        .font(.subheadline.weight(.semibold))
    }

    // MARK: - Helpers

    /// Bridges a typed-optional-enum accessor on the session to a `Binding`,
    /// touching the model on every write so `updatedAt` stays current.
    private func bind<T>(_ keyPath: ReferenceWritableKeyPath<WorkoutSession, T?>) -> Binding<T?> {
        Binding(
            get: { session[keyPath: keyPath] },
            set: {
                session[keyPath: keyPath] = $0
                session.touch()
            }
        )
    }

    private var bodyWeightSuggestions: [Double] {
        let stored = UserDefaults.standard.double(forKey: AppSettingsKeys.lastBodyWeightKg)
        return stored > 0 ? [stored] : []
    }

    private func persist() {
        session.touch()
        if let bw = session.bodyWeightManualKg, bw > 0 {
            UserDefaults.standard.set(bw, forKey: AppSettingsKeys.lastBodyWeightKg)
        }
        try? context.save()
    }
}

#Preview {
    let container = PersistenceController.makePreviewContainer()
    let context = container.mainContext
    let session = WorkoutSession(title: "Today")
    context.insert(session)
    try? context.save()
    return NavigationStack {
        SessionQuestionnaireView(session: session)
    }
    .modelContainer(container)
}
