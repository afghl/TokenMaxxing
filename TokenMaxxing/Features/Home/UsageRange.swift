enum UsageRange: String, CaseIterable, Identifiable, Sendable {
    case day = "Day"
    case month = "Month"
    case year = "Year"

    var id: Self { self }

    var headline: String {
        switch self {
        case .day:
            "Today"
        case .month:
            "Last 30 Days"
        case .year:
            "Last 12 Months"
        }
    }

    var chartTitle: String {
        switch self {
        case .day:
            "Intraday Token Trend"
        case .month:
            "Daily Volume"
        case .year:
            "Monthly Trend"
        }
    }

    var totalLabel: String {
        switch self {
        case .day:
            "tokens today"
        case .month:
            "tokens in 30 days"
        case .year:
            "tokens this year"
        }
    }

    var averageLabel: String {
        switch self {
        case .day:
            "Avg per interval"
        case .month:
            "Daily average"
        case .year:
            "Monthly average"
        }
    }

    var peakLabel: String {
        switch self {
        case .day:
            "Peak interval"
        case .month:
            "Peak day"
        case .year:
            "Peak month"
        }
    }

    var previousPeriodLabel: String {
        switch self {
        case .day:
            "yesterday"
        case .month:
            "previous 30 days"
        case .year:
            "previous year"
        }
    }
}
