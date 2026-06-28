import SwiftUI
import SwiftData

/// The "Today" tab entry point (spec §6, §14.1). If a workout is in progress
/// (a `WorkoutSession` with `endTime == nil`) it shows the live workout;
/// otherwise it shows a big Start button plus quick context (last workout) and a
/// link to History for backfilling a past workout.
struct TodayView: View {
    @Environment(\.modelContext) private var context

    @Query(sort: \WorkoutSession.startTime, order: .reverse)
    private var sessions: [WorkoutSession]

    @State private var showStartConfirm = false

    private var activeSession: WorkoutSession? {
        WorkoutLoggingHelpers.activeSession(in: sessions)
    }

    private var lastFinished: WorkoutSession? {
        sessions.first { $0.endTime != nil }
    }

    var body: some View {
        NavigationStack {
            Group {
                if let active = activeSession {
                    ActiveWorkoutView(session: active)
                } else {
                    startScreen
                }
            }
        }
    }

    // MARK: - Start screen

    private var startScreen: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.xl) {
                header

                Button {
                    start()
                } label: {
                    Label("Start Workout", systemImage: "play.fill")
                        .font(.title3.weight(.bold))
                        .frame(maxWidth: .infinity, minHeight: Theme.Size.bigControlHeight)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                if let last = lastFinished {
                    lastWorkoutCard(last)
                }

                backfillLink

                Spacer(minLength: Theme.Spacing.xl)
            }
            .padding(Theme.Spacing.l)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Today")
    }

    private var header: some View {
        VStack(spacing: Theme.Spacing.s) {
            Image(systemName: "figure.strengthtraining.traditional")
                .font(.system(size: 56))
                .foregroundStyle(Color.accentColor)
                .padding(.top, Theme.Spacing.xl)
            Text(greeting)
                .font(.title2.weight(.bold))
            Text("Ready to train?")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12: return "Good morning"
        case 12..<17: return "Good afternoon"
        case 17..<22: return "Good evening"
        default: return "Late session"
        }
    }

    private func lastWorkoutCard(_ session: WorkoutSession) -> some View {
        SectionCard("Last workout", systemImage: "clock.arrow.circlepath") {
            VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                DetailRow(label: "When", value: Format.relativeDay(session.startTime))
                DetailRow(label: "Duration", value: Format.durationCompact(session.duration))
                DetailRow(label: "Exercises", value: "\(session.exercisesInOrder.count)")
                DetailRow(label: "Working sets", value: "\(StatsKit.totalSets(session.orderedSets))")
                if !session.exercisesInOrder.isEmpty {
                    Divider()
                    Text(session.exercisesInOrder.map(\.canonicalName).joined(separator: " · "))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var backfillLink: some View {
        VStack(spacing: Theme.Spacing.s) {
            Text("Forgot to log something?")
                .font(.footnote)
                .foregroundStyle(.secondary)
            Text("Add a past workout from the History tab.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, Theme.Spacing.m)
    }

    // MARK: - Actions

    private func start() {
        WorkoutLoggingHelpers.startSession(in: context)
    }
}

#Preview("With active workout") {
    let container = PersistenceController.makePreviewContainer()
    let context = container.mainContext
    let exercises = (try? context.fetch(FetchDescriptor<Exercise>())) ?? []
    let session = WorkoutSession(title: "Today", startTime: Date().addingTimeInterval(-12 * 60))
    context.insert(session)
    if let bench = exercises.first(where: { $0.canonicalName == "Bench Press" }) {
        let s = WorkoutSet(exercise: bench, exerciseNameAtTime: bench.canonicalName, setIndex: 0)
        s.weightKg = 60; s.reps = 8; s.effort = 2; s.workout = session
        context.insert(s)
    }
    try? context.save()
    return TodayView()
        .modelContainer(container)
}

#Preview("Start screen") {
    // Preview container without an active session (PreviewData's session is finished).
    TodayView()
        .modelContainer(PersistenceController.makePreviewContainer())
}
