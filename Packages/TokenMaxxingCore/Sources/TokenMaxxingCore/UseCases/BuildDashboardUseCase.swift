import Foundation

public struct BuildDashboardUseCase: Sendable {
    public let configuration: UsageDashboardConfiguration
    public let calendar: Calendar

    public init(
        configuration: UsageDashboardConfiguration = UsageDashboardConfiguration(),
        calendar: Calendar = .current
    ) {
        self.configuration = configuration
        self.calendar = calendar
    }

    public func execute(
        sessions: [Session],
        now: Date = .now
    ) -> UsageDashboardMetrics {
        TokenUsageAggregator.dashboardMetrics(
            from: sessions,
            calendar: calendar,
            now: now,
            dayBucketMinutes: configuration.dayBucketMinutes
        )
    }
}
