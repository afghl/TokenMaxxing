import Observation

struct HourlyTokenUsage: Identifiable {
    let hour: Int
    let tokens: Int

    var id: Int { hour }
}

enum UsageChartStyle {
    case line
    case bar

    var title: String {
        switch self {
        case .line:
            "Line Chart"
        case .bar:
            "Bar Chart"
        }
    }

    var toggleTitle: String {
        switch self {
        case .line:
            "Show Bar Chart"
        case .bar:
            "Show Line Chart"
        }
    }

    var toggleIconName: String {
        switch self {
        case .line:
            "chart.bar"
        case .bar:
            "chart.line.uptrend.xyaxis"
        }
    }
}

@Observable
final class UsageDashboardState {
    var message = "Hello, TokenMaxing"
    var chartStyle: UsageChartStyle = .line

    let hourlyUsage: [HourlyTokenUsage] = [
        .init(hour: 0, tokens: 180),
        .init(hour: 1, tokens: 120),
        .init(hour: 2, tokens: 90),
        .init(hour: 3, tokens: 60),
        .init(hour: 4, tokens: 70),
        .init(hour: 5, tokens: 110),
        .init(hour: 6, tokens: 220),
        .init(hour: 7, tokens: 460),
        .init(hour: 8, tokens: 780),
        .init(hour: 9, tokens: 1_250),
        .init(hour: 10, tokens: 1_620),
        .init(hour: 11, tokens: 1_480),
        .init(hour: 12, tokens: 980),
        .init(hour: 13, tokens: 1_120),
        .init(hour: 14, tokens: 1_760),
        .init(hour: 15, tokens: 2_140),
        .init(hour: 16, tokens: 1_940),
        .init(hour: 17, tokens: 1_520),
        .init(hour: 18, tokens: 1_080),
        .init(hour: 19, tokens: 60),
        .init(hour: 20, tokens: 1_320),
        .init(hour: 21, tokens: 1_700),
        .init(hour: 22, tokens: 1_360),
        .init(hour: 23, tokens: 640),
    ]

    var totalTokens: Int {
        hourlyUsage.reduce(0) { $0 + $1.tokens }
    }

    func triggerScan() {
        message = "Scan triggered"
    }

    func toggleChartStyle() {
        chartStyle = chartStyle == .line ? .bar : .line
    }
}
