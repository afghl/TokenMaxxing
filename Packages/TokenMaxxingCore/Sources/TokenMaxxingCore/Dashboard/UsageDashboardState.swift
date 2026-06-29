import Foundation
import Observation

@Observable
public final class UsageDashboardState {
    public var selectedRange: UsageRange = .month
    public var status = "No usage data"

    public private(set) var intradayUsage: [TokenUsagePoint]
    public private(set) var hourlyUsage: [TokenUsagePoint]
    public private(set) var dailyUsage: [TokenUsagePoint]
    public private(set) var monthlyUsage: [TokenUsagePoint]
    public private(set) var intradayComparison: IntradayUsageComparison

    public private(set) var sessionCount: Int
    public private(set) var turnCount: Int
    public private(set) var latestActivityAt: Date?

    private var previousIntradayUsage: [TokenUsagePoint]
    private var previousHourlyUsage: [TokenUsagePoint]
    private var previousDailyUsage: [TokenUsagePoint]
    private var previousMonthlyUsage: [TokenUsagePoint]

    private let configuration: UsageDashboardConfiguration
    private let calendar: Calendar
    @ObservationIgnored private let dashboardService: UsageDashboardService
    @ObservationIgnored private var isRefreshing = false

    public init(
        configuration: UsageDashboardConfiguration = UsageDashboardConfiguration(),
        calendar: Calendar = .current,
        now: Date = .now,
        sessions: [Session] = [],
        dashboardService: UsageDashboardService = UsageDashboardService()
    ) {
        self.configuration = configuration
        self.calendar = calendar
        self.dashboardService = dashboardService

        let metrics = TokenUsageAggregator.dashboardMetrics(
            from: sessions,
            calendar: calendar,
            now: now,
            dayBucketMinutes: configuration.dayBucketMinutes
        )
        intradayComparison = metrics.intradayComparison
        intradayUsage = metrics.intradayUsage
        hourlyUsage = metrics.hourlyUsage
        dailyUsage = metrics.dailyUsage
        monthlyUsage = metrics.monthlyUsage
        previousIntradayUsage = metrics.previousIntradayUsage
        previousHourlyUsage = metrics.previousHourlyUsage
        previousDailyUsage = metrics.previousDailyUsage
        previousMonthlyUsage = metrics.previousMonthlyUsage
        sessionCount = metrics.sessionCount
        turnCount = metrics.turnCount
        latestActivityAt = metrics.latestActivityAt

        if !sessions.isEmpty {
            status = "Updated just now"
        }
    }

    public var visibleUsage: [TokenUsagePoint] {
        switch selectedRange {
        case .day:
            cumulativeUsage(from: intradayUsage)
        case .month:
            dailyUsage
        case .year:
            monthlyUsage
        }
    }

    public var totalTokens: Int {
        total(for: usageForSelectedRange)
    }

    public var averageTokens: Int {
        let points = usageForSelectedRange
        guard !points.isEmpty else { return 0 }
        return totalTokens / points.count
    }

    public var peakUsage: TokenUsagePoint? {
        let points = usageForSelectedRange
        guard points.contains(where: { $0.tokens > 0 }) else { return nil }
        return points.max { $0.tokens < $1.tokens }
    }

    public var trendDescription: String {
        let previous = previousTotalTokens
        guard previous > 0 else { return "No previous period yet" }

        let difference = totalTokens - previous
        let percentage = Int((Double(abs(difference)) / Double(previous) * 100).rounded())
        let direction = difference >= 0 ? "Up" : "Down"
        return "\(direction) \(percentage)% vs \(selectedRange.previousPeriodLabel)"
    }

    public var projectedMonthTokens: Int {
        let elapsedDays = max(dailyUsage.count, 1)
        return (total(for: dailyUsage) / elapsedDays) * 30
    }

    public var weekAverageTokens: Int {
        let lastSevenDays = dailyUsage.suffix(7)
        guard !lastSevenDays.isEmpty else { return 0 }
        return lastSevenDays.reduce(0) { $0 + $1.tokens } / lastSevenDays.count
    }

    public var activeDays: Int {
        dailyUsage.filter { $0.tokens > 0 }.count
    }

    @MainActor
    public func refreshFromCodexLogs(
        root: URL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(
            ".codex"),
        now: Date = .now
    ) async {
        guard !isRefreshing else {
            return
        }

        isRefreshing = true
        defer {
            isRefreshing = false
        }

        status = "Importing local logs..."
        tokenMaxxingDebugLog("Starting Codex log import at \(root.path)")

        do {
            let metrics = try await dashboardService.refreshFromCodexLogs(
                root: root,
                now: now,
                calendar: calendar,
                configuration: configuration
            )

            tokenMaxxingDebugLog(
                "Codex log import returned \(metrics.sessionCount) persisted sessions"
            )
            apply(metrics: metrics)
        } catch {
            tokenMaxxingDebugLog("Codex log import failed: \(error.localizedDescription)")
            status = "Import failed"
        }
    }

    public func formatPeakLabel(_ point: TokenUsagePoint) -> String {
        switch selectedRange {
        case .day:
            point.date.formatted(.dateTime.hour(.defaultDigits(amPM: .abbreviated)).minute())
        case .month:
            point.date.formatted(.dateTime.month(.abbreviated).day())
        case .year:
            point.date.formatted(.dateTime.month(.abbreviated))
        }
    }

    private var previousTotalTokens: Int {
        switch selectedRange {
        case .day:
            total(for: previousIntradayUsage)
        case .month:
            total(for: previousDailyUsage)
        case .year:
            total(for: previousMonthlyUsage)
        }
    }

    private var usageForSelectedRange: [TokenUsagePoint] {
        switch selectedRange {
        case .day:
            intradayUsage
        case .month:
            dailyUsage
        case .year:
            monthlyUsage
        }
    }

    private func total(for points: [TokenUsagePoint]) -> Int {
        points.reduce(0) { $0 + $1.tokens }
    }

    private func cumulativeUsage(from points: [TokenUsagePoint]) -> [TokenUsagePoint] {
        var runningTotal = 0
        return points.map { point in
            runningTotal += point.tokens
            return TokenUsagePoint(date: point.date, tokens: runningTotal)
        }
    }

    private func apply(metrics: UsageDashboardMetrics) {
        intradayComparison = metrics.intradayComparison
        intradayUsage = metrics.intradayUsage
        hourlyUsage = metrics.hourlyUsage
        dailyUsage = metrics.dailyUsage
        monthlyUsage = metrics.monthlyUsage
        previousIntradayUsage = metrics.previousIntradayUsage
        previousHourlyUsage = metrics.previousHourlyUsage
        previousDailyUsage = metrics.previousDailyUsage
        previousMonthlyUsage = metrics.previousMonthlyUsage
        sessionCount = metrics.sessionCount
        turnCount = metrics.turnCount
        latestActivityAt = metrics.latestActivityAt
        tokenMaxxingDebugLog(
            "Dashboard metrics: sessions=\(sessionCount), turns=\(turnCount), totalTokens=\(totalTokens)"
        )
        status = turnCount == 0 ? "No Codex usage found" : "Updated just now"
    }
}
