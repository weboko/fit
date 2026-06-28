import SwiftUI
import SwiftData

/// First-run onboarding (F15). A short, paged explainer shown exactly once,
/// gated by `AppSettingsKeys.hasOnboarded` from `ContentView`. It covers the
/// app's purpose, its privacy stance, the weight unit, an optional Apple Health
/// connection and an optional starter-exercise top-up — none of which block
/// finishing. Everything here can also be changed later in Settings.
///
/// Storage stays in kg; `weightUnit` is persisted as the `WeightUnit` rawValue
/// to match the rest of the app. Starter exercises are only added from here when
/// the library happens to be empty, so we never duplicate the first-launch seed.
struct OnboardingView: View {
    @Environment(\.modelContext) private var context

    /// Called when the user finishes or skips. The caller flips
    /// `hasOnboarded = true` and dismisses the cover.
    let onFinish: () -> Void

    /// Weight display unit. Stored as the `WeightUnit` rawValue ("kg"/"lb").
    @AppStorage(AppSettingsKeys.weightUnit) private var weightUnitRaw: String = WeightUnit.kg.rawValue

    @State private var step: Step = .welcome
    @StateObject private var health = HealthImportService()
    @State private var didAddStarters = false

    private enum Step: Int, CaseIterable, Identifiable {
        case welcome
        case privacy
        case units
        case health
        case starters

        var id: Int { rawValue }
    }

    /// On devices without Health the Health step is skipped entirely.
    private var steps: [Step] {
        Step.allCases.filter { $0 != .health || HealthImportService.isAvailable }
    }

    private var isLastStep: Bool { step == steps.last }

    private var selectedUnit: Binding<WeightUnit> {
        Binding(
            get: { WeightUnit(rawValue: weightUnitRaw) ?? .kg },
            set: { weightUnitRaw = $0.rawValue }
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            header

            TabView(selection: $step) {
                ForEach(steps) { current in
                    ScrollView {
                        page(for: current)
                            .padding(Theme.Spacing.l)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .tag(current)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .indexViewStyle(.page(backgroundDisplayMode: .always))

            footer
        }
        .background(Color(.systemGroupedBackground))
    }

    // MARK: - Chrome

    private var header: some View {
        HStack {
            Spacer()
            if !isLastStep {
                Button("Skip", action: finish)
                    .font(.body.weight(.medium))
            }
        }
        .frame(height: Theme.Size.controlHeight)
        .padding(.horizontal, Theme.Spacing.l)
    }

    private var footer: some View {
        VStack(spacing: Theme.Spacing.s) {
            Button(action: advance) {
                Text(isLastStep ? "Get started" : "Continue")
                    .font(.headline)
                    .frame(maxWidth: .infinity, minHeight: Theme.Size.bigControlHeight)
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(Theme.Spacing.l)
    }

    // MARK: - Pages

    @ViewBuilder
    private func page(for step: Step) -> some View {
        switch step {
        case .welcome: welcomePage
        case .privacy: privacyPage
        case .units: unitsPage
        case .health: healthPage
        case .starters: startersPage
        }
    }

    private var welcomePage: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.l) {
            stepIcon("figure.strengthtraining.traditional")
            Text("Welcome to Fit")
                .font(.largeTitle.weight(.bold))
            Text("A private strength logger. Capture sets fast in the gym, then export clean data whenever you want.")
                .font(.title3)
                .foregroundStyle(.secondary)
        }
    }

    private var privacyPage: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.l) {
            stepIcon("lock.shield")
            Text("Private by design")
                .font(.largeTitle.weight(.bold))
            VStack(alignment: .leading, spacing: Theme.Spacing.m) {
                privacyRow("iphone", "Local-first", "Your data lives on your device.")
                privacyRow("icloud", "iCloud sync", "Synced privately across your devices via iCloud.")
                privacyRow("person.crop.circle.badge.xmark", "No accounts", "No sign-up, no servers, no backend.")
                privacyRow("eye.slash", "No tracking", "No analytics, no ads, no AI.")
                privacyRow("heart.text.square", "Health is read-only", "Fit never writes to Apple Health.")
            }
        }
    }

    private var unitsPage: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.l) {
            stepIcon("scalemass")
            Text("Weight units")
                .font(.largeTitle.weight(.bold))
            Text("Pick how weights are shown. Everything is stored and exported in kilograms either way.")
                .font(.title3)
                .foregroundStyle(.secondary)
            Picker("Weight unit", selection: selectedUnit) {
                ForEach(WeightUnit.allCases) { unit in
                    Text(unit.displayName).tag(unit)
                }
            }
            .pickerStyle(.segmented)
            .frame(minHeight: Theme.Size.controlHeight)
            Text("You can change this anytime in Settings.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private var healthPage: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.l) {
            stepIcon("heart.text.square")
            Text("Apple Health")
                .font(.largeTitle.weight(.bold))
            Text("Optionally import your workouts, body weight and sleep. Fit only reads from Health — it never writes back.")
                .font(.title3)
                .foregroundStyle(.secondary)

            if health.authorizationStatus == .notDetermined {
                Button {
                    Task { await health.requestAuthorization() }
                } label: {
                    Label("Connect Apple Health", systemImage: "heart.text.square")
                        .font(.headline)
                        .frame(maxWidth: .infinity, minHeight: Theme.Size.controlHeight)
                }
                .buttonStyle(.bordered)
                .disabled(health.isWorking)
            } else {
                Label("Health connected", systemImage: "checkmark.circle.fill")
                    .font(.headline)
                    .foregroundStyle(.green)
                    .frame(maxWidth: .infinity, minHeight: Theme.Size.controlHeight)
            }

            Text("You can skip this and connect later in Settings.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .onAppear { health.refreshAuthorizationStatus() }
    }

    private var startersPage: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.l) {
            stepIcon("dumbbell")
            Text("Starter exercises")
                .font(.largeTitle.weight(.bold))
            Text("Begin with a curated set of common lifts, or start empty and add your own. Either way you can add, edit and merge exercises anytime.")
                .font(.title3)
                .foregroundStyle(.secondary)

            if didAddStarters {
                Label("Starter exercises added", systemImage: "checkmark.circle.fill")
                    .font(.headline)
                    .foregroundStyle(.green)
                    .frame(maxWidth: .infinity, minHeight: Theme.Size.controlHeight)
            } else if libraryIsEmpty {
                Button(action: addStarters) {
                    Label("Add starter exercises", systemImage: "plus.circle")
                        .font(.headline)
                        .frame(maxWidth: .infinity, minHeight: Theme.Size.controlHeight)
                }
                .buttonStyle(.bordered)
            } else {
                Label("Your library is ready to go", systemImage: "checkmark.circle.fill")
                    .font(.headline)
                    .foregroundStyle(.green)
                    .frame(maxWidth: .infinity, minHeight: Theme.Size.controlHeight)
            }
        }
    }

    // MARK: - Building blocks

    private func stepIcon(_ systemImage: String) -> some View {
        Image(systemName: systemImage)
            .font(.system(size: 52, weight: .semibold))
            .foregroundStyle(Theme.Palette.accent)
            .padding(.top, Theme.Spacing.l)
    }

    private func privacyRow(_ systemImage: String, _ title: String, _ detail: String) -> some View {
        HStack(alignment: .top, spacing: Theme.Spacing.m) {
            Image(systemName: systemImage)
                .font(.title3)
                .foregroundStyle(Theme.Palette.accent)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Text(title).font(.headline)
                Text(detail).font(.subheadline).foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Actions

    /// Only offer/perform the starter add when nothing has been seeded yet, so
    /// we never duplicate the first-launch seed performed by `SeedData`.
    private var libraryIsEmpty: Bool {
        let count = (try? context.fetchCount(FetchDescriptor<Exercise>())) ?? 0
        return count == 0
    }

    private func addStarters() {
        guard libraryIsEmpty else { return }
        SeedData.addStarterExercises(to: context)
        try? context.save()
        didAddStarters = true
    }

    private func advance() {
        guard let index = steps.firstIndex(of: step) else { finish(); return }
        let next = index + 1
        if next < steps.count {
            withAnimation { step = steps[next] }
        } else {
            finish()
        }
    }

    private func finish() {
        onFinish()
    }
}

#Preview {
    OnboardingView(onFinish: {})
        .modelContainer(PersistenceController.makePreviewContainer())
}
