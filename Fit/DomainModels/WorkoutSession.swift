import Foundation
import SwiftData

/// A single training session. The container of sets and the place where
/// once-per-workout subjective metadata lives.
///
/// SwiftData + CloudKit constraints honoured here:
/// - every stored property has a default value,
/// - every relationship is optional,
/// - no `.unique` attributes (CloudKit does not support them).
@Model
final class WorkoutSession {
    var id: UUID = UUID()
    var title: String = ""

    /// When the session started. `endTime == nil` marks an in-progress workout.
    var startTime: Date = Date()
    var endTime: Date?

    /// IANA timezone identifier captured at logging time (see spec §26.5).
    var timezoneIdentifier: String = TimeZone.current.identifier

    // MARK: First-priority subjective metadata (§8.1)
    var goalRaw: String?
    var locationRaw: String?
    var energyBefore: Int?          // 0–5, see EnergyScale
    var sorenessRaw: String?
    var painTodayRaw: String?
    var sleepQualitySubjectiveRaw: String?

    // MARK: Second-priority metadata (§8.2)
    var stressLevel: Int?           // 0–5, see StressScale
    var foodTimingRaw: String?
    var caffeineRaw: String?
    var bodyWeightManualKg: Double?

    var notes: String = ""
    var isBackfilled: Bool = false

    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    // MARK: Relationships
    @Relationship(deleteRule: .cascade, inverse: \WorkoutSet.workout)
    var sets: [WorkoutSet]? = []

    @Relationship(deleteRule: .cascade, inverse: \JournalEntry.workout)
    var journalEntries: [JournalEntry]? = []

    @Relationship(deleteRule: .nullify, inverse: \HealthWorkout.linkedSession)
    var linkedHealthWorkout: HealthWorkout?

    init(
        id: UUID = UUID(),
        title: String = "",
        startTime: Date = Date(),
        endTime: Date? = nil,
        timezoneIdentifier: String = TimeZone.current.identifier,
        isBackfilled: Bool = false
    ) {
        self.id = id
        self.title = title
        self.startTime = startTime
        self.endTime = endTime
        self.timezoneIdentifier = timezoneIdentifier
        self.isBackfilled = isBackfilled
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}

// MARK: - Typed enum accessors

extension WorkoutSession {
    var goal: WorkoutGoal? {
        get { goalRaw.flatMap(WorkoutGoal.init(rawValue:)) }
        set { goalRaw = newValue?.rawValue }
    }
    var location: WorkoutLocation? {
        get { locationRaw.flatMap(WorkoutLocation.init(rawValue:)) }
        set { locationRaw = newValue?.rawValue }
    }
    var soreness: Soreness? {
        get { sorenessRaw.flatMap(Soreness.init(rawValue:)) }
        set { sorenessRaw = newValue?.rawValue }
    }
    var painToday: PainToday? {
        get { painTodayRaw.flatMap(PainToday.init(rawValue:)) }
        set { painTodayRaw = newValue?.rawValue }
    }
    var sleepQualitySubjective: SleepQuality? {
        get { sleepQualitySubjectiveRaw.flatMap(SleepQuality.init(rawValue:)) }
        set { sleepQualitySubjectiveRaw = newValue?.rawValue }
    }
    var foodTiming: FoodTiming? {
        get { foodTimingRaw.flatMap(FoodTiming.init(rawValue:)) }
        set { foodTimingRaw = newValue?.rawValue }
    }
    var caffeine: Caffeine? {
        get { caffeineRaw.flatMap(Caffeine.init(rawValue:)) }
        set { caffeineRaw = newValue?.rawValue }
    }
}

// MARK: - Convenience

extension WorkoutSession {
    /// An in-progress workout has not been finished yet.
    var isActive: Bool { endTime == nil }

    var timeZone: TimeZone {
        TimeZone(identifier: timezoneIdentifier) ?? .current
    }

    var duration: TimeInterval? {
        guard let endTime else { return nil }
        return endTime.timeIntervalSince(startTime)
    }

    /// Sets ordered by their `setIndex` then timestamp.
    var orderedSets: [WorkoutSet] {
        (sets ?? []).sorted {
            if $0.setIndex != $1.setIndex { return $0.setIndex < $1.setIndex }
            return $0.timestamp < $1.timestamp
        }
    }

    var workingSets: [WorkoutSet] {
        orderedSets.filter { !$0.isWarmup }
    }

    /// Distinct exercises in order of first appearance in the session.
    var exercisesInOrder: [Exercise] {
        var seen = Set<UUID>()
        var result: [Exercise] = []
        for set in orderedSets {
            guard let exercise = set.exercise else { continue }
            if seen.insert(exercise.id).inserted {
                result.append(exercise)
            }
        }
        return result
    }

    /// A short, human display title, falling back to the date.
    func displayTitle(dateStyle: Date.FormatStyle = .dateTime.weekday().month().day()) -> String {
        if !title.trimmingCharacters(in: .whitespaces).isEmpty { return title }
        return startTime.formatted(dateStyle)
    }

    func touch() { updatedAt = Date() }
}
