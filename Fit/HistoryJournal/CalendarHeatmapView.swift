import SwiftUI
import SwiftData

/// A GitHub-style contribution heatmap of training days over the recent past
/// (spec §15, §18). Each cell is one calendar day; its colour ramps with the
/// number of finished workouts logged that day. Deterministic only — it just
/// counts finished sessions, no projections or recommendations.
///
/// Layout: 7 rows (weekdays) × N week columns. The oldest week is on the left,
/// the most recent week on the right, so the rightmost column is the current
/// week. Self-contained: all counting happens inline, StatsKit is untouched.
struct CalendarHeatmapView: View {

    /// All sessions newest first; finished ones are filtered in memory so the
    /// predicate stays simple (predicates cannot call custom helpers).
    @Query(sort: \WorkoutSession.startTime, order: .reverse)
    private var sessions: [WorkoutSession]

    /// How many weeks of history to show (≈18 weeks).
    private let weekCount = 18

    /// Side length of each day cell, in points.
    private let cellSize: CGFloat = 13

    /// Gap between cells (and between week columns).
    private let cellSpacing: CGFloat = 3

    /// Workouts-per-day at which the green ramp reaches its strongest shade.
    private let intensityCap = 3

    var body: some View {
        SectionCard("Training calendar", systemImage: "calendar") {
            let model = makeModel()

            VStack(alignment: .leading, spacing: Theme.Spacing.m) {
                ScrollViewReader { proxy in
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(alignment: .top, spacing: cellSpacing) {
                            ForEach(model.weeks) { week in
                                weekColumn(week)
                                    .id(week.id)
                            }
                        }
                    }
                    .onAppear {
                        // Keep the current (rightmost) week in view on open.
                        if let last = model.weeks.last {
                            proxy.scrollTo(last.id, anchor: .trailing)
                        }
                    }
                }

                legend

                Text("Workouts in the last \(weekCount) weeks.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Subviews

    private func weekColumn(_ week: HeatmapWeek) -> some View {
        VStack(spacing: cellSpacing) {
            ForEach(week.days) { day in
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(color(forCount: day.count))
                    .frame(width: cellSize, height: cellSize)
                    .accessibilityLabel(accessibilityLabel(for: day))
            }
        }
    }

    private var legend: some View {
        HStack(spacing: cellSpacing) {
            Text("Less")
                .font(.caption2)
                .foregroundStyle(.secondary)
            ForEach(legendCounts, id: \.self) { count in
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(color(forCount: count))
                    .frame(width: cellSize - 2, height: cellSize - 2)
            }
            Text("More")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Colour ramp

    /// The sample counts shown in the legend, from empty to the cap.
    private var legendCounts: [Int] { Array(0...intensityCap) }

    /// Faint gray for a rest day, otherwise a green ramp that deepens with the
    /// number of workouts and is capped so a heavy day cannot oversaturate.
    private func color(forCount count: Int) -> Color {
        guard count > 0 else { return Theme.Palette.subtle }
        let clamped = min(count, intensityCap)
        // Map 1...cap onto a comfortable 0.35...1.0 opacity range.
        let fraction = Double(clamped) / Double(intensityCap)
        let opacity = 0.35 + 0.65 * fraction
        return Color.green.opacity(opacity)
    }

    private func accessibilityLabel(for day: HeatmapDay) -> String {
        let dateText = day.date.formatted(.dateTime.month().day())
        switch day.count {
        case 0: return "\(dateText): rest day"
        case 1: return "\(dateText): 1 workout"
        default: return "\(dateText): \(day.count) workouts"
        }
    }

    // MARK: - Model construction

    /// Builds the week/day grid by counting finished workouts per calendar day
    /// over the trailing window. Pure function of `sessions` + the clock, so the
    /// render is deterministic for a given store and day.
    private func makeModel(now: Date = Date(), calendar: Calendar = .current) -> HeatmapModel {
        // Count finished workouts per start-of-day.
        var countsByDay: [Date: Int] = [:]
        for session in sessions where !session.isActive {
            let day = calendar.startOfDay(for: session.startTime)
            countsByDay[day, default: 0] += 1
        }

        // The grid ends with the week containing today. Find the start of the
        // current week, then walk back `weekCount - 1` weeks for the first cell.
        let today = calendar.startOfDay(for: now)
        let weekday = calendar.component(.weekday, from: today)
        let daysFromWeekStart = (weekday - calendar.firstWeekday + 7) % 7
        guard
            let currentWeekStart = calendar.date(byAdding: .day, value: -daysFromWeekStart, to: today),
            let gridStart = calendar.date(byAdding: .weekOfYear, value: -(weekCount - 1), to: currentWeekStart)
        else {
            return HeatmapModel(weeks: [])
        }

        var weeks: [HeatmapWeek] = []
        weeks.reserveCapacity(weekCount)
        for weekIndex in 0..<weekCount {
            guard let weekStart = calendar.date(byAdding: .day, value: weekIndex * 7, to: gridStart) else { continue }
            var days: [HeatmapDay] = []
            days.reserveCapacity(7)
            for dayOffset in 0..<7 {
                guard let date = calendar.date(byAdding: .day, value: dayOffset, to: weekStart) else { continue }
                // Future days (in the current week) get no fill but keep their slot.
                let count = date <= today ? (countsByDay[date] ?? 0) : 0
                days.append(HeatmapDay(date: date, count: count))
            }
            weeks.append(HeatmapWeek(weekStart: weekStart, days: days))
        }
        return HeatmapModel(weeks: weeks)
    }
}

// MARK: - Grid value types

/// One day cell: its date (start-of-day) and finished-workout count.
private struct HeatmapDay: Identifiable {
    let date: Date
    let count: Int
    var id: Date { date }
}

/// One column: a week starting on `weekStart`, with its seven day cells.
private struct HeatmapWeek: Identifiable {
    let weekStart: Date
    let days: [HeatmapDay]
    var id: Date { weekStart }
}

/// The full grid, oldest week first.
private struct HeatmapModel {
    let weeks: [HeatmapWeek]
}

#Preview {
    NavigationStack {
        ScrollView {
            CalendarHeatmapView()
                .padding(Theme.Spacing.l)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Insights")
    }
    .modelContainer(PersistenceController.makePreviewContainer())
}
