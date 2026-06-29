import Foundation
import SwiftData
import WidgetKit

// MARK: - Shared contract (duplicated for the widget extension)

/// The tiny data contract the app writes to a shared App Group `UserDefaults`
/// for the WidgetKit extension to read. The widget is a separate module (no
/// shared framework), so this Codable shape is **duplicated** in
/// `FitWidget/WidgetSnapshot.swift` — keep the property names + JSON keys in
/// sync between the two.
struct WidgetSnapshot: Codable {
    var lastWorkoutTitle: String?
    var lastWorkoutDate: Date?
    var weeklyStreak: Int
    var topSetSummary: String?
}

// MARK: - Writer

/// Computes a `WidgetSnapshot` from the finished workout sessions and persists
/// it (as JSON) into the shared App Group `UserDefaults`, then asks WidgetKit to
/// reload. Pure/deterministic given its inputs; the SwiftData read is the only
/// side-effectful part, hence `@MainActor`.
@MainActor
enum WidgetSnapshotWriter {

    /// App Group identifier — must match `FitWidget/WidgetSnapshot.swift` and the
    /// `com.apple.security.application-groups` entitlement on both targets.
    static let suiteName = "group.com.weboko.fit"
    /// Storage key — must match the widget's `SharedStore.snapshotKey`.
    static let snapshotKey = "widgetSnapshot.v1"

    /// Reads finished sessions from the context, builds the snapshot, and writes
    /// it. Safe to call from a finish action or on launch. Failures are silent
    /// (the widget simply keeps its last state / shows the empty state).
    static func update(from context: ModelContext, now: Date = Date()) {
        // Fetch all sessions and filter to finished ones in Swift. The codebase
        // prefers Swift-side filtering over `#Predicate` for anything non-trivial
        // (the macro can't reach computed helpers / optional comparisons cleanly).
        guard let all = try? context.fetch(FetchDescriptor<WorkoutSession>()) else { return }
        let finished = all.filter { $0.endTime != nil }
        let snapshot = makeSnapshot(from: finished, now: now)
        save(snapshot)
        WidgetCenter.shared.reloadAllTimelines()
    }

    /// Builds a snapshot from already-fetched finished sessions. Deterministic
    /// and side-effect-free — the unit-testable core. `now` anchors the streak.
    static func makeSnapshot(from finishedSessions: [WorkoutSession], now: Date = Date()) -> WidgetSnapshot {
        let sorted = finishedSessions.sorted { $0.startTime > $1.startTime }
        let last = sorted.first

        let title = last?.displayTitle()
        let date = last?.startTime
        let topSummary = last.flatMap(topSetSummary(for:))
        let streak = weeklyStreak(from: sorted, now: now)

        return WidgetSnapshot(
            lastWorkoutTitle: title,
            lastWorkoutDate: date,
            weeklyStreak: streak,
            topSetSummary: topSummary
        )
    }

    // MARK: - Top set summary

    /// "Bench Press 80 kg × 6" for the session's best working set, or nil when
    /// the session has no rankable set.
    private static func topSetSummary(for session: WorkoutSession) -> String? {
        guard let best = WorkoutLoggingHelpers.topSets(in: session).first else { return nil }
        return "\(best.exercise.canonicalName) \(Format.setSummary(best.set))"
    }

    // MARK: - Weekly streak

    /// Consecutive ISO weeks, counting back from the week containing `now`, in
    /// which at least one finished workout started. The current week counts only
    /// if it has a workout; the streak stops at the first gap.
    static func weeklyStreak(from finishedSessions: [WorkoutSession], now: Date = Date()) -> Int {
        var calendar = Calendar(identifier: .iso8601)
        calendar.timeZone = .current

        // Set of week-start dates that contain ≥1 finished workout.
        let activeWeekStarts = Set(finishedSessions.compactMap { session in
            calendar.dateInterval(of: .weekOfYear, for: session.startTime)?.start
        })
        guard !activeWeekStarts.isEmpty else { return 0 }

        guard var weekStart = calendar.dateInterval(of: .weekOfYear, for: now)?.start else { return 0 }

        var streak = 0
        while activeWeekStarts.contains(weekStart) {
            streak += 1
            guard let previous = calendar.date(byAdding: .weekOfYear, value: -1, to: weekStart) else { break }
            weekStart = previous
        }
        return streak
    }

    // MARK: - Persistence

    private static func save(_ snapshot: WidgetSnapshot) {
        guard let defaults = UserDefaults(suiteName: suiteName) else { return }
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(snapshot) else { return }
        defaults.set(data, forKey: snapshotKey)
    }
}
