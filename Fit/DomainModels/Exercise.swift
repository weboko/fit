import Foundation
import SwiftData

/// A user-owned exercise definition. Exercises are never hard-coded: starter
/// suggestions are seeded once but are fully editable, mergeable and
/// archivable. Names may be in any language or mixed languages (spec §10.2).
@Model
final class Exercise {
    var id: UUID = UUID()
    var canonicalName: String = ""

    var categoryRaw: String?
    var equipmentRaw: String?
    var movementPatternRaw: String?
    var defaultWeightModeRaw: String = WeightMode.external.rawValue

    /// Muscle groups stored as arrays of stable raw values (CloudKit-friendly).
    var primaryMusclesRaw: [String] = []
    var secondaryMusclesRaw: [String] = []

    var notes: String = ""
    var archived: Bool = false

    /// Marks an exercise the user is explicitly progressing toward a goal on
    /// (e.g. 100 kg bench press) so the UI can surface it (spec §17).
    var isGoalExercise: Bool = false
    var isFavorite: Bool = false

    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    @Relationship(deleteRule: .cascade, inverse: \ExerciseAlias.exercise)
    var aliases: [ExerciseAlias]? = []

    @Relationship(deleteRule: .nullify, inverse: \WorkoutSet.exercise)
    var sets: [WorkoutSet]? = []

    init(
        id: UUID = UUID(),
        canonicalName: String = "",
        category: ExerciseCategory? = nil,
        equipment: Equipment? = nil,
        movementPattern: MovementPattern? = nil,
        defaultWeightMode: WeightMode = .external,
        primaryMuscles: [MuscleGroup] = [],
        secondaryMuscles: [MuscleGroup] = [],
        isGoalExercise: Bool = false,
        isFavorite: Bool = false
    ) {
        self.id = id
        self.canonicalName = canonicalName
        self.categoryRaw = category?.rawValue
        self.equipmentRaw = equipment?.rawValue
        self.movementPatternRaw = movementPattern?.rawValue
        self.defaultWeightModeRaw = defaultWeightMode.rawValue
        self.primaryMusclesRaw = primaryMuscles.map(\.rawValue)
        self.secondaryMusclesRaw = secondaryMuscles.map(\.rawValue)
        self.isGoalExercise = isGoalExercise
        self.isFavorite = isFavorite
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}

// MARK: - Typed accessors

extension Exercise {
    var category: ExerciseCategory? {
        get { categoryRaw.flatMap(ExerciseCategory.init(rawValue:)) }
        set { categoryRaw = newValue?.rawValue }
    }
    var equipment: Equipment? {
        get { equipmentRaw.flatMap(Equipment.init(rawValue:)) }
        set { equipmentRaw = newValue?.rawValue }
    }
    var movementPattern: MovementPattern? {
        get { movementPatternRaw.flatMap(MovementPattern.init(rawValue:)) }
        set { movementPatternRaw = newValue?.rawValue }
    }
    var defaultWeightMode: WeightMode {
        get { WeightMode(rawValue: defaultWeightModeRaw) ?? .external }
        set { defaultWeightModeRaw = newValue.rawValue }
    }
    var primaryMuscles: [MuscleGroup] {
        get { primaryMusclesRaw.compactMap(MuscleGroup.init(rawValue:)) }
        set { primaryMusclesRaw = newValue.map(\.rawValue) }
    }
    var secondaryMuscles: [MuscleGroup] {
        get { secondaryMusclesRaw.compactMap(MuscleGroup.init(rawValue:)) }
        set { secondaryMusclesRaw = newValue.map(\.rawValue) }
    }
}

// MARK: - Convenience

extension Exercise {
    var aliasNames: [String] {
        (aliases ?? []).map(\.aliasName).filter { !$0.isEmpty }
    }

    var orderedSets: [WorkoutSet] {
        (sets ?? []).sorted { $0.timestamp > $1.timestamp }
    }

    /// All names this exercise can be matched against (canonical + aliases),
    /// used by search and picker.
    var searchableNames: [String] {
        [canonicalName] + aliasNames
    }

    func matches(query: String) -> Bool {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return true }
        return searchableNames.contains { $0.lowercased().contains(q) }
    }

    func touch() { updatedAt = Date() }
}
