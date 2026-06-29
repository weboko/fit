import WidgetKit
import SwiftUI

// MARK: - Timeline entry

/// One timeline entry: a snapshot read at a point in time. The widget is
/// refreshed explicitly by the app (`WidgetCenter.reloadAllTimelines()`) when a
/// workout finishes, so a single far-future-expiring entry is sufficient.
struct FitEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot?
}

// MARK: - Timeline provider

struct FitProvider: TimelineProvider {
    /// Shown in the widget gallery / while data loads. Deterministic sample.
    func placeholder(in context: Context) -> FitEntry {
        FitEntry(date: Date(), snapshot: Self.sample)
    }

    /// A single representative entry (gallery snapshot uses sample data, the
    /// real widget reads the shared store).
    func getSnapshot(in context: Context, completion: @escaping (FitEntry) -> Void) {
        let snapshot = context.isPreview ? Self.sample : SharedStore.load()
        completion(FitEntry(date: Date(), snapshot: snapshot))
    }

    /// One entry, never auto-expiring — the app drives reloads on finish/launch.
    func getTimeline(in context: Context, completion: @escaping (Timeline<FitEntry>) -> Void) {
        let entry = FitEntry(date: Date(), snapshot: SharedStore.load())
        completion(Timeline(entries: [entry], policy: .never))
    }

    /// Sample data for the gallery placeholder / previews.
    static let sample = WidgetSnapshot(
        lastWorkoutTitle: "Push Day",
        lastWorkoutDate: Calendar.current.date(byAdding: .day, value: -1, to: Date()),
        weeklyStreak: 5,
        topSetSummary: "Bench Press 80 kg × 6"
    )
}

// MARK: - View

struct FitWidgetEntryView: View {
    var entry: FitEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        Group {
            if let snapshot = entry.snapshot, hasContent(snapshot) {
                content(for: snapshot)
            } else {
                emptyState
            }
        }
        .containerBackground(.fill.tertiary, for: .widget)
    }

    private func hasContent(_ snapshot: WidgetSnapshot) -> Bool {
        snapshot.lastWorkoutTitle != nil || snapshot.weeklyStreak > 0
    }

    @ViewBuilder
    private func content(for snapshot: WidgetSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("Fit", systemImage: "figure.strengthtraining.traditional")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)

            if let title = snapshot.lastWorkoutTitle {
                Text(title)
                    .font(.headline)
                    .lineLimit(1)
                if let date = snapshot.lastWorkoutDate {
                    Text(date, format: .relative(presentation: .named))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            } else {
                Text("Last workout")
                    .font(.headline)
            }

            if family == .systemMedium, let top = snapshot.topSetSummary {
                Text(top)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)

            if snapshot.weeklyStreak > 0 {
                Text("🔥 \(snapshot.weeklyStreak)-week streak")
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("Fit", systemImage: "figure.strengthtraining.traditional")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
            Spacer(minLength: 0)
            Text("No workouts yet")
                .font(.headline)
            Text("Log a workout to see it here.")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}

// MARK: - Widget

struct FitWidget: Widget {
    let kind = "FitWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: FitProvider()) { entry in
            FitWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Last Workout")
        .description("Your most recent workout and current weekly training streak.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// MARK: - Previews

#Preview(as: .systemSmall) {
    FitWidget()
} timeline: {
    FitEntry(date: Date(), snapshot: FitProvider.sample)
    FitEntry(date: Date(), snapshot: nil)
}

#Preview(as: .systemMedium) {
    FitWidget()
} timeline: {
    FitEntry(date: Date(), snapshot: FitProvider.sample)
}
