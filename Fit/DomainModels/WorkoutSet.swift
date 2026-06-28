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

    /// Optional superset / circuit grouping within a session (F10). `nil` means
    /// the set is not part of a superset; `1` = group A, `2` = group B, … Stored
    /// as an optional Int so it's CloudKit-safe and needs no schema/init change.
    var supersetGroup: Int?

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

// MARK: - Superset grouping (F10)

/// Bidirectional mapping between a stored superset group number (1, 2, …) and
/// its display letter ("A", "B", …). Kept deliberately small (≈6 groups) since
/// supersets/circuits rarely chain more than a handful of exercises.
enum SupersetGroup {
    /// How many distinct groups the UI offers (A…F).
    static let maxGroups = 6

    /// The group numbers the picker offers, in order: 1…maxGroups.
    static let allNumbers = Array(1...maxGroups)

    /// Letter for a group number: 1 → "A", 2 → "B", … Returns nil for values
    /// outside the supported range (including 0 / negatives).
    static func letter(for number: Int) -> String? {
        guard number >= 1, number <= maxGroups else { return nil }
        // 65 == "A"; the guard keeps the byte in the printable A…F range.
        let scalar = UnicodeScalar(UInt8(64 + number))
        return String(Character(scalar))
    }

    /// Group number for a letter: "A" → 1, "b" → 2, … Returns nil when the
    /// letter is outside the supported range.
    static func number(for letter: String) -> Int? {
        guard let first = letter.uppercased().unicodeScalars.first else { return nil }
        let value = Int(first.value) - 64
        return (1...maxGroups).contains(value) ? value : nil
    }

    /// "Superset A", "Superset B", … for a group number, or nil if out of range.
    static func displayName(for number: Int) -> String? {
        letter(for: number).map { "Superset \($0)" }
    }
}

extension WorkoutSet {
    /// The single-letter label for this set's superset group ("A"/"B"/…), or nil
    /// when the set is not part of a superset.
    var supersetLabel: String? {
        supersetGroup.flatMap(SupersetGroup.letter(for:))
    }

    /// "Superset A" / "Superset B" / … for badge display, or nil when ungrouped.
    var supersetDisplayName: String? {
        supersetGroup.flatMap(SupersetGroup.displayName(for:))
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
