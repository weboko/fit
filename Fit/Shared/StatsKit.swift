import Foundation

/// Pure, deterministic statistics over sets and workouts. No AI, no
/// recommendations — just arithmetic (spec §15). Shared by the exercise
/// library, history and goal screens.
enum StatsKit {

    // MARK: - Totals

    static func totalSets(_ sets: [WorkoutSet], includeWarmups: Bool = false) -> Int {
        sets.filter { includeWarmups || !$0.isWarmup }.count
    }

    static func totalReps(_ sets: [WorkoutSet], includeWarmups: Bool = false) -> Int {
        sets.filter { includeWarmups || !$0.isWarmup }
            .reduce(0) { $0 + ($1.reps ?? 0) }
    }

    static func totalVolumeKg(_ sets: [WorkoutSet], includeWarmups: Bool = false) -> Double {
        sets.filter { includeWarmups || !$0.isWarmup }
            .reduce(0) { $0 + ($1.volumeKg ?? 0) }
    }

    // MARK: - Bests (per exercise)

    /// The set with the highest external/effective load (ties broken by reps).
    static func bestSetByWeight(_ sets: [WorkoutSet]) -> WorkoutSet? {
        sets.filter { !$0.isWarmup && $0.effectiveLoadKg != nil }
            .max {
                let l = ($0.effectiveLoadKg ?? 0, Double($0.reps ?? 0))
                let r = ($1.effectiveLoadKg ?? 0, Double($1.reps ?? 0))
                return l < r
            }
    }

    /// Highest reps in a single set (useful for bodyweight progress).
    static func bestRepsSet(_ sets: [WorkoutSet]) -> WorkoutSet? {
        sets.filter { !$0.isWarmup && $0.reps != nil }
            .max { ($0.reps ?? 0) < ($1.reps ?? 0) }
    }

    static func bestEstimatedOneRepMaxKg(_ sets: [WorkoutSet]) -> Double? {
        sets.compactMap(\.estimatedOneRepMaxKg).max()
    }

    // MARK: - Muscle group breakdowns (for hypertrophy tracking, spec §18)

    /// Counts working sets attributed to each primary muscle group of the
    /// exercise. A set with multiple primary muscles contributes to each.
    static func setsByMuscleGroup(_ sets: [WorkoutSet]) -> [MuscleGroup: Int] {
        var result: [MuscleGroup: Int] = [:]
        for set in sets where !set.isWarmup {
            for muscle in set.exercise?.primaryMuscles ?? [] {
                result[muscle, default: 0] += 1
            }
        }
        return result
    }

    static func volumeByMuscleGroup(_ sets: [WorkoutSet]) -> [MuscleGroup: Double] {
        var result: [MuscleGroup: Double] = [:]
        for set in sets where !set.isWarmup {
            guard let volume = set.volumeKg else { continue }
            for muscle in set.exercise?.primaryMuscles ?? [] {
                result[muscle, default: 0] += volume
            }
        }
        return result
    }

    // MARK: - Time series (for simple charts)

    struct SessionPoint: Identifiable {
        let id = UUID()
        let date: Date
        let value: Double
    }

    /// One point per session: the best effective load achieved in that session
    /// for the given sets (already filtered to one exercise).
    static func bestLoadPerSession(_ sets: [WorkoutSet]) -> [SessionPoint] {
        seriesPerSession(sets) { group in
            group.compactMap(\.effectiveLoadKg).max()
        }
    }

    /// One point per session: total volume for the given sets.
    static func volumePerSession(_ sets: [WorkoutSet]) -> [SessionPoint] {
        seriesPerSession(sets) { group in
            let v = group.reduce(0.0) { $0 + ($1.volumeKg ?? 0) }
            return v > 0 ? v : nil
        }
    }

    /// One point per session: best estimated 1RM.
    static func estimatedOneRepMaxPerSession(_ sets: [WorkoutSet]) -> [SessionPoint] {
        seriesPerSession(sets) { group in
            group.compactMap(\.estimatedOneRepMaxKg).max()
        }
    }

    private static func seriesPerSession(
        _ sets: [WorkoutSet],
        reduce: ([WorkoutSet]) -> Double?
    ) -> [SessionPoint] {
        let working = sets.filter { !$0.isWarmup }
        let grouped = Dictionary(grouping: working) { set in
            set.workout?.id ?? set.id
        }
        var points: [SessionPoint] = []
        for (_, group) in grouped {
            guard let value = reduce(group),
                  let date = group.compactMap({ $0.workout?.startTime ?? $0.timestamp }).min() else { continue }
            points.append(SessionPoint(date: date, value: value))
        }
        return points.sorted { $0.date < $1.date }
    }

    // MARK: - Frequency

    /// Number of distinct days on which a workout started, within the sessions.
    static func workoutDays(_ sessions: [WorkoutSession]) -> Int {
        let days = Set(sessions.map { Calendar.current.startOfDay(for: $0.startTime) })
        return days.count
    }

    /// Sessions per ISO week, sorted oldest first.
    static func sessionsPerWeek(_ sessions: [WorkoutSession]) -> [SessionPoint] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: sessions) { session -> Date in
            calendar.dateInterval(of: .weekOfYear, for: session.startTime)?.start ?? session.startTime
        }
        return grouped
            .map { SessionPoint(date: $0.key, value: Double($0.value.count)) }
            .sorted { $0.date < $1.date }
    }
}
