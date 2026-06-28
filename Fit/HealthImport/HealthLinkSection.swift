import SwiftUI
import SwiftData
import HealthKit
import Foundation

/// A section that ties a manual `WorkoutSession` to an imported Apple Health
/// workout. Shows the currently linked one (with an unlink button) and lists any
/// already-imported Health workouts whose time window overlaps the session,
/// offering to link them. Consumed by the WorkoutLogging finish screen and the
/// HistoryJournal workout detail.
///
/// It only links against workouts already imported into SwiftData — importing
/// itself lives in `HealthSettingsSection` / `ImportHealthDataView`. If nothing
/// overlaps it guides the user there.
struct HealthLinkSection: View {
    @Environment(\.modelContext) private var context
    @StateObject private var service = HealthImportService()

    @Bindable private var session: WorkoutSession

    /// All imported health workouts; filtered for overlap in `suggestions`.
    @Query(sort: \HealthWorkout.startTime, order: .reverse)
    private var allHealthWorkouts: [HealthWorkout]

    init(session: WorkoutSession) {
        self._session = Bindable(wrappedValue: session)
    }

    private var linked: HealthWorkout? { session.linkedHealthWorkout }

    /// Overlapping, link-available suggestions excluding the current link.
    private var suggestions: [HealthWorkout] {
        allHealthWorkouts.filter { hw in
            hw.overlaps(session: session)
                && hw.id != linked?.id
                && (hw.linkedSession == nil || hw.linkedSession?.id == session.id)
        }
    }

    var body: some View {
        SectionCard("Apple Health", systemImage: "heart.text.square") {
            if let linked {
                linkedView(linked)
            } else if suggestions.isEmpty {
                emptyView
            } else {
                suggestionsView
            }
        }
    }

    // MARK: Linked

    @ViewBuilder
    private func linkedView(_ hw: HealthWorkout) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            HStack {
                Text("Linked workout")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                SourceBadge(text: "Apple Health", systemImage: "heart.fill", tint: .pink)
            }

            HealthWorkoutSummaryRow(workout: hw)

            Button(role: .destructive) {
                service.unlink(from: session, in: context)
            } label: {
                Label("Unlink", systemImage: "link.badge.minus")
            }
            .buttonStyle(.bordered)
        }
    }

    // MARK: Suggestions

    private var suggestionsView: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            Text(suggestions.count == 1
                 ? "1 Apple Health workout overlaps this session."
                 : "\(suggestions.count) Apple Health workouts overlap this session.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            ForEach(suggestions) { hw in
                VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                    HealthWorkoutSummaryRow(workout: hw)
                    Button {
                        service.link(hw, to: session, in: context)
                    } label: {
                        Label("Link this workout", systemImage: "link")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding(.vertical, Theme.Spacing.xs)
            }
        }
    }

    // MARK: Empty

    private var emptyView: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            Text("No imported Apple Health workouts overlap this session.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            if HealthImportService.isAvailable {
                NavigationLink {
                    ImportHealthDataView()
                } label: {
                    Label("Import from Apple Health", systemImage: "square.and.arrow.down")
                }
            } else {
                Text("Apple Health is not available on this device.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

/// Compact, reusable summary of one `HealthWorkout` (type, time, duration,
/// energy, heart rate). Used by the link section and the import browser.
struct HealthWorkoutSummaryRow: View {
    let workout: HealthWorkout

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            HStack(spacing: Theme.Spacing.s) {
                Image(systemName: "heart.text.square")
                    .foregroundStyle(.pink)
                Text(workout.workoutType.isEmpty ? "Workout" : workout.workoutType)
                    .font(.headline)
                Spacer()
                Text(Format.durationCompact(workout.durationSeconds))
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
            }

            Text(timeRange)
                .font(.footnote)
                .foregroundStyle(.secondary)

            HStack(spacing: Theme.Spacing.l) {
                if let kcal = workout.activeEnergyKcal {
                    metric(systemImage: "flame.fill",
                           text: "\(Format.decimal(kcal, maxFractionDigits: 0)) kcal",
                           tint: .orange)
                }
                if let avg = workout.avgHeartRateBpm {
                    metric(systemImage: "heart.fill",
                           text: "\(Format.decimal(avg, maxFractionDigits: 0)) bpm",
                           tint: .red)
                }
                if let maxHr = workout.maxHeartRateBpm {
                    metric(systemImage: "arrow.up.heart",
                           text: "\(Format.decimal(maxHr, maxFractionDigits: 0)) max",
                           tint: .red)
                }
            }
            .font(.footnote)

            if let source = workout.sourceName, !source.isEmpty {
                Text(source)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func metric(systemImage: String, text: String, tint: Color) -> some View {
        Label(text, systemImage: systemImage)
            .foregroundStyle(tint)
            .labelStyle(.titleAndIcon)
    }

    private var timeRange: String {
        let start = workout.startTime.formatted(.dateTime.weekday().month().day().hour().minute())
        let end = workout.endTime.formatted(.dateTime.hour().minute())
        return "\(start) – \(end)"
    }
}

#Preview {
    let container = PersistenceController.makePreviewContainer()
    let session = WorkoutSession(title: "Preview session",
                                 startTime: Date().addingTimeInterval(-3600),
                                 endTime: Date())
    container.mainContext.insert(session)

    let hw = HealthWorkout(
        appleHealthUUID: UUID().uuidString,
        workoutType: "Strength Training",
        startTime: Date().addingTimeInterval(-3500),
        endTime: Date().addingTimeInterval(-300),
        durationSeconds: 3200
    )
    hw.activeEnergyKcal = 410
    hw.avgHeartRateBpm = 128
    hw.maxHeartRateBpm = 162
    hw.sourceName = "Apple Watch"
    container.mainContext.insert(hw)

    return NavigationStack {
        ScrollView {
            HealthLinkSection(session: session)
                .padding()
        }
    }
    .modelContainer(container)
}
