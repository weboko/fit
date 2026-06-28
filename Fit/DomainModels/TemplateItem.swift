import Foundation
import SwiftData

/// One planned exercise inside a `WorkoutTemplate`: which exercise, in what
/// order, and the target sets / reps / weight to aim for. The targets are
/// suggestions used to pre-fill set entry when starting from a template; they
/// are never logged as real sets by themselves (spec F4).
///
/// SwiftData + CloudKit constraints honoured here:
/// - every stored property has a default value,
/// - relationships are optional and the inverse is declared on the parent side,
/// - no `.unique` attributes.
@Model
final class TemplateItem {
    var id: UUID = UUID()

    /// Position within the template (0-based, ascending).
    var order: Int = 0

    /// Target number of working sets to perform.
    var targetSets: Int = 3
    /// Optional target reps per set.
    var targetReps: Int?
    /// Optional target load in kg (storage is always kg, like everything else).
    var targetWeightKg: Double?

    /// Weight mode this target is expressed in, stored as a raw value with a
    /// typed accessor (mirrors `WorkoutSet.weightModeRaw`).
    var weightModeRaw: String = WeightMode.external.rawValue

    /// Snapshot of the exercise name at save time, preserved even if the
    /// exercise is later renamed, merged or archived (mirrors `WorkoutSet`).
    var exerciseNameAtTime: String = ""

    // Relationships. Inverse for `template` is declared on `WorkoutTemplate`.
    var template: WorkoutTemplate?
    /// Plain (nullify) reference to the exercise; no inverse declared here so we
    /// do not add a back-reference array to `Exercise`.
    @Relationship(deleteRule: .nullify)
    var exercise: Exercise?

    init(
        id: UUID = UUID(),
        order: Int = 0,
        targetSets: Int = 3,
        targetReps: Int? = nil,
        targetWeightKg: Double? = nil,
        weightMode: WeightMode = .external,
        exercise: Exercise? = nil,
        exerciseNameAtTime: String = ""
    ) {
        self.id = id
        self.order = order
        self.targetSets = targetSets
        self.targetReps = targetReps
        self.targetWeightKg = targetWeightKg
        self.weightModeRaw = weightMode.rawValue
        self.exercise = exercise
        self.exerciseNameAtTime = exerciseNameAtTime
    }
}

// MARK: - Typed enum accessors

extension TemplateItem {
    var weightMode: WeightMode {
        get { WeightMode(rawValue: weightModeRaw) ?? .external }
        set { weightModeRaw = newValue.rawValue }
    }
}

// MARK: - Convenience

extension TemplateItem {
    /// The name to display: the live exercise name if linked, else the snapshot.
    var displayName: String {
        if let name = exercise?.canonicalName, !name.isEmpty { return name }
        return exerciseNameAtTime
    }

    /// A compact one-line target summary, e.g. "3 × 8 @ 60 kg" or "3 × 8".
    var targetSummary: String {
        var parts: [String] = ["\(targetSets) set\(targetSets == 1 ? "" : "s")"]
        if let reps = targetReps, reps > 0 {
            parts[0] = "\(targetSets) × \(reps)"
        }
        if let kg = targetWeightKg, kg > 0 {
            switch weightMode {
            case .external, .unknown:
                parts.append("@ \(Format.weight(kg))")
            case .addedBodyweight:
                parts.append("@ +\(Format.weight(kg))")
            case .assistedBodyweight:
                parts.append("@ −\(Format.weight(kg))")
            case .bodyweight:
                break
            }
        } else if weightMode == .bodyweight {
            parts.append("bodyweight")
        }
        return parts.joined(separator: " ")
    }
}
