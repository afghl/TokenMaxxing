import Charts
import SwiftUI
import TokenMaxxingCore

struct TokenUsageChart: View {
    let range: UsageRange
    let points: [TokenUsagePoint]
    let intradayComparison: IntradayUsageComparison

    private var maxTokens: Int {
        let comparisonPoints = intradayComparison.currentUsage + intradayComparison.averageUsage
        let candidates = range == .day ? comparisonPoints : points
        return max(candidates.map(\.tokens).max() ?? 1, 1)
    }

    var body: some View {
        switch range {
        case .day:
            dayComparisonChart
        case .month, .year:
            styledChart(barChart)
        }
    }

    private var dayComparisonChart: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 48) {
                UsageComparisonValue(
                    title: "Today",
                    value: intradayComparison.currentTotal,
                    tint: HomePalette.tokenAccent
                )

                UsageComparisonValue(
                    title: "Average",
                    value: intradayComparison.averageTotal,
                    tint: HomePalette.averageLine
                )
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            dayComparisonPlot
                .frame(height: 290)
        }
    }

    private var dayComparisonPlot: some View {
        Chart {
            ForEach(averageUsageThroughReference) { item in
                LineMark(
                    x: .value("Time", item.date),
                    y: .value("Average", item.tokens),
                    series: .value("Series", "Average elapsed")
                )
                .interpolationMethod(.linear)
                .lineStyle(.init(lineWidth: 3, lineCap: .round, lineJoin: .miter))
                .foregroundStyle(HomePalette.averageLine.opacity(0.42))
            }

            ForEach(averageUsageAfterReference) { item in
                LineMark(
                    x: .value("Time", item.date),
                    y: .value("Average", item.tokens),
                    series: .value("Series", "Average future")
                )
                .interpolationMethod(.linear)
                .lineStyle(.init(lineWidth: 3, lineCap: .round, lineJoin: .miter))
                .foregroundStyle(HomePalette.averageLine.opacity(0.16))
            }

            if let comparisonConnector {
                RuleMark(
                    x: .value("Current Time", comparisonReferenceDate),
                    yStart: .value("Lower Value", comparisonConnector.lower),
                    yEnd: .value("Upper Value", comparisonConnector.upper)
                )
                .lineStyle(.init(lineWidth: 2, lineCap: .round))
                .foregroundStyle(HomePalette.averageLine.opacity(0.24))
            }

            ForEach(currentUsageThroughReference) { item in
                AreaMark(
                    x: .value("Time", item.date),
                    y: .value("Today", item.tokens)
                )
                .interpolationMethod(.linear)
                .foregroundStyle(
                    LinearGradient(
                        colors: [
                            HomePalette.tokenAccent.opacity(0.25),
                            HomePalette.tokenAccent.opacity(0.02),
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

                LineMark(
                    x: .value("Time", item.date),
                    y: .value("Today", item.tokens),
                    series: .value("Series", "Today")
                )
                .interpolationMethod(.linear)
                .lineStyle(.init(lineWidth: 3, lineCap: .round, lineJoin: .miter))
                .foregroundStyle(HomePalette.tokenAccent)
            }

            if let averageReferencePoint {
                PointMark(
                    x: .value("Time", averageReferencePoint.date),
                    y: .value("Average", averageReferencePoint.tokens)
                )
                .symbolSize(82)
                .foregroundStyle(HomePalette.averageLine.opacity(0.62))
            }

            if let currentReferencePoint {
                PointMark(
                    x: .value("Time", currentReferencePoint.date),
                    y: .value("Today", currentReferencePoint.tokens)
                )
                .symbolSize(82)
                .foregroundStyle(HomePalette.tokenAccent)
            }
        }
        .chartXScale(domain: intradayComparison.dayStart...intradayComparison.dayEnd)
        .chartYScale(domain: 0...(Double(maxTokens) * 1.18))
        .chartXAxis {
            AxisMarks(values: dayAxisValues) { value in
                AxisTick()
                    .foregroundStyle(.secondary.opacity(0.3))

                if let date = value.as(Date.self) {
                    AxisValueLabel {
                        Text(dayAxisLabel(for: date))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .chartYAxis(.hidden)
        .chartPlotStyle { plotArea in
            plotArea
                .background(.clear)
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

    private var dayAxisValues: [Date] {
        let calendar = Calendar.current
        let hourlyValues = (0...24).compactMap { hour in
            calendar.date(byAdding: .hour, value: hour, to: intradayComparison.dayStart)
        }

        var valuesByMinute: [Int: Date] = [:]
        for value in hourlyValues {
            let minuteOffset = calendar.dateComponents(
                [.minute],
                from: intradayComparison.dayStart,
                to: value
            ).minute ?? 0
            valuesByMinute[minuteOffset] = value
        }

        let referenceMinuteOffset = calendar.dateComponents(
            [.minute],
            from: intradayComparison.dayStart,
            to: comparisonReferenceDate
        ).minute ?? 0
        valuesByMinute[referenceMinuteOffset] = comparisonReferenceDate

        return valuesByMinute.values.sorted()
    }

    private var comparisonReferenceDate: Date {
        min(
            max(intradayComparison.referenceDate, intradayComparison.dayStart),
            intradayComparison.dayEnd
        )
    }

    private var currentUsageThroughReference: [TokenUsagePoint] {
        usage(intradayComparison.currentUsage, through: comparisonReferenceDate)
    }

    private var averageUsageThroughReference: [TokenUsagePoint] {
        usage(intradayComparison.averageUsage, through: comparisonReferenceDate)
    }

    private var averageUsageAfterReference: [TokenUsagePoint] {
        usage(intradayComparison.averageUsage, startingAt: comparisonReferenceDate)
    }

    private var currentReferencePoint: TokenUsagePoint? {
        point(in: intradayComparison.currentUsage, at: comparisonReferenceDate)
    }

    private var averageReferencePoint: TokenUsagePoint? {
        point(in: intradayComparison.averageUsage, at: comparisonReferenceDate)
    }

    private var comparisonConnector: (lower: Int, upper: Int)? {
        guard let currentReferencePoint, let averageReferencePoint else {
            return nil
        }

        return (
            lower: min(currentReferencePoint.tokens, averageReferencePoint.tokens),
            upper: max(currentReferencePoint.tokens, averageReferencePoint.tokens)
        )
    }

    private func usage(_ points: [TokenUsagePoint], through date: Date) -> [TokenUsagePoint] {
        guard let referencePoint = point(in: points, at: date) else {
            return []
        }

        return points.filter { $0.date < date } + [referencePoint]
    }

    private func usage(_ points: [TokenUsagePoint], startingAt date: Date) -> [TokenUsagePoint] {
        guard let referencePoint = point(in: points, at: date) else {
            return []
        }

        return [referencePoint] + points.filter { $0.date > date }
    }

    private func point(in points: [TokenUsagePoint], at date: Date) -> TokenUsagePoint? {
        guard let firstPoint = points.first else {
            return nil
        }

        if date <= firstPoint.date {
            return TokenUsagePoint(date: date, tokens: firstPoint.tokens)
        }

        guard let upperIndex = points.firstIndex(where: { $0.date > date }) else {
            return TokenUsagePoint(date: date, tokens: points.last?.tokens ?? 0)
        }

        let lowerPoint = points[points.index(before: upperIndex)]
        let upperPoint = points[upperIndex]
        let interval = upperPoint.date.timeIntervalSince(lowerPoint.date)

        guard interval > 0 else {
            return TokenUsagePoint(date: date, tokens: lowerPoint.tokens)
        }

        let progress = date.timeIntervalSince(lowerPoint.date) / interval
        let tokens = Double(lowerPoint.tokens)
            + (Double(upperPoint.tokens - lowerPoint.tokens) * progress)
        return TokenUsagePoint(date: date, tokens: Int(tokens.rounded()))
    }

    private func dayAxisLabel(for date: Date) -> String {
        let minuteOffset = Calendar.current.dateComponents(
            [.minute],
            from: intradayComparison.dayStart,
            to: date
        ).minute ?? 0

        if minuteOffset % 60 == 0 {
            return "\(minuteOffset / 60)"
        }

        return date.formatted(.dateTime.hour(.twoDigits(amPM: .omitted)).minute(.twoDigits))
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

private struct UsageComparisonValue: View {
    let title: String
    let value: Int
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(title, systemImage: "circle.fill")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(tint)

            HStack(alignment: .firstTextBaseline, spacing: 5) {
                Text(formattedValue)
                    .font(.system(size: 46, weight: .bold, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.65)

                Text("tokens")
                    .font(.system(size: 18, weight: .semibold))
            }
            .foregroundStyle(tint)
        }
        .frame(width: 240, alignment: .leading)
    }

    private var formattedValue: String {
        let absoluteValue = abs(value)

        switch absoluteValue {
        case 1_000_000...:
            return compactValue(divisor: 1_000_000, suffix: "M")
        case 1_000...:
            return value.formatted()
        default:
            return value.formatted()
        }
    }

    private func compactValue(divisor: Double, suffix: String) -> String {
        let scaled = Double(value) / divisor
        let formatted = String(format: "%.1f", scaled)
            .replacingOccurrences(of: ".0", with: "")
        return "\(formatted)\(suffix)"
    }
}
