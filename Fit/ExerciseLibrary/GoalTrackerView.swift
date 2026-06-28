import SwiftUI
import SwiftData

/// Per-exercise progress targets, stored in `UserDefaults` keyed by the
/// exercise id. We deliberately avoid adding fields to the SwiftData model:
/// targets are a lightweight UI preference, not part of the logged training
/// record. A weighted exercise tracks a kg target; a bodyweight-mode exercise
/// tracks a reps target (spec §17). Everything here is deterministic — no AI.
enum GoalTargets {

    private static let kgPrefix = "fit.goal.targetKg."
    private static let repsPrefix = "fit.goal.targetReps."

    /// Which metric a goal exercise is judged against, derived purely from its
    /// default weight mode: bodyweight goals progress by reps, everything else
    /// progresses by load (kg).
    enum Metric {
        case kg
        case reps
    }

    static func metric(for exercise: Exercise) -> Metric {
        exercise.defaultWeightMode == .bodyweight ? .reps : .kg
    }

    /// A sensible starting suggestion when the user hasn't set a target yet,
    /// in the goal's own metric. 100 kg for the classic bench-style goal, 10
    /// reps for bodyweight goals.
    static func defaultTarget(for exercise: Exercise) -> Double {
        metric(for: exercise) == .kg ? 100 : 10
    }

    // MARK: - kg targets

    static func targetKg(for exercise: Exercise) -> Double? {
        let key = kgPrefix + exercise.id.uuidString
        guard UserDefaults.standard.object(forKey: key) != nil else { return nil }
        let value = UserDefaults.standard.double(forKey: key)
        return value > 0 ? value : nil
    }

    static func setTargetKg(_ value: Double?, for exercise: Exercise) {
        let key = kgPrefix + exercise.id.uuidString
        if let value, value > 0 {
            UserDefaults.standard.set(value, forKey: key)
        } else {
            UserDefaults.standard.removeObject(forKey: key)
        }
    }

    // MARK: - reps targets

    static func targetReps(for exercise: Exercise) -> Int? {
        let key = repsPrefix + exercise.id.uuidString
        guard UserDefaults.standard.object(forKey: key) != nil else { return nil }
        let value = UserDefaults.standard.integer(forKey: key)
        return value > 0 ? value : nil
    }

    static func setTargetReps(_ value: Int?, for exercise: Exercise) {
        let key = repsPrefix + exercise.id.uuidString
        if let value, value > 0 {
            UserDefaults.standard.set(value, forKey: key)
        } else {
            UserDefaults.standard.removeObject(forKey: key)
        }
    }

    // MARK: - Resolved target (with default fallback)

    /// The effective target in the goal's metric: the stored value if present,
    /// otherwise the default suggestion.
    static func resolvedTarget(for exercise: Exercise) -> Double {
        switch metric(for: exercise) {
        case .kg:
            return targetKg(for: exercise) ?? defaultTarget(for: exercise)
        case .reps:
            return Double(targetReps(for: exercise) ?? Int(defaultTarget(for: exercise)))
        }
    }
}

/// Tiny deterministic facade over goal progress for callers outside this file
/// (e.g. the Today screen teaser) that just need a fraction and a one-liner,
/// without rebuilding the progress maths.
enum GoalTeaser {
    /// Progress toward the goal's target, clamped 0...1.
    static func fraction(for exercise: Exercise) -> Double {
        GoalProgress(exercise: exercise).fraction
    }

    /// A compact "best → target" summary, e.g. "80 kg / 100 kg" or "6 / 10 reps".
    static func summary(for exercise: Exercise) -> String {
        let progress = GoalProgress(exercise: exercise)
        switch progress.metric {
        case .kg:
            let best = progress.best.map { Format.weight($0) } ?? "—"
            return "\(best) / \(Format.weight(progress.target))"
        case .reps:
            let best = progress.best.map { "\(Int($0))" } ?? "—"
            return "\(best) / \(Int(progress.target)) reps"
        }
    }
}

/// Read-only goal progress facts for one exercise, computed deterministically
/// from its logged sets and stored target (StatsKit + GoalTargets). No
/// recommendations — just "best so far vs target".
private struct GoalProgress {
    let exercise: Exercise
    let metric: GoalTargets.Metric
    let target: Double
    /// The best value achieved so far, in the goal's metric (kg or reps).
    let best: Double?
    /// The set that produced `best`, for a friendly summary line.
    let bestSet: WorkoutSet?

    init(exercise: Exercise) {
        self.exercise = exercise
        let sets = exercise.orderedSets
        let metric = GoalTargets.metric(for: exercise)
        self.metric = metric
        self.target = GoalTargets.resolvedTarget(for: exercise)
        switch metric {
        case .kg:
            let best = StatsKit.bestSetByWeight(sets)
            self.bestSet = best
            self.best = best?.effectiveLoadKg
        case .reps:
            let best = StatsKit.bestRepsSet(sets)
            self.bestSet = best
            self.best = best?.reps.map(Double.init)
        }
    }

    /// Progress fraction clamped to 0...1, or 0 when there's no data yet.
    var fraction: Double {
        guard target > 0, let best else { return 0 }
        return min(1, max(0, best / target))
    }

    var percent: Int { Int((fraction * 100).rounded()) }

    var reachedTarget: Bool {
        guard let best else { return false }
        return best >= target
    }

    /// How far is left to the target, in the goal's metric. Nil when reached or
    /// when there's nothing logged yet.
    var remaining: Double? {
        guard let best, best < target else { return nil }
        return target - best
    }
}

/// A dedicated screen surfacing the user's goal exercises (those marked
/// `isGoalExercise`) and how close they are to a configurable target — e.g.
/// Bench Press → 100 kg, Pull-up → 10 reps (spec §17). Deterministic only:
/// best set so far, recent working weights, an est-1RM / reps trend, and a
/// distance-to-target bar. No coaching, no recommendations.
struct GoalTrackerView: View {
    @Query(sort: \Exercise.canonicalName, order: .forward)
    private var allExercises: [Exercise]

    /// Active goal exercises only, filtered in memory (mirrors the library,
    /// where `#Predicate` can't reach computed helpers).
    private var goalExercises: [Exercise] {
        allExercises.filter { $0.isGoalExercise && !$0.archived }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.l) {
                if goalExercises.isEmpty {
                    emptyState
                } else {
                    ForEach(goalExercises) { exercise in
                        GoalCard(exercise: exercise)
                    }
                }
            }
            .padding(Theme.Spacing.l)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Goals")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var emptyState: some View {
        EmptyStateView(
            title: "No goal exercises yet",
            message: "Open an exercise and turn on \"Goal exercise\" to track your progress toward a target here, like benching 100 kg or 10 pull-ups.",
            systemImage: "target"
        )
        .padding(.vertical, Theme.Spacing.xl)
    }
}

/// One goal exercise's progress card: current best, an editable target with a
/// distance-to-target bar, recent working weights, and a trend chart.
private struct GoalCard: View {
    let exercise: Exercise

    /// Local mirrors of the persisted targets so the steppers feel live; saved
    /// to `GoalTargets` on change.
    @State private var targetKg: Double?
    @State private var targetReps: Int?

    init(exercise: Exercise) {
        self.exercise = exercise
        _targetKg = State(initialValue: GoalTargets.targetKg(for: exercise)
            ?? GoalTargets.defaultTarget(for: exercise))
        _targetReps = State(initialValue: GoalTargets.targetReps(for: exercise)
            ?? Int(GoalTargets.defaultTarget(for: exercise)))
    }

    private var progress: GoalProgress { GoalProgress(exercise: exercise) }

    /// Last few non-warmup sets, newest first.
    private var recentWorkingSets: [WorkoutSet] {
        Array(exercise.orderedSets.filter { !$0.isWarmup }.prefix(5))
    }

    var body: some View {
        SectionCard(exercise.canonicalName.isEmpty ? "Goal" : exercise.canonicalName,
                    systemImage: "target") {
            currentBest
            Divider()
            targetEditor
            progressBar
            if !recentWorkingSets.isEmpty {
                Divider()
                recentWeights
            }
            Divider()
            trendChart
        }
    }

    // MARK: - Current best

    @ViewBuilder
    private var currentBest: some View {
        switch progress.metric {
        case .kg:
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())],
                      spacing: Theme.Spacing.m) {
                StatTile(value: bestLoadText, label: "Best set", systemImage: "scalemass")
                StatTile(value: oneRepMaxText, label: "Est. 1RM", systemImage: "arrow.up.right")
            }
        case .reps:
            StatTile(value: bestRepsText, label: "Most reps", systemImage: "repeat")
        }
    }

    private var bestLoadText: String {
        guard let set = progress.bestSet else { return "—" }
        return Format.setSummary(set)
    }

    private var oneRepMaxText: String {
        guard let value = StatsKit.bestEstimatedOneRepMaxKg(exercise.orderedSets) else { return "—" }
        return Format.weight(value)
    }

    private var bestRepsText: String {
        guard let reps = progress.bestSet?.reps else { return "—" }
        return "\(reps)"
    }

    // MARK: - Target editor

    @ViewBuilder
    private var targetEditor: some View {
        switch progress.metric {
        case .kg:
            VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                Label("Target", systemImage: "flag.checkered")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                WeightStepperField(weightKg: $targetKg)
                    .onChange(of: targetKg) { _, new in
                        GoalTargets.setTargetKg(new, for: exercise)
                    }
            }
        case .reps:
            VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                Label("Target reps", systemImage: "flag.checkered")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                RepsStepperField(reps: $targetReps, quickValues: [5, 8, 10, 12, 15, 20])
                    .onChange(of: targetReps) { _, new in
                        GoalTargets.setTargetReps(new, for: exercise)
                    }
            }
        }
    }

    // MARK: - Progress bar

    private var progressBar: some View {
        let progress = self.progress
        return VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            ProgressView(value: progress.fraction)
                .tint(progress.reachedTarget ? .green : .accentColor)
            HStack {
                Text("\(progress.percent)% of \(targetSummary(progress))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(distanceText(progress))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(progress.reachedTarget ? .green : .secondary)
            }
        }
    }

    private func targetSummary(_ progress: GoalProgress) -> String {
        switch progress.metric {
        case .kg: return Format.weight(progress.target)
        case .reps: return "\(Int(progress.target)) reps"
        }
    }

    private func distanceText(_ progress: GoalProgress) -> String {
        guard let remaining = progress.remaining else {
            return progress.best == nil ? "No data yet" : "Reached"
        }
        switch progress.metric {
        case .kg:
            return "\(Format.weight(remaining)) to go"
        case .reps:
            let reps = Int(remaining.rounded())
            return "\(reps) rep\(reps == 1 ? "" : "s") to go"
        }
    }

    // MARK: - Recent working weights

    private var recentWeights: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            Label("Recent working sets", systemImage: "clock.arrow.circlepath")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
            FlowLayout {
                ForEach(recentWorkingSets) { set in
                    Text(Format.setSummary(set))
                        .font(.subheadline)
                        .padding(.horizontal, Theme.Spacing.m)
                        .padding(.vertical, Theme.Spacing.s)
                        .background(Theme.Palette.subtle)
                        .clipShape(Capsule())
                }
            }
        }
    }

    // MARK: - Trend chart

    private var trendChart: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            Label(progress.metric == .kg ? "Est. 1RM per session" : "Best reps per session",
                  systemImage: "chart.xyaxis.line")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
            MetricLineChart(points: trendPoints, unitSuffix: trendSuffix)
        }
    }

    private var trendPoints: [StatsKit.SessionPoint] {
        switch progress.metric {
        case .kg:
            return StatsKit.estimatedOneRepMaxPerSession(exercise.orderedSets)
        case .reps:
            return bestRepsPerSession(exercise.orderedSets)
        }
    }

    private var trendSuffix: String {
        progress.metric == .kg ? " \(Format.weightUnit.symbol)" : ""
    }

    /// One point per session: the most reps achieved in any working set that
    /// session. Built inline because StatsKit has no reps-series helper.
    private func bestRepsPerSession(_ sets: [WorkoutSet]) -> [StatsKit.SessionPoint] {
        let working = sets.filter { !$0.isWarmup }
        let grouped = Dictionary(grouping: working) { set in
            set.workout?.id ?? set.id
        }
        var points: [StatsKit.SessionPoint] = []
        for (_, group) in grouped {
            guard let reps = group.compactMap(\.reps).max(),
                  let date = group.compactMap({ $0.workout?.startTime ?? $0.timestamp }).min()
            else { continue }
            points.append(StatsKit.SessionPoint(date: date, value: Double(reps)))
        }
        return points.sorted { $0.date < $1.date }
    }
}

#Preview {
    NavigationStack {
        GoalTrackerView()
    }
    .modelContainer(PersistenceController.makePreviewContainer())
}
