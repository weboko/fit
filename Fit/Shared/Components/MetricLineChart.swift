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
        }
    }
}
