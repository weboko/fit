import Foundation
import SwiftData

/// Optional starter exercise suggestions. Exercises are NOT hard-coded: these
/// are seeded once on first launch (only when the library is empty) and are
/// fully editable, mergeable and archivable afterwards (spec §10).
enum SeedData {

    private static let seededFlagKey = "fit.hasSeededStarterExercises.v1"

    /// Seeds starter exercises only if the library is empty and we have not
    /// seeded on this device before.
    static func seedIfNeeded(in context: ModelContext) {
        let alreadySeeded = UserDefaults.standard.bool(forKey: seededFlagKey)
        let existingCount = (try? context.fetchCount(FetchDescriptor<Exercise>())) ?? 0
        guard !alreadySeeded, existingCount == 0 else {
            if existingCount > 0 { UserDefaults.standard.set(true, forKey: seededFlagKey) }
            return
        }
        addStarterExercises(to: context)
        UserDefaults.standard.set(true, forKey: seededFlagKey)
    }

    /// Inserts the curated starter set. Safe to call from Settings; the user can
    /// archive or delete anything they don't want.
    @discardableResult
    static func addStarterExercises(to context: ModelContext) -> [Exercise] {
        var created: [Exercise] = []

        func make(
            _ name: String,
            category: ExerciseCategory,
            equipment: Equipment,
            pattern: MovementPattern,
            mode: WeightMode = .external,
            primary: [MuscleGroup] = [],
            secondary: [MuscleGroup] = [],
            goal: Bool = false,
            aliases: [(String, String?)] = []
        ) {
            let exercise = Exercise(
                canonicalName: name,
                category: category,
                equipment: equipment,
                movementPattern: pattern,
                defaultWeightMode: mode,
                primaryMuscles: primary,
                secondaryMuscles: secondary,
                isGoalExercise: goal
            )
            context.insert(exercise)
            for (aliasName, lang) in aliases {
                let alias = ExerciseAlias(aliasName: aliasName, languageOptional: lang, exercise: exercise)
                context.insert(alias)
            }
            created.append(exercise)
        }

        // Chest / push — includes the 100 kg bench-press goal exercise.
        make("Bench Press", category: .chest, equipment: .barbell, pattern: .horizontalPush,
             primary: [.chest], secondary: [.triceps, .frontDelts], goal: true,
             aliases: [("жим лежачи", "uk"), ("жим лёжа", "ru")])
        make("Incline Bench Press", category: .chest, equipment: .barbell, pattern: .horizontalPush,
             primary: [.chest], secondary: [.frontDelts, .triceps])
        make("Dumbbell Bench Press", category: .chest, equipment: .dumbbell, pattern: .horizontalPush,
             primary: [.chest], secondary: [.triceps, .frontDelts])
        make("Push-up", category: .chest, equipment: .bodyweight, pattern: .horizontalPush,
             mode: .bodyweight, primary: [.chest], secondary: [.triceps, .frontDelts])

        // Back / vertical pull — pull-up family (spec §16).
        make("Pull-up", category: .back, equipment: .bodyweight, pattern: .verticalPull,
             mode: .bodyweight, primary: [.lats], secondary: [.biceps, .upperBack],
             goal: true, aliases: [("підтягування", "uk"), ("подтягивания", "ru")])
        make("Chin-up", category: .back, equipment: .bodyweight, pattern: .verticalPull,
             mode: .bodyweight, primary: [.lats], secondary: [.biceps])
        make("Neutral-grip Pull-up", category: .back, equipment: .bodyweight, pattern: .verticalPull,
             mode: .bodyweight, primary: [.lats], secondary: [.biceps, .upperBack])
        make("Assisted Pull-up", category: .back, equipment: .assistedMachine, pattern: .verticalPull,
             mode: .assistedBodyweight, primary: [.lats], secondary: [.biceps])
        make("Band-assisted Pull-up", category: .back, equipment: .resistanceBand, pattern: .verticalPull,
             mode: .assistedBodyweight, primary: [.lats], secondary: [.biceps])
        make("Negative Pull-up", category: .back, equipment: .bodyweight, pattern: .verticalPull,
             mode: .bodyweight, primary: [.lats], secondary: [.biceps])
        make("Weighted Pull-up", category: .back, equipment: .bodyweight, pattern: .verticalPull,
             mode: .addedBodyweight, primary: [.lats], secondary: [.biceps, .upperBack])
        make("Scapular Pull-up", category: .back, equipment: .bodyweight, pattern: .verticalPull,
             mode: .bodyweight, primary: [.upperBack], secondary: [.lats])
        make("Dead Hang", category: .back, equipment: .bodyweight, pattern: .verticalPull,
             mode: .bodyweight, primary: [.forearms], secondary: [.lats])

        // Back / horizontal pull.
        make("Lat Pulldown", category: .back, equipment: .cable, pattern: .verticalPull,
             primary: [.lats], secondary: [.biceps],
             aliases: [("тяга блока", "uk"), ("тяга верхнего блока", "ru"), ("vertical pull machine", "en")])
        make("Seated Cable Row", category: .back, equipment: .cable, pattern: .horizontalPull,
             primary: [.upperBack], secondary: [.lats, .biceps])
        make("Barbell Row", category: .back, equipment: .barbell, pattern: .horizontalPull,
             primary: [.upperBack], secondary: [.lats, .biceps])
        make("Dumbbell Row", category: .back, equipment: .dumbbell, pattern: .horizontalPull,
             primary: [.lats], secondary: [.upperBack, .biceps])

        // Biceps (a stated growth goal).
        make("Barbell Curl", category: .biceps, equipment: .barbell, pattern: .curl,
             primary: [.biceps])
        make("Dumbbell Curl", category: .biceps, equipment: .dumbbell, pattern: .curl,
             primary: [.biceps], aliases: [("dumbbell curls", "en")])
        make("Hammer Curl", category: .biceps, equipment: .dumbbell, pattern: .curl,
             primary: [.biceps], secondary: [.forearms])
        make("Cable Curl", category: .biceps, equipment: .cable, pattern: .curl, primary: [.biceps])

        // Triceps / shoulders.
        make("Overhead Press", category: .shoulders, equipment: .barbell, pattern: .verticalPush,
             primary: [.frontDelts], secondary: [.triceps, .sideDelts])
        make("Lateral Raise", category: .shoulders, equipment: .dumbbell, pattern: .isolation,
             primary: [.sideDelts])
        make("Triceps Pushdown", category: .triceps, equipment: .cable, pattern: .extension_,
             primary: [.triceps])
        make("Dips", category: .triceps, equipment: .bodyweight, pattern: .verticalPush,
             mode: .bodyweight, primary: [.triceps], secondary: [.chest, .frontDelts])

        // Legs.
        make("Back Squat", category: .legs, equipment: .barbell, pattern: .squat,
             primary: [.quads], secondary: [.glutes, .hamstrings])
        make("Romanian Deadlift", category: .legs, equipment: .barbell, pattern: .hinge,
             primary: [.hamstrings], secondary: [.glutes, .lowerBack])
        make("Deadlift", category: .legs, equipment: .barbell, pattern: .hinge,
             primary: [.glutes, .hamstrings], secondary: [.lowerBack, .upperBack])
        make("Leg Press", category: .legs, equipment: .machine, pattern: .squat,
             primary: [.quads], secondary: [.glutes])

        // Core.
        make("Plank", category: .core, equipment: .bodyweight, pattern: .core,
             mode: .bodyweight, primary: [.abs])
        make("Hanging Leg Raise", category: .core, equipment: .bodyweight, pattern: .core,
             mode: .bodyweight, primary: [.abs], secondary: [.forearms])

        return created
    }
}
