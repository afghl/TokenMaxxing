import Foundation

public struct UsageDashboardMetrics: Equatable, Sendable {
    public let hourlyUsage: [TokenUsagePoint]
    public let dailyUsage: [TokenUsagePoint]
    public let monthlyUsage: [TokenUsagePoint]

    public let previousHourlyUsage: [TokenUsagePoint]
    public let previousDailyUsage: [TokenUsagePoint]
    public let previousMonthlyUsage: [TokenUsagePoint]

    public let sessionCount: Int
    public let turnCount: Int
    public let latestActivityAt: Date?

    public init(
        hourlyUsage: [TokenUsagePoint],
        dailyUsage: [TokenUsagePoint],
        monthlyUsage: [TokenUsagePoint],
        previousHourlyUsage: [TokenUsagePoint],
        previousDailyUsage: [TokenUsagePoint],
        previousMonthlyUsage: [TokenUsagePoint],
        sessionCount: Int,
        turnCount: Int,
        latestActivityAt: Date?
    ) {
        self.hourlyUsage = hourlyUsage
        self.dailyUsage = dailyUsage
        self.monthlyUsage = monthlyUsage
        self.previousHourlyUsage = previousHourlyUsage
        self.previousDailyUsage = previousDailyUsage
        self.previousMonthlyUsage = previousMonthlyUsage
        self.sessionCount = sessionCount
        self.turnCount = turnCount
        self.latestActivityAt = latestActivityAt
    }
}
