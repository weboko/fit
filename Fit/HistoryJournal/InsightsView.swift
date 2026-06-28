import SwiftUI
import SwiftData
import Charts

/// Deterministic volume & frequency analytics over the user's finished workouts
/// (spec §15, §18). Shows training frequency, plus sets and volume per muscle
/// group over a selectable time range, using `StatsKit`. Charts only — no
/// recommendations, no projections, no AI.
struct InsightsView: View {

    /// The time window the analytics cover.
    private enum Range: String, CaseIterable, Identifiable {
        case days30
        case days90
        case year
        case all

        var id: String { rawValue }

        var label: String {
            switch self {
            case .days30: return "30d"
            case .days90: return "90d"
            case .year: return "1y"
            case .all: return "All"
            }
        }

        /// The inclusive start of the window, or `nil` for "all time".
        func start(now: Date = Date(), calendar: Calendar = .current) -> Date? {
            switch self {
            case .days30: return calendar.date(byAdding: .day, value: -30, to: now)
            case .days90: return calendar.date(byAdding: .day, value: -90, to: now)
            case .year: return calendar.date(byAdding: .year, value: -1, to: now)
            case .all: return nil
            }
        }

        /// Number of days spanned by the window, used for the weekly average.
        func days(now: Date = Date(), calendar: Calendar = .current, earliest: Date?) -> Int {
            let from: Date?
            switch self {
            case .all: from = earliest
            default: from = start(now: now, calendar: calendar)
            }
            guard let from else { return 0 }
            let days = calendar.dateComponents([.day], from: from, to: now).day ?? 0
            return max(days, 1)
        }
    }

    /// All sessions newest first; we filter to finished ones in memory so the
    /// predicate stays simple (predicates cannot call custom helpers).
    @Query(sort: \WorkoutSession.startTime, order: .reverse)
    private var sessions: [WorkoutSession]

    @State private var range: Range = .days90

    /// Number of muscle-group rows shown before collapsing the remainder.
    private let topMuscleLimit = 10

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.l) {
                rangePicker

                if filteredSessions.isEmpty {
                    EmptyStateView(
                        title: "No workouts in range",
                        message: "Finish a workout, or widen the time range, to see your training frequency and per-muscle volume here.",
                        systemImage: "chart.bar.xaxis"
                    )
                    .padding(.top, Theme.Spacing.xl)
                } else {
                    totalsCard
                    frequencyCard
                    volumeByMuscleCard
                    setsByMuscleCard
                }
            }
            .padding(Theme.Spacing.l)
        }
        .background(Color(.systemGroupedBackground))
    }

    // MARK: - Range picker

    private var rangePicker: some View {
        Picker("Time range", selection: $range) {
            ForEach(Range.allCases) { r in
                Text(r.label).tag(r)
            }
        }
        .pickerStyle(.segmented)
    }

    // MARK: - Totals

    private var totalsCard: some View {
        SectionCard("Totals", systemImage: "sum") {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())],
                      spacing: Theme.Spacing.m) {
                StatTile(value: "\(StatsKit.totalSets(workingSets))",
                         label: "Sets", systemImage: "number")
                StatTile(value: "\(StatsKit.totalReps(workingSets))",
                         label: "Reps", systemImage: "repeat")
                StatTile(value: Format.weight(StatsKit.totalVolumeKg(workingSets)),
                         label: "Volume", systemImage: "scalemass")
            }
            Text("Working sets only; warm-ups are excluded.")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Frequency

    private var frequencyCard: some View {
        SectionCard("Training frequency", systemImage: "calendar") {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())],
                      spacing: Theme.Spacing.m) {
                StatTile(value: "\(filteredSessions.count)",
                         label: "Workouts", systemImage: "figure.strengthtraining.traditional")
                StatTile(value: "\(StatsKit.workoutDays(filteredSessions))",
                         label: "Active days", systemImage: "calendar.badge.checkmark")
                StatTile(value: Format.decimal(averageWorkoutsPerWeek, maxFractionDigits: 1),
                         label: "Per week", systemImage: "chart.bar")
            }

            if weeklyPoints.count >= 1 {
                Chart(weeklyPoints) { point in
                    BarMark(
                        x: .value("Week", point.date, unit: .weekOfYear),
                        y: .value("Workouts", point.value)
                    )
                    .foregroundStyle(Theme.Palette.accent)
                }
                .chartYAxis {
                    AxisMarks(position: .leading, values: .automatic(desiredCount: 3)) { value in
                        AxisGridLine()
                        AxisValueLabel {
                            if let v = value.as(Double.self) {
                                Text(Format.decimal(v, maxFractionDigits: 0))
                            }
                        }
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                        AxisGridLine()
                        AxisValueLabel(format: .dateTime.month().day())
                    }
                }
                .frame(height: 160)
            }
        }
    }

    // MARK: - Volume by muscle group

    private var volumeByMuscleCard: some View {
        SectionCard("Volume by muscle group", systemImage: "chart.bar.xaxis") {
            let ranked = sortedVolume
            if ranked.isEmpty {
                Text("No tagged muscle groups in this range.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                let shown = Array(ranked.prefix(topMuscleLimit))
                Chart(shown, id: \.muscle) { item in
                    BarMark(
                        x: .value("Volume", item.value),
                        y: .value("Muscle", item.muscle.displayName)
                    )
                    .foregroundStyle(Theme.Palette.accent)
                    .annotation(position: .trailing, alignment: .leading) {
                        Text("\(Format.decimal(item.value)) kg")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: 3)) { value in
                        AxisGridLine()
                        AxisValueLabel {
                            if let v = value.as(Double.self) {
                                Text(Format.decimal(v, maxFractionDigits: 0))
                            }
                        }
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading) { _ in
                        AxisValueLabel()
                    }
                }
                .frame(height: chartHeight(for: shown.count))

                if ranked.count > topMuscleLimit {
                    Text("Showing top \(topMuscleLimit) of \(ranked.count) muscle groups.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: - Sets by muscle group

    private var setsByMuscleCard: some View {
        SectionCard("Sets by muscle group", systemImage: "list.number") {
            let ranked = sortedSets
            if ranked.isEmpty {
                Text("No tagged muscle groups in this range.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                let shown = Array(ranked.prefix(topMuscleLimit))
                Chart(shown, id: \.muscle) { item in
                    BarMark(
                        x: .value("Sets", item.value),
                        y: .value("Muscle", item.muscle.displayName)
                    )
                    .foregroundStyle(Theme.Palette.accent)
                    .annotation(position: .trailing, alignment: .leading) {
                        Text("\(item.value)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: 3)) { value in
                        AxisGridLine()
                        AxisValueLabel {
                            if let v = value.as(Int.self) {
                                Text("\(v)")
                            }
                        }
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading) { _ in
                        AxisValueLabel()
                    }
                }
                .frame(height: chartHeight(for: shown.count))

                if ranked.count > topMuscleLimit {
                    Text("Showing top \(topMuscleLimit) of \(ranked.count) muscle groups.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: - Derived data

    /// Finished sessions whose start falls within the selected range.
    private var filteredSessions: [WorkoutSession] {
        let finished = sessions.filter { !$0.isActive }
        guard let start = range.start() else { return finished }
        return finished.filter { $0.startTime >= start }
    }

    /// Working sets across the filtered sessions (warm-ups excluded upstream).
    private var workingSets: [WorkoutSet] {
        filteredSessions.flatMap { $0.workingSets }
    }

    private var weeklyPoints: [StatsKit.SessionPoint] {
        StatsKit.sessionsPerWeek(filteredSessions)
    }

    private var earliestSessionDate: Date? {
        filteredSessions.map(\.startTime).min()
    }

    private var averageWorkoutsPerWeek: Double {
        let days = range.days(earliest: earliestSessionDate)
        guard days > 0 else { return 0 }
        let weeks = Double(days) / 7.0
        guard weeks > 0 else { return 0 }
        return Double(filteredSessions.count) / weeks
    }

    private struct VolumeItem { let muscle: MuscleGroup; let value: Double }
    private struct SetsItem { let muscle: MuscleGroup; let value: Int }

    private var sortedVolume: [VolumeItem] {
        StatsKit.volumeByMuscleGroup(workingSets)
            .map { VolumeItem(muscle: $0.key, value: $0.value) }
            .sorted { $0.value > $1.value }
    }

    private var sortedSets: [SetsItem] {
        StatsKit.setsByMuscleGroup(workingSets)
            .map { SetsItem(muscle: $0.key, value: $0.value) }
            .sorted { $0.value > $1.value }
    }

    /// Keep horizontal bar charts readable: roughly one row of height per bar.
    private func chartHeight(for count: Int) -> CGFloat {
        CGFloat(max(count, 1)) * 28 + 24
    }
}

#Preview {
    NavigationStack {
        InsightsView()
            .navigationTitle("Insights")
    }
    .modelContainer(PersistenceController.makePreviewContainer())
}
