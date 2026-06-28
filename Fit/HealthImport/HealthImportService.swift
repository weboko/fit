import Foundation
import SwiftData
import HealthKit

/// Read-only bridge to Apple Health. Queries workouts, body mass and sleep and
/// upserts them into SwiftData, de-duplicating against previously imported
/// records. Never writes to Health, never overwrites manually-entered data
/// (spec §11, §26.3).
///
/// `@MainActor` so its published state and the `ModelContext` inserts both stay
/// on the main thread (the contexts passed in are main-context bound in this
/// app). HealthKit completion handlers run on a background queue; we hop back
/// via the continuation + `@MainActor` isolation of the calling methods.
@MainActor
final class HealthImportService: ObservableObject {

    // MARK: Published UI state

    /// Combined authorization signal for the read types we care about. Note that
    /// for privacy Apple only ever reports `.sharingDenied`/`.notDetermined` for
    /// READ types (you cannot tell if read access was granted), so this reflects
    /// "have we asked / been refused", not "can we definitely read".
    @Published private(set) var authorizationStatus: HKAuthorizationStatus = .notDetermined

    /// Set while a request or an import is running, to drive progress UI.
    @Published private(set) var isWorking: Bool = false

    /// The last user-facing message (success or failure) from an import, if any.
    @Published private(set) var lastResultMessage: String?

    // MARK: Store

    /// A single shared store instance for the whole service lifetime.
    private let store = HKHealthStore()

    // MARK: Availability

    static var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    init() {
        refreshAuthorizationStatus()
    }

    // MARK: Authorization

    /// Human-readable description of the current authorization state for the UI.
    var authorizationStatusDescription: String {
        guard Self.isAvailable else {
            return "Apple Health is not available on this device."
        }
        switch authorizationStatus {
        case .notDetermined:
            return "Not requested yet."
        case .sharingDenied:
            // For read types this also covers "asked but you can't read", which
            // Apple deliberately makes indistinguishable for privacy.
            return "Permission not granted. You can change this in the Health app under Sharing."
        case .sharingAuthorized:
            return "Authorization requested. Imports will include whatever you allowed."
        @unknown default:
            return "Unknown authorization state."
        }
    }

    /// Whether it makes sense to show import controls (available + at least asked).
    var canAttemptImport: Bool {
        Self.isAvailable && authorizationStatus != .notDetermined
    }

    /// Re-reads the authorization status for our primary type (workouts) and
    /// publishes it. HealthKit only exposes status meaningfully for share/read
    /// per-type; we use the workout type as the representative signal.
    func refreshAuthorizationStatus() {
        guard Self.isAvailable else {
            authorizationStatus = .notDetermined
            return
        }
        authorizationStatus = store.authorizationStatus(for: HKObjectType.workoutType())
    }

    /// Requests READ access for all the types in `HealthKitTypes.readTypes`.
    /// No-ops safely when Health is unavailable.
    func requestAuthorization() async {
        guard Self.isAvailable else {
            lastResultMessage = "Apple Health is not available on this device."
            return
        }
        isWorking = true
        defer { isWorking = false }
        do {
            try await store.requestAuthorization(toShare: [], read: HealthKitTypes.readTypes)
            refreshAuthorizationStatus()
            lastResultMessage = nil
        } catch {
            lastResultMessage = "Could not request Health access: \(error.localizedDescription)"
            refreshAuthorizationStatus()
        }
    }

    // MARK: Imports

    /// Imports workouts started on/after `since`, upserting `HealthWorkout`
    /// records de-duplicated by `appleHealthUUID`. For each new workout we also
    /// query its heart-rate samples and compute avg/min/max + count.
    /// Returns silently when unavailable. Reports a summary in `lastResultMessage`.
    func importRecentWorkouts(into context: ModelContext, since: Date) async {
        guard Self.isAvailable else {
            lastResultMessage = "Apple Health is not available."
            return
        }
        isWorking = true
        defer { isWorking = false }

        do {
            let workouts = try await fetchWorkouts(since: since)
            let existing = existingWorkoutUUIDs(in: context)
            var inserted = 0

            for workout in workouts {
                let uuid = workout.uuid.uuidString
                guard !existing.contains(uuid) else { continue }

                let hw = HealthWorkout(
                    appleHealthUUID: uuid,
                    workoutType: HealthKitTypes.name(for: workout.workoutActivityType),
                    startTime: workout.startDate,
                    endTime: workout.endDate,
                    durationSeconds: workout.duration
                )
                hw.activeEnergyKcal = activeEnergy(of: workout)
                hw.totalEnergyKcal = totalEnergy(of: workout)
                hw.sourceName = workout.sourceRevision.source.name
                hw.sourceDevice = workout.device?.name ?? workout.sourceRevision.source.name

                // Heart-rate summary from the workout's own samples.
                if let summary = try? await heartRateSummary(for: workout) {
                    hw.avgHeartRateBpm = summary.avg
                    hw.minHeartRateBpm = summary.min
                    hw.maxHeartRateBpm = summary.max
                    hw.heartRateSampleCount = summary.count
                }

                context.insert(hw)
                inserted += 1
            }

            try? context.save()
            lastResultMessage = inserted == 0
                ? "No new workouts to import."
                : "Imported \(inserted) workout\(inserted == 1 ? "" : "s")."
        } catch {
            lastResultMessage = "Workout import failed: \(error.localizedDescription)"
        }
    }

    /// Imports body-mass samples on/after `since` as `BodyWeightEntry`,
    /// de-duplicated by `appleHealthSampleId`. Source marked `.healthImport`.
    func importBodyWeight(into context: ModelContext, since: Date) async {
        guard Self.isAvailable, let type = HealthKitTypes.bodyMass else {
            lastResultMessage = "Body weight is not available from Health."
            return
        }
        isWorking = true
        defer { isWorking = false }

        do {
            let samples = try await fetchQuantitySamples(type: type, since: since)
            let existing = existingBodyWeightSampleIds(in: context)
            var inserted = 0

            for sample in samples {
                let sampleId = sample.uuid.uuidString
                guard !existing.contains(sampleId) else { continue }

                let kg = sample.quantity.doubleValue(for: HealthKitTypes.kilogram)
                let entry = BodyWeightEntry(
                    timestamp: sample.startDate,
                    weightKg: kg,
                    source: .healthImport,
                    appleHealthSampleId: sampleId
                )
                context.insert(entry)
                inserted += 1
            }

            try? context.save()
            lastResultMessage = inserted == 0
                ? "No new body-weight entries to import."
                : "Imported \(inserted) body-weight entr\(inserted == 1 ? "y" : "ies")."
        } catch {
            lastResultMessage = "Body-weight import failed: \(error.localizedDescription)"
        }
    }

    /// Imports sleep-analysis "asleep" samples on/after `since` as `SleepEntry`,
    /// de-duplicated by `appleHealthSampleId`. Source marked `.healthImport`.
    /// Only "asleep" categories are imported (in-bed / awake are skipped).
    func importSleep(into context: ModelContext, since: Date) async {
        guard Self.isAvailable, let type = HealthKitTypes.sleepAnalysis else {
            lastResultMessage = "Sleep is not available from Health."
            return
        }
        isWorking = true
        defer { isWorking = false }

        do {
            let samples = try await fetchCategorySamples(type: type, since: since)
            let existing = existingSleepSampleIds(in: context)
            var inserted = 0
            let calendar = Calendar.current

            for sample in samples {
                guard Self.isAsleep(sample) else { continue }
                let sampleId = sample.uuid.uuidString
                guard !existing.contains(sampleId) else { continue }

                let entry = SleepEntry(
                    // The night belongs to the calendar day of waking (end).
                    date: calendar.startOfDay(for: sample.endDate),
                    source: .healthImport
                )
                entry.startTime = sample.startDate
                entry.endTime = sample.endDate
                entry.durationSeconds = sample.endDate.timeIntervalSince(sample.startDate)
                entry.appleHealthSampleId = sampleId
                context.insert(entry)
                inserted += 1
            }

            try? context.save()
            lastResultMessage = inserted == 0
                ? "No new sleep records to import."
                : "Imported \(inserted) sleep record\(inserted == 1 ? "" : "s")."
        } catch {
            lastResultMessage = "Sleep import failed: \(error.localizedDescription)"
        }
    }

    // MARK: Linking

    /// Apple Health workouts already imported that overlap `session`'s window and
    /// are not linked to a different session. Sorted by start time.
    func suggestedWorkouts(for session: WorkoutSession, in context: ModelContext) -> [HealthWorkout] {
        let all = (try? context.fetch(FetchDescriptor<HealthWorkout>())) ?? []
        return all
            .filter { $0.overlaps(session: session) }
            .filter { $0.linkedSession == nil || $0.linkedSession?.id == session.id }
            .sorted { $0.startTime < $1.startTime }
    }

    /// Links `hw` to `session`, ensuring no duplicate links: any health workout
    /// previously linked to this session is detached first, and `hw` is detached
    /// from any other session it might have been linked to.
    func link(_ hw: HealthWorkout, to session: WorkoutSession, in context: ModelContext) {
        // Detach hw from a previous (different) session.
        if let previous = hw.linkedSession, previous.id != session.id {
            previous.linkedHealthWorkout = nil
        }
        // Detach session's previous link if it's a different health workout.
        if let current = session.linkedHealthWorkout, current.id != hw.id {
            current.linkedSession = nil
        }
        session.linkedHealthWorkout = hw
        session.touch()
        try? context.save()
    }

    /// Removes any link between `session` and its currently linked health workout.
    func unlink(from session: WorkoutSession, in context: ModelContext) {
        guard let current = session.linkedHealthWorkout else { return }
        current.linkedSession = nil
        session.linkedHealthWorkout = nil
        session.touch()
        try? context.save()
    }

    // MARK: - Dedup lookups

    private func existingWorkoutUUIDs(in context: ModelContext) -> Set<String> {
        let all = (try? context.fetch(FetchDescriptor<HealthWorkout>())) ?? []
        return Set(all.map { $0.appleHealthUUID })
    }

    private func existingBodyWeightSampleIds(in context: ModelContext) -> Set<String> {
        let all = (try? context.fetch(FetchDescriptor<BodyWeightEntry>())) ?? []
        return Set(all.compactMap { $0.appleHealthSampleId })
    }

    private func existingSleepSampleIds(in context: ModelContext) -> Set<String> {
        let all = (try? context.fetch(FetchDescriptor<SleepEntry>())) ?? []
        return Set(all.compactMap { $0.appleHealthSampleId })
    }

    // MARK: - HealthKit query wrappers (async/await over continuations)

    private func fetchWorkouts(since: Date) async throws -> [HKWorkout] {
        let predicate = HKQuery.predicateForSamples(withStart: since, end: nil, options: .strictStartDate)
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: HKObjectType.workoutType(),
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [sort]
            ) { _, samples, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                continuation.resume(returning: (samples as? [HKWorkout]) ?? [])
            }
            store.execute(query)
        }
    }

    private func fetchQuantitySamples(type: HKQuantityType, since: Date) async throws -> [HKQuantitySample] {
        let predicate = HKQuery.predicateForSamples(withStart: since, end: nil, options: .strictStartDate)
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: type,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [sort]
            ) { _, samples, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                continuation.resume(returning: (samples as? [HKQuantitySample]) ?? [])
            }
            store.execute(query)
        }
    }

    private func fetchCategorySamples(type: HKCategoryType, since: Date) async throws -> [HKCategorySample] {
        let predicate = HKQuery.predicateForSamples(withStart: since, end: nil, options: .strictStartDate)
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: type,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [sort]
            ) { _, samples, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                continuation.resume(returning: (samples as? [HKCategorySample]) ?? [])
            }
            store.execute(query)
        }
    }

    /// Aggregated heart-rate stats over a workout's time window.
    private struct HeartRateSummary {
        let avg: Double
        let min: Double
        let max: Double
        let count: Int
    }

    private func heartRateSummary(for workout: HKWorkout) async throws -> HeartRateSummary? {
        guard let hrType = HealthKitTypes.heartRate else { return nil }
        let predicate = HKQuery.predicateForSamples(
            withStart: workout.startDate,
            end: workout.endDate,
            options: .strictStartDate
        )
        let unit = HealthKitTypes.beatsPerMinute

        let samples: [HKQuantitySample] = try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: hrType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: nil
            ) { _, samples, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                continuation.resume(returning: (samples as? [HKQuantitySample]) ?? [])
            }
            store.execute(query)
        }

        guard !samples.isEmpty else { return nil }
        let values = samples.map { $0.quantity.doubleValue(for: unit) }
        let sum = values.reduce(0, +)
        return HeartRateSummary(
            avg: sum / Double(values.count),
            min: values.min() ?? 0,
            max: values.max() ?? 0,
            count: values.count
        )
    }

    // MARK: - Workout energy helpers (handle pre/post iOS 18 statistics API)

    private func activeEnergy(of workout: HKWorkout) -> Double? {
        guard let type = HealthKitTypes.activeEnergyBurned,
              let stats = workout.statistics(for: type),
              let quantity = stats.sumQuantity() else {
            // Fall back to the (deprecated) totalEnergyBurned on the workout.
            return workout.totalEnergyBurned?.doubleValue(for: HealthKitTypes.kilocalorie)
        }
        return quantity.doubleValue(for: HealthKitTypes.kilocalorie)
    }

    private func totalEnergy(of workout: HKWorkout) -> Double? {
        let active = activeEnergy(of: workout)
        var basal: Double?
        if let type = HealthKitTypes.basalEnergyBurned,
           let stats = workout.statistics(for: type),
           let quantity = stats.sumQuantity() {
            basal = quantity.doubleValue(for: HealthKitTypes.kilocalorie)
        }
        switch (active, basal) {
        case let (a?, b?): return a + b
        case let (a?, nil): return a
        case let (nil, b?): return b
        case (nil, nil): return nil
        }
    }

    // MARK: - Sleep classification

    /// Whether a sleep-analysis sample represents actual sleep (any "asleep"
    /// category). Uses the iOS 16+ granular sleep categories; in-bed and awake
    /// samples are ignored so durations reflect real sleep.
    private static func isAsleep(_ sample: HKCategorySample) -> Bool {
        switch HKCategoryValueSleepAnalysis(rawValue: sample.value) {
        case .asleepUnspecified, .asleepCore, .asleepDeep, .asleepREM:
            return true
        default:
            return false
        }
    }
}
