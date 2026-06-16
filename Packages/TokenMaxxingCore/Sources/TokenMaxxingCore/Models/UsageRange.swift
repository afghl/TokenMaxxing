public enum UsageRange: String, CaseIterable, Identifiable, Sendable {
    case day = "Day"
    case month = "Month"
    case year = "Year"

    public var id: Self { self }

    public var headline: String {
        switch self {
        case .day:
            "Today"
        case .month:
            "Last 30 Days"
        case .year:
            "Last 12 Months"
        }
    }

    public var chartTitle: String {
        switch self {
        case .day:
            "Daily Token Trend"
        case .month:
            "Daily Volume"
        case .year:
            "Monthly Trend"
        }
    }

    public var totalLabel: String {
        switch self {
        case .day:
            "tokens today"
        case .month:
            "tokens in 30 days"
        case .year:
            "tokens this year"
        }
    }

    public var averageLabel: String {
        switch self {
        case .day:
            "Avg per active hour"
        case .month:
            "Daily average"
        case .year:
            "Monthly average"
        }
    }

    public var peakLabel: String {
        switch self {
        case .day:
            "Peak hour"
        case .month:
            "Peak day"
        case .year:
            "Peak month"
        }
    }

    public var previousPeriodLabel: String {
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
