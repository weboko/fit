import SwiftUI
import SwiftData

/// The live workout screen for an in-progress session. Shows a running timer,
/// each exercise with its logged sets, and the primary actions: add a set, add
/// or change an exercise (shared `ExercisePickerView` sheet), and finish
/// (spec §6, §7, §14.1).
struct ActiveWorkoutView: View {
    @Bindable var session: WorkoutSession

    @Environment(\.modelContext) private var context

    /// Drives the running timer label without persisting anything.
    @State private var now = Date()
    private let ticker = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    /// In-app rest countdown, started when a set is saved.
    @State private var restTimer = RestTimerModel()
    /// Tracks the set count so we can detect a freshly-saved set.
    @State private var savedSetCount = 0

    /// Drives a brief, auto-dismissing celebration banner when the newest set
    /// sets a personal record. Empty means no banner is shown.
    @State private var prCelebrationKinds: Set<PRKind> = []
    /// Bumped each time a PR is detected so `.sensoryFeedback` fires once.
    @State private var prHapticTrigger = 0
    /// Bumped each time a set is saved so a light save haptic fires once (F5),
    /// kept separate from the F2 PR success haptic so both can coexist.
    @State private var saveHapticTrigger = 0
    /// Identifies the current banner so a stale auto-dismiss cannot hide a newer one.
    @State private var prBannerToken = UUID()

    // Sheet routing
    @State private var pickerMode: PickerMode?
    @State private var setEntryTarget: Exercise?
    @State private var showFinish = false
    @State private var showQuestionnaire = false
    @State private var showDiscardConfirm = false

    // F4: planned exercises from the template this workout was started from.
    // Strictly additive — does not touch the rest timer (F1) or PR (F2) paths.
    @State private var activeTemplate: WorkoutTemplate?
    @State private var plannedEntryTarget: PlannedSetTarget?

    private enum PickerMode: Identifiable {
        case addExercise
        var id: Int { 0 }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.l) {
                if !prCelebrationKinds.isEmpty {
                    prBanner
                }

                timerHeader

                plannedCard

                if session.exercisesInOrder.isEmpty {
                    emptyState
                } else {
                    ForEach(session.exercisesInOrder) { exercise in
                        exerciseCard(exercise)
                    }
                }

                addExerciseButton
            }
            .padding(Theme.Spacing.l)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Workout")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Menu {
                    Button {
                        showQuestionnaire = true
                    } label: {
                        Label("How are you feeling?", systemImage: "heart.text.square")
                    }
                    Button(role: .destructive) {
                        showDiscardConfirm = true
                    } label: {
                        Label("Discard workout", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .accessibilityLabel("More options")
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button("Finish") { showFinish = true }
                    .fontWeight(.semibold)
            }
        }
        .safeAreaInset(edge: .bottom) {
            if restTimer.isRunning {
                RestTimerBar(model: restTimer)
            }
        }
        .onAppear {
            savedSetCount = session.orderedSets.count
            loadActiveTemplate()
            wireRestNotifications()
        }
        .onReceive(ticker) { value in
            now = value
            restTimer.tick()
        }
        .onChange(of: session.orderedSets.count) { _, newCount in
            // A newly-saved set starts the rest countdown using the newest set's
            // per-exercise rest override (F20), falling back to the global
            // default. The F5 notification scheduling rides the same `start`
            // (via onRestStarted), so it uses the resolved duration too.
            if newCount > savedSetCount {
                saveHapticTrigger += 1
                restTimer.start(RestTimerDefaults.restSeconds(forExerciseId: newestSet?.exercise?.id))
                celebrateIfPersonalRecord()
            }
            savedSetCount = newCount
        }
        .sensoryFeedback(.success, trigger: prHapticTrigger)
        .sensoryFeedback(.impact(weight: .light), trigger: saveHapticTrigger)
        .sheet(item: $pickerMode) { _ in
            ExercisePickerView { exercise in
                // Open set entry immediately after choosing.
                setEntryTarget = exercise
            }
        }
        .sheet(item: $setEntryTarget) { exercise in
            SetEntryView(session: session, exercise: exercise)
        }
        .sheet(item: $plannedEntryTarget) { target in
            SetEntryView(session: session, exercise: target.exercise, prefill: target.prefill)
        }
        .sheet(isPresented: $showQuestionnaire) {
            NavigationStack {
                SessionQuestionnaireView(session: session)
            }
        }
        .fullScreenCover(isPresented: $showFinish) {
            FinishWorkoutView(session: session)
        }
        .confirmationDialog("Discard this workout?",
                            isPresented: $showDiscardConfirm,
                            titleVisibility: .visible) {
            Button("Discard workout", role: .destructive) { discard() }
            Button("Keep going", role: .cancel) {}
        } message: {
            Text("This permanently deletes the in-progress workout and its sets.")
        }
    }

    // MARK: - PR celebration banner

    private var prBanner: some View {
        HStack(spacing: Theme.Spacing.m) {
            Image(systemName: "trophy.fill")
                .font(.title3)
                .foregroundStyle(.yellow)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text("New personal record!")
                    .font(.subheadline.weight(.bold))
                if !prCelebrationKinds.isEmpty {
                    Text(prCelebrationSubtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: Theme.Spacing.s)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Theme.Spacing.m)
        .background(Color.yellow.opacity(0.15))
        .clipShape(RoundedRectangle(cornerRadius: Theme.Size.cornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Size.cornerRadius, style: .continuous)
                .strokeBorder(Color.yellow.opacity(0.5), lineWidth: 1)
        )
        .transition(.move(edge: .top).combined(with: .opacity))
        .accessibilityElement(children: .combine)
    }

    private var prCelebrationSubtitle: String {
        PRKind.allCases
            .filter { prCelebrationKinds.contains($0) }
            .map(\.displayName)
            .joined(separator: " · ")
    }

    // MARK: - Header

    private var timerHeader: some View {
        SectionCard {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    Text("Elapsed")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(Format.duration(elapsed))
                        .font(.system(size: 40, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .contentTransition(.numericText())
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: Theme.Spacing.xs) {
                    statBadge(value: "\(session.exercisesInOrder.count)", label: "exercises")
                    statBadge(value: "\(StatsKit.totalSets(session.orderedSets, includeWarmups: true))", label: "sets")
                }
            }
        }
    }

    private func statBadge(value: String, label: String) -> some View {
        HStack(spacing: Theme.Spacing.xs) {
            Text(value).font(.headline.weight(.bold))
            Text(label).font(.caption).foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(value) \(label)")
    }

    private var elapsed: TimeInterval {
        max(0, now.timeIntervalSince(session.startTime))
    }

    // MARK: - Exercise card

    private func exerciseCard(_ exercise: Exercise) -> some View {
        let sets = session.orderedSets.filter { $0.exercise?.id == exercise.id }
        return SectionCard {
            VStack(alignment: .leading, spacing: Theme.Spacing.m) {
                HStack {
                    Text(exercise.canonicalName)
                        .font(.headline)
                    Spacer()
                    if let lastEverHint = previousBestHint(for: exercise) {
                        Text(lastEverHint)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }

                if sets.isEmpty {
                    Text("No sets yet.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(Array(sets.enumerated()), id: \.element.id) { idx, set in
                        LoggedSetRow(set: set, indexLabel: "#\(idx + 1)")
                        if set.id != sets.last?.id {
                            Divider()
                        }
                    }
                }

                Button {
                    setEntryTarget = exercise
                } label: {
                    Label("Add set", systemImage: "plus")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity, minHeight: Theme.Size.controlHeight)
                        .background(Color.accentColor.opacity(0.15))
                        .clipShape(RoundedRectangle(cornerRadius: Theme.Size.cornerRadius, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
        .contextMenu {
            ForEach(sets) { set in
                Button(role: .destructive) {
                    delete(set)
                } label: {
                    Label("Delete \(Format.setSummary(set))", systemImage: "trash")
                }
            }
        }
    }

    private func previousBestHint(for exercise: Exercise) -> String? {
        let history = WorkoutLoggingHelpers.recentSets(for: exercise, excludingSession: session, includeWarmups: false, limit: 30)
        guard !history.isEmpty, let best = StatsKit.bestSetByWeight(history) else { return nil }
        return "Prev best " + Format.setSummary(best)
    }

    // MARK: - Buttons / empty state

    private var addExerciseButton: some View {
        Button {
            pickerMode = .addExercise
        } label: {
            Label(session.exercisesInOrder.isEmpty ? "Add first exercise" : "Add / change exercise",
                  systemImage: "plus.circle.fill")
                .font(.headline)
                .frame(maxWidth: .infinity, minHeight: Theme.Size.bigControlHeight)
        }
        .buttonStyle(.borderedProminent)
    }

    private var emptyState: some View {
        VStack(spacing: Theme.Spacing.m) {
            Image(systemName: "dumbbell")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            Text("No exercises yet")
                .font(.headline)
            Text("Add your first exercise to start logging sets.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Theme.Spacing.xl)
    }

    // MARK: - Planned (from template) — F4, strictly additive

    /// The remaining planned items for the active template, or empty if this
    /// workout was not started from one (or everything is already logged).
    private var remainingPlannedItems: [TemplateItem] {
        guard let template = activeTemplate else { return [] }
        return TemplateSupport.remainingItems(of: template, in: session)
    }

    /// The "Planned (from template)" card, shown only while planned exercises
    /// remain to be logged.
    @ViewBuilder
    private var plannedCard: some View {
        let items = remainingPlannedItems
        if let template = activeTemplate, !items.isEmpty {
            SectionCard("Planned · \(template.displayName)", systemImage: "list.bullet.rectangle.portrait") {
                VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                    Text("Tap to log a planned exercise with its target pre-filled.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    ForEach(items) { item in
                        plannedRow(item)
                        if item.id != items.last?.id { Divider() }
                    }
                }
            }
        }
    }

    private func plannedRow(_ item: TemplateItem) -> some View {
        Button {
            startPlanned(item)
        } label: {
            HStack(spacing: Theme.Spacing.m) {
                Image(systemName: "circle")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.displayName)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                    Text(item.targetSummary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: Theme.Spacing.s)
                Image(systemName: "plus.circle.fill")
                    .foregroundStyle(Color.accentColor)
                    .accessibilityHidden(true)
            }
            .contentShape(Rectangle())
            .padding(.vertical, 2)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Log planned \(item.displayName), \(item.targetSummary)")
    }

    private func loadActiveTemplate() {
        activeTemplate = TemplateSupport.activeTemplate(for: session, in: context)
    }

    /// Opens set entry for a planned item, pre-filled from its target. The
    /// planned item must resolve to a concrete exercise to log against.
    private func startPlanned(_ item: TemplateItem) {
        guard let exercise = item.exercise else { return }
        plannedEntryTarget = PlannedSetTarget(exercise: exercise, prefill: SetPrefill(item: item))
    }

    // MARK: - Rest notifications (F5, additive)

    /// Mirrors the rest-timer lifecycle into a local notification so the user is
    /// alerted when the rest ends even if the app is backgrounded. The hooks
    /// default to `nil` on `RestTimerModel`, so this wiring is purely additive
    /// and leaves the in-app F1 countdown behaviour unchanged.
    ///
    /// - start → schedule an alert for the full rest length.
    /// - ±15s (change) → reschedule for the new remaining time.
    /// - stop / skip / reaching 0 → cancel any pending alert.
    private func wireRestNotifications() {
        restTimer.onRestStarted = { seconds in
            RestNotifier.scheduleRestEnd(after: seconds)
        }
        restTimer.onRestChanged = { remaining in
            RestNotifier.scheduleRestEnd(after: remaining)
        }
        restTimer.onRestEnded = {
            RestNotifier.cancel()
        }
    }

    // MARK: - Actions

    private func delete(_ set: WorkoutSet) {
        context.delete(set)
        session.touch()
        try? context.save()
    }

    private func discard() {
        context.delete(session)
        try? context.save()
        // Drop the template link so a future workout starts clean (F4).
        TemplateSupport.clearActiveTemplate()
    }

    // MARK: - PR detection

    /// Checks whether the most recently saved set holds any personal record and,
    /// if so, fires a success haptic and shows a brief, auto-dismissing banner.
    private func celebrateIfPersonalRecord() {
        guard let newest = newestSet,
              let exercise = newest.exercise else { return }
        let kinds = PersonalRecords.kinds(for: newest, in: exercise.sets ?? [])
        guard !kinds.isEmpty else { return }

        prHapticTrigger += 1
        let token = UUID()
        prBannerToken = token
        withAnimation(.spring(duration: 0.3)) {
            prCelebrationKinds = kinds
        }

        // Auto-dismiss after a few seconds, unless a newer banner supersedes it.
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(3))
            guard prBannerToken == token else { return }
            withAnimation(.easeOut(duration: 0.25)) {
                prCelebrationKinds = []
            }
        }
    }

    /// The latest set in the session (highest setIndex, then timestamp).
    private var newestSet: WorkoutSet? {
        session.orderedSets.last
    }
}

/// Identifies a planned-exercise set-entry sheet (F4): the exercise to log and
/// the target to pre-fill it with. Kept separate from the plain `setEntryTarget`
/// so the existing add-set flow is untouched.
struct PlannedSetTarget: Identifiable {
    let exercise: Exercise
    let prefill: SetPrefill
    var id: UUID { exercise.id }
}

#Preview {
    let container = PersistenceController.makePreviewContainer()
    let context = container.mainContext
    // Build a fresh active session with a couple of sets for the preview.
    let exercises = (try? context.fetch(FetchDescriptor<Exercise>())) ?? []
    let bench = exercises.first { $0.canonicalName == "Bench Press" }
    let session = WorkoutSession(title: "Today", startTime: Date().addingTimeInterval(-25 * 60))
    context.insert(session)
    if let bench {
        let s1 = WorkoutSet(exercise: bench, exerciseNameAtTime: bench.canonicalName, setIndex: 0)
        s1.weightKg = 60; s1.reps = 8; s1.effort = 2; s1.workout = session
        let s2 = WorkoutSet(exercise: bench, exerciseNameAtTime: bench.canonicalName, setIndex: 1)
        s2.weightKg = 70; s2.reps = 6; s2.effort = 3; s2.workout = session
        context.insert(s1); context.insert(s2)
    }
    try? context.save()
    return NavigationStack {
        ActiveWorkoutView(session: session)
    }
    .modelContainer(container)
}
