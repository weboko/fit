import Foundation
import SwiftData

/// Sample data for SwiftUI previews and manual testing. Never used in the
/// shipping app path.
enum PreviewData {

    /// Populates a context with a couple of realistic workouts so previews of
    /// history, exercise detail and export have something to show.
    static func populate(_ context: ModelContext) {
        SeedData.seedIfNeeded(in: context)

        let exercises = (try? context.fetch(FetchDescriptor<Exercise>())) ?? []
        func exercise(_ name: String) -> Exercise? {
            exercises.first { $0.canonicalName == name }
        }

        guard let bench = exercise("Bench Press"),
              let pullup = exercise("Assisted Pull-up") else { return }

        let calendar = Calendar.current

        // A finished session three days ago.
        let start = calendar.date(byAdding: .day, value: -3, to: Date()) ?? Date()
        let session = WorkoutSession(title: "Push day", startTime: start,
                                     endTime: start.addingTimeInterval(65 * 60))
        session.goal = .strength
        session.location = .gym
        session.energyBefore = 4
        session.sleepQualitySubjective = .good
        session.bodyWeightManualKg = 82
        context.insert(session)

        func addSet(_ exercise: Exercise, index: Int, weight: Double?, reps: Int, effort: Int,
                    mode: WeightMode = .external, assist: Double? = nil, bw: Double? = nil, warmup: Bool = false) {
            let set = WorkoutSet(exercise: exercise, exerciseNameAtTime: exercise.canonicalName,
                                 setIndex: index, timestamp: start.addingTimeInterval(Double(index) * 180),
                                 weightMode: mode)
            set.weightKg = weight
            set.reps = reps
            set.effort = effort
            set.isWarmup = warmup
            set.assistanceKg = assist
            set.bodyWeightKg = bw
            set.workout = session
            context.insert(set)
        }

        addSet(bench, index: 0, weight: 40, reps: 10, effort: 1, warmup: true)
        addSet(bench, index: 1, weight: 60, reps: 8, effort: 2)
        addSet(bench, index: 2, weight: 70, reps: 6, effort: 3)
        addSet(bench, index: 3, weight: 80, reps: 4, effort: 4)
        addSet(pullup, index: 4, weight: nil, reps: 6, effort: 4, mode: .assistedBodyweight, assist: 20, bw: 82)
        addSet(pullup, index: 5, weight: nil, reps: 5, effort: 5, mode: .assistedBodyweight, assist: 20, bw: 82)

        let journal = JournalEntry(workout: session, entryType: .workoutNote,
                                   text: "Bench felt strong. Pull-ups hard, grip okay.")
        context.insert(journal)

        try? context.save()
    }
}
