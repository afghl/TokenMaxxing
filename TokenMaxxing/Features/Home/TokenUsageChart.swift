import Charts
import SwiftUI
import TokenMaxxingCore

struct TokenUsageChart: View {
    let range: UsageRange
    let points: [TokenUsagePoint]

    private var maxTokens: Int {
        max(points.map(\.tokens).max() ?? 1, 1)
    }

    var body: some View {
        switch range {
        case .day:
            styledChart(dayChart)
        case .month, .year:
            styledChart(barChart)
        }
    }

    private var dayChart: some View {
        Chart(points) { item in
            AreaMark(
                x: .value("Time", item.date),
                y: .value("Tokens", item.tokens)
            )
            .interpolationMethod(.catmullRom)
            .foregroundStyle(
                LinearGradient(
                    colors: [HomePalette.tokenAccent.opacity(0.35), HomePalette.tokenAccent.opacity(0.03)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )

            LineMark(
                x: .value("Time", item.date),
                y: .value("Tokens", item.tokens)
            )
            .interpolationMethod(.linear)
            .lineStyle(.init(lineWidth: 3, lineCap: .butt, lineJoin: .miter))
            .foregroundStyle(HomePalette.tokenAccent)
        }
    }

    private var barChart: some View {
        Chart(points) { item in
            BarMark(
                x: .value("Date", item.date),
                y: .value("Tokens", item.tokens)
            )
            .foregroundStyle(HomePalette.tokenAccent.gradient)
            .cornerRadius(4)
        }
    }

    private func styledChart(_ chart: some View) -> some View {
        chart
            .chartYScale(domain: 0...(Double(maxTokens) * 1.18))
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: range == .day ? 6 : 5)) { value in
                    AxisGridLine()
                        .foregroundStyle(.secondary.opacity(0.22))
                    AxisTick()
                        .foregroundStyle(.secondary.opacity(0.35))

                    if let date = value.as(Date.self) {
                        AxisValueLabel {
                            Text(axisLabel(for: date))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) {
                    AxisGridLine()
                        .foregroundStyle(.secondary.opacity(0.18))
                    AxisValueLabel()
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
    }

    private func axisLabel(for date: Date) -> String {
        switch range {
        case .day:
            date.formatted(.dateTime.hour(.defaultDigits(amPM: .omitted)))
        case .month:
            date.formatted(.dateTime.day())
        case .year:
            date.formatted(.dateTime.month(.abbreviated))
        }
    }
}
