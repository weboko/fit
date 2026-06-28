import Foundation

/// The kinds of personal record we recognise. Deterministic and metric-based:
/// heaviest effective load, most reps in a set, and best estimated 1RM. No AI,
/// no coaching — just arithmetic over a single exercise's history (spec §15).
enum PRKind: String, CaseIterable, Identifiable {
    case load
    case reps
    case estimatedOneRepMax

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .load: return "Heaviest"
        case .reps: return "Most reps"
        case .estimatedOneRepMax: return "Best est. 1RM"
        }
    }

    /// SF Symbol used to mark the specific record kind.
    var systemImage: String {
        switch self {
        case .load: return "scalemass"
        case .reps: return "repeat"
        case .estimatedOneRepMax: return "arrow.up.right"
        }
    }
}

/// Pure, deterministic personal-record detection over a single exercise's sets.
///
/// "Record-at-the-time" means a set is judged only against the OTHER non-warmup
/// sets of the SAME exercise that happened strictly BEFORE it. A value counts as
/// a record when it strictly exceeds every earlier value of that kind (so the
/// first set that ever produces a value for a kind is itself a record). Warm-ups
/// never count, and missing/nil values are skipped rather than treated as zero.
enum PersonalRecords {

    /// Which records `set` holds relative to earlier sets of the same exercise.
    ///
    /// - Parameters:
    ///   - set: The set under test.
    ///   - exerciseSets: All sets of the same exercise (warm-ups and later sets
    ///     are filtered out here, so callers can pass the full relationship).
    /// - Returns: The set of `PRKind`s this set held at the moment it was logged.
    static func kinds(for set: WorkoutSet, in exerciseSets: [WorkoutSet]) -> Set<PRKind> {
        guard !set.isWarmup else { return [] }

        // Earlier working sets only — strictly before this set's timestamp. Ties
        // on timestamp are broken by id so a set never compares against itself.
        let earlier = exerciseSets.filter { other in
            guard !other.isWarmup, other.id != set.id else { return false }
            if other.timestamp != set.timestamp { return other.timestamp < set.timestamp }
            return other.id.uuidString < set.id.uuidString
        }

        var result: Set<PRKind> = []

        if let load = set.effectiveLoadKg {
            let earlierMax = earlier.compactMap(\.effectiveLoadKg).max()
            if earlierMax == nil || load > earlierMax! { result.insert(.load) }
        }

        if let reps = set.reps {
            let earlierMax = earlier.compactMap(\.reps).max()
            if earlierMax == nil || reps > earlierMax! { result.insert(.reps) }
        }

        if let oneRM = set.estimatedOneRepMaxKg {
            let earlierMax = earlier.compactMap(\.estimatedOneRepMaxKg).max()
            if earlierMax == nil || oneRM > earlierMax! { result.insert(.estimatedOneRepMax) }
        }

        return result
    }

    /// The all-time best set per kind across the exercise's sets, for the
    /// exercise-detail summary. Warm-ups are ignored. A kind is omitted when no
    /// set has data for it.
    static func current(for exercise: Exercise) -> [PRKind: WorkoutSet] {
        let working = (exercise.sets ?? []).filter { !$0.isWarmup }
        var result: [PRKind: WorkoutSet] = [:]

        if let bestLoad = working
            .filter({ $0.effectiveLoadKg != nil })
            .max(by: { ($0.effectiveLoadKg ?? 0) < ($1.effectiveLoadKg ?? 0) }) {
            result[.load] = bestLoad
        }

        if let bestReps = working
            .filter({ $0.reps != nil })
            .max(by: { ($0.reps ?? 0) < ($1.reps ?? 0) }) {
            result[.reps] = bestReps
        }

        if let bestOneRM = working
            .filter({ $0.estimatedOneRepMaxKg != nil })
            .max(by: { ($0.estimatedOneRepMaxKg ?? 0) < ($1.estimatedOneRepMaxKg ?? 0) }) {
            result[.estimatedOneRepMax] = bestOneRM
        }

        return result
    }
}
