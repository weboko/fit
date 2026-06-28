import Foundation
import SwiftData

/// A single logged set. Designed so pull-ups (assisted / weighted / bodyweight)
/// and ordinary external-load lifts share one representation via `weightMode`.
@Model
final class WorkoutSet {
    var id: UUID = UUID()

    // Relationships (inverses declared on the parent side).
    var workout: WorkoutSession?
    var exercise: Exercise?

    /// Snapshot of the exercise name at logging time, preserved even if the
    /// exercise is later renamed or merged (spec §21).
    var exerciseNameAtTime: String = ""

    var setIndex: Int = 0
    var timestamp: Date = Date()

    var weightModeRaw: String = WeightMode.external.rawValue

    /// External bar/machine load (used when weightMode == .external).
    var weightKg: Double?
    /// Bodyweight used for bodyweight-based modes.
    var bodyWeightKg: Double?
    /// Assistance subtracted for assisted bodyweight (positive number, kg).
    var assistanceKg: Double?
    /// Extra load added for weighted bodyweight (positive number, kg).
    var addedWeightKg: Double?

    var reps: Int?
    var effort: Int?            // 0–5, see EffortScale

    var repsLeftRaw: String?
    var formQualityRaw: String?
    var limiterRaw: String?
    var painSeverityRaw: String?
    var painLocationRaw: String?

    var isWarmup: Bool = false
    var isFailed: Bool = false

    var sourceRaw: String = RecordSource.manual.rawValue
    var notes: String = ""

    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    init(
        id: UUID = UUID(),
        exercise: Exercise? = nil,
        exerciseNameAtTime: String = "",
        setIndex: Int = 0,
        timestamp: Date = Date(),
        weightMode: WeightMode = .external,
        source: RecordSource = .manual
    ) {
        self.id = id
        self.exercise = exercise
        self.exerciseNameAtTime = exerciseNameAtTime
        self.setIndex = setIndex
        self.timestamp = timestamp
        self.weightModeRaw = weightMode.rawValue
        self.sourceRaw = source.rawValue
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}

// MARK: - Typed enum accessors

extension WorkoutSet {
    var weightMode: WeightMode {
        get { WeightMode(rawValue: weightModeRaw) ?? .unknown }
        set { weightModeRaw = newValue.rawValue }
    }
    var source: RecordSource {
        get { RecordSource(rawValue: sourceRaw) ?? .manual }
        set { sourceRaw = newValue.rawValue }
    }
    var repsLeft: RepsLeft? {
        get { repsLeftRaw.flatMap(RepsLeft.init(rawValue:)) }
        set { repsLeftRaw = newValue?.rawValue }
    }
    var formQuality: FormQuality? {
        get { formQualityRaw.flatMap(FormQuality.init(rawValue:)) }
        set { formQualityRaw = newValue?.rawValue }
    }
    var limiter: Limiter? {
        get { limiterRaw.flatMap(Limiter.init(rawValue:)) }
        set { limiterRaw = newValue?.rawValue }
    }
    var painSeverity: PainSeverity? {
        get { painSeverityRaw.flatMap(PainSeverity.init(rawValue:)) }
        set { painSeverityRaw = newValue?.rawValue }
    }
    var painLocation: PainLocation? {
        get { painLocationRaw.flatMap(PainLocation.init(rawValue:)) }
        set { painLocationRaw = newValue?.rawValue }
    }
}

// MARK: - Derived training values (deterministic, non-AI — spec §15)

extension WorkoutSet {
    /// The load that actually "counts" for this set, in kg, accounting for the
    /// weight mode. Returns nil when there is not enough data to compute it.
    var effectiveLoadKg: Double? {
        switch weightMode {
        case .external:
            return weightKg
        case .bodyweight:
            return bodyWeightKg
        case .assistedBodyweight:
            guard let bw = bodyWeightKg else { return nil }
            return bw - (assistanceKg ?? 0)
        case .addedBodyweight:
            guard let bw = bodyWeightKg else { return weightKg }
            return bw + (addedWeightKg ?? 0)
        case .unknown:
            return weightKg ?? bodyWeightKg
        }
    }

    /// Volume load = effective load × reps. Used for simple volume summaries.
    var volumeKg: Double? {
        guard let load = effectiveLoadKg, let reps else { return nil }
        return load * Double(reps)
    }

    /// Epley estimate of one-rep max. Clearly an estimate, never coaching.
    var estimatedOneRepMaxKg: Double? {
        guard weightMode == .external || weightMode == .addedBodyweight,
              let load = effectiveLoadKg, load > 0,
              let reps, reps > 0 else { return nil }
        if reps == 1 { return load }
        return load * (1.0 + Double(reps) / 30.0)
    }

    func touch() { updatedAt = Date() }
}
