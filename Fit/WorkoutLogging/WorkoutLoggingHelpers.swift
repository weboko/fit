import Foundation
import SwiftUI
import SwiftData

// MARK: - Active session helpers

/// Shared logic for the WorkoutLogging module: finding/starting the active
/// session, deriving per-exercise history, and pre-filling the next set.
///
/// All functions are deterministic and side-effect-free unless they explicitly
/// take a `ModelContext`. No AI, no network.
enum WorkoutLoggingHelpers {

    /// The single in-progress session (endTime == nil), if any. If multiple
    /// exist (should not happen) the most recently started wins.
    static func activeSession(in sessions: [WorkoutSession]) -> WorkoutSession? {
        sessions.filter { $0.endTime == nil }
            .max { $0.startTime < $1.startTime }
    }

    /// Creates and inserts a fresh active session.
    @discardableResult
    static func startSession(in context: ModelContext, startTime: Date = Date()) -> WorkoutSession {
        let session = WorkoutSession(startTime: startTime)
        context.insert(session)
        try? context.save()
        return session
    }

    /// Finishes the session: stamps endTime and saves.
    static func finishSession(_ session: WorkoutSession, in context: ModelContext, endTime: Date = Date()) {
        session.endTime = endTime
        session.touch()
        try? context.save()
    }

    /// Discards an empty (no sets) active session entirely, or just leaves a
    /// non-empty one untouched. Returns true if it was deleted.
    @discardableResult
    static func discardSessionIfEmpty(_ session: WorkoutSession, in context: ModelContext) -> Bool {
        guard (session.sets ?? []).isEmpty else { return false }
        context.delete(session)
        try? context.save()
        return true
    }

    // MARK: - Per-exercise history & suggestions

    /// Recent sets for an exercise across all sessions, newest first, optionally
    /// excluding warm-ups and optionally a particular session.
    static func recentSets(
        for exercise: Exercise,
        excludingSession session: WorkoutSession? = nil,
        includeWarmups: Bool = true,
        limit: Int = 12
    ) -> [WorkoutSet] {
        (exercise.sets ?? [])
            .filter { set in
                if !includeWarmups, set.isWarmup { return false }
                if let session, set.workout?.id == session.id { return false }
                return true
            }
            .sorted { $0.timestamp > $1.timestamp }
            .prefix(limit)
            .map { $0 }
    }

    /// Recent distinct external/effective loads (kg) for an exercise, newest
    /// first — used to feed `WeightStepperField.recentKg`.
    static func recentLoadsKg(for exercise: Exercise, limit: Int = 8) -> [Double] {
        var seen = Set<Double>()
        var result: [Double] = []
        for set in recentSets(for: exercise, limit: 40) {
            let load: Double?
            switch set.weightMode {
            case .external: load = set.weightKg
            case .addedBodyweight: load = set.addedWeightKg
            case .assistedBodyweight: load = set.assistanceKg
            case .bodyweight: load = set.bodyWeightKg
            case .unknown: load = set.weightKg ?? set.bodyWeightKg
            }
            guard let load, load > 0 else { continue }
            if seen.insert(load).inserted {
                result.append(load)
            }
            if result.count >= limit { break }
        }
        return result
    }

    /// The most recent set logged for an exercise anywhere — the basis for
    /// pre-filling the next set's weight/reps/mode. Prefers working sets for the
    /// suggestion, falling back to any set (including warm-ups).
    static func lastSet(for exercise: Exercise, excludingSession session: WorkoutSession? = nil) -> WorkoutSet? {
        let recent = recentSets(for: exercise, excludingSession: session)
        return recent.first { !$0.isWarmup } ?? recent.first
    }

    /// The last set within the current session for an exercise (used to chain
    /// set indices and reuse bodyweight within the same workout).
    static func lastSetInSession(_ session: WorkoutSession, exercise: Exercise) -> WorkoutSet? {
        session.orderedSets
            .filter { $0.exercise?.id == exercise.id }
            .max { $0.setIndex < $1.setIndex }
    }

    /// The next `setIndex` to use when appending a set to a session. Indices are
    /// session-global (monotonic) to keep ordering stable across exercises.
    static func nextSetIndex(in session: WorkoutSession) -> Int {
        (session.orderedSets.map(\.setIndex).max() ?? -1) + 1
    }

    /// How many working/total sets of an exercise are already logged in the
    /// session (for display like "Set 3").
    static func setNumber(for exercise: Exercise, in session: WorkoutSession) -> Int {
        session.orderedSets.filter { $0.exercise?.id == exercise.id }.count + 1
    }

    // MARK: - Top sets summary (for the finish screen)

    /// The best working set (by effective load, then reps) for each exercise in
    /// the session, in exercise order. Used by the finish summary.
    static func topSets(in session: WorkoutSession) -> [(exercise: Exercise, set: WorkoutSet)] {
        var result: [(Exercise, WorkoutSet)] = []
        for exercise in session.exercisesInOrder {
            let sets = session.orderedSets.filter { $0.exercise?.id == exercise.id }
            if let best = StatsKit.bestSetByWeight(sets) ?? StatsKit.bestRepsSet(sets) {
                result.append((exercise, best))
            }
        }
        return result
    }
}

// MARK: - Suggestion model for pre-filling a new set

/// A lightweight, copyable snapshot of "what the next set probably looks like",
/// derived from the most recent matching set. All optional so an unknown field
/// simply stays empty.
struct SetSuggestion {
    var weightMode: WeightMode
    var weightKg: Double?
    var addedWeightKg: Double?
    var assistanceKg: Double?
    var bodyWeightKg: Double?
    var reps: Int?

    /// Builds a suggestion from a previous set (typically `lastSet`). Carries the
    /// load fields appropriate to the weight mode.
    init(from set: WorkoutSet) {
        self.weightMode = set.weightMode
        self.weightKg = set.weightKg
        self.addedWeightKg = set.addedWeightKg
        self.assistanceKg = set.assistanceKg
        self.bodyWeightKg = set.bodyWeightKg
        self.reps = set.reps
    }

    /// A default suggestion when there is no history, based on the exercise's
    /// configured default weight mode (and last known bodyweight if any).
    init(forNewExercise exercise: Exercise, lastBodyWeightKg: Double?) {
        self.weightMode = exercise.defaultWeightMode
        self.weightKg = nil
        self.addedWeightKg = nil
        self.assistanceKg = nil
        self.bodyWeightKg = lastBodyWeightKg
        self.reps = nil
    }
}

// MARK: - Small reusable rows for logged sets

/// One logged set rendered as a tappable row (load × reps + effort dot + flags).
struct LoggedSetRow: View {
    let set: WorkoutSet
    var indexLabel: String?

    var body: some View {
        HStack(spacing: Theme.Spacing.m) {
            if let indexLabel {
                Text(indexLabel)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 28, alignment: .leading)
            }
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: Theme.Spacing.s) {
                    Text(Format.setSummary(set))
                        .font(.body.weight(.medium))
                    if set.isWarmup {
                        Text("warm-up")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    if set.isFailed {
                        Text("failed")
                            .font(.caption2)
                            .foregroundStyle(.red)
                    }
                }
                if let detail = subdetail {
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: Theme.Spacing.s)
            if let effort = set.effort {
                effortDot(effort)
            }
        }
        .contentShape(Rectangle())
    }

    private var subdetail: String? {
        var parts: [String] = []
        if let effort = set.effort {
            parts.append(EffortScale.shortLabel(for: effort))
        }
        if let form = set.formQuality, form != .unknown {
            parts.append(form.displayName)
        }
        if let limiter = set.limiter, limiter != .none, limiter != .unknown {
            parts.append(limiter.displayName)
        }
        if let pain = set.painSeverity, pain != .none {
            let loc = set.painLocation.map { " (\($0.displayName))" } ?? ""
            parts.append("Pain: \(pain.displayName)\(loc)")
        }
        let trimmedNote = set.notes.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedNote.isEmpty {
            parts.append("“\(trimmedNote)”")
        }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    private func effortDot(_ value: Int) -> some View {
        Text("\(value)")
            .font(.caption.weight(.bold))
            .foregroundStyle(.white)
            .frame(width: 26, height: 26)
            .background(Theme.Palette.intensity(value))
            .clipShape(Circle())
    }
}

/// A compact one-line summary of an exercise's recent history, e.g.
/// "Last: 80 kg × 6 · Today".
struct RecentSetHistoryRow: View {
    let set: WorkoutSet

    var body: some View {
        HStack {
            Text(Format.setSummary(set))
                .font(.subheadline.weight(.medium))
            if let effort = set.effort {
                Text("· \(EffortScale.shortLabel(for: effort))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(relativeDate)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var relativeDate: String {
        let date = set.workout?.startTime ?? set.timestamp
        return Format.relativeDay(date)
    }
}
