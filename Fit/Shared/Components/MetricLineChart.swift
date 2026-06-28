import SwiftUI
import Charts

/// A simple deterministic line/point chart over `StatsKit.SessionPoint` values.
/// Used for bench/pull-up progress and volume trends. No AI, no projections —
/// it just plots what was logged (spec §15, §17, §18).
struct MetricLineChart: View {
    let points: [StatsKit.SessionPoint]
    var unitSuffix: String = ""
    var tint: Color = .accentColor

    var body: some View {
        if points.count < 2 {
            Text("Not enough data yet to chart.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, minHeight: 80)
        } else {
            Chart(points) { point in
                LineMark(
                    x: .value("Date", point.date),
                    y: .value("Value", point.value)
                )
                .interpolationMethod(.monotone)
                .foregroundStyle(tint)

                PointMark(
                    x: .value("Date", point.date),
                    y: .value("Value", point.value)
                )
                .foregroundStyle(tint)
            }
            .chartYAxis {
                AxisMarks { value in
                    AxisGridLine()
                    AxisValueLabel {
                        if let v = value.as(Double.self) {
                            Text("\(Format.decimal(v))\(unitSuffix)")
                        }
                    }
                }
            }
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 4)) { value in
                    AxisGridLine()
                    AxisValueLabel(format: .dateTime.month().day())
                }
            }
            .frame(height: 180)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Trend chart")
            .accessibilityValue(accessibilitySummary)
        }
    }

    /// A concise spoken summary of the plotted trend (first/last values and
    /// direction) so VoiceOver users get the gist without exploring every point.
    private var accessibilitySummary: String {
        guard let first = points.first, let last = points.last else { return "No data" }
        let direction: String
        if last.value > first.value { direction = "up" }
        else if last.value < first.value { direction = "down" }
        else { direction = "flat" }
        let from = "\(Format.decimal(first.value))\(unitSuffix)"
        let to = "\(Format.decimal(last.value))\(unitSuffix)"
        return "\(points.count) points, trending \(direction), from \(from) to \(to)"
    }
}
