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
    /// Identifies the current banner so a stale auto-dismiss cannot hide a newer one.
    @State private var prBannerToken = UUID()

    // Sheet routing
    @State private var pickerMode: PickerMode?
    @State private var setEntryTarget: Exercise?
    @State private var showFinish = false
    @State private var showQuestionnaire = false
    @State private var showDiscardConfirm = false

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
        .onAppear { savedSetCount = session.orderedSets.count }
        .onReceive(ticker) { value in
            now = value
            restTimer.tick()
        }
        .onChange(of: session.orderedSets.count) { _, newCount in
            // A newly-saved set starts the rest countdown for the default length.
            if newCount > savedSetCount {
                restTimer.start(RestTimerDefaults.defaultRestSeconds)
                celebrateIfPersonalRecord()
            }
            savedSetCount = newCount
        }
        .sensoryFeedback(.success, trigger: prHapticTrigger)
        .sheet(item: $pickerMode) { _ in
            ExercisePickerView { exercise in
                // Open set entry immediately after choosing.
                setEntryTarget = exercise
            }
        }
        .sheet(item: $setEntryTarget) { exercise in
            SetEntryView(session: session, exercise: exercise)
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

    // MARK: - Actions

    private func delete(_ set: WorkoutSet) {
        context.delete(set)
        session.touch()
        try? context.save()
    }

    private func discard() {
        context.delete(session)
        try? context.save()
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
