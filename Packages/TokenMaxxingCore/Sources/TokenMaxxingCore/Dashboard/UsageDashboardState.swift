import Foundation
import Observation

@Observable
public final class UsageDashboardState {
    public var selectedRange: UsageRange = .month
    public var status = "No local scan yet"

    public private(set) var hourlyUsage: [TokenUsagePoint]
    public private(set) var dailyUsage: [TokenUsagePoint]
    public private(set) var monthlyUsage: [TokenUsagePoint]

    public private(set) var sessionCount: Int
    public private(set) var turnCount: Int
    public private(set) var latestActivityAt: Date?

    private var previousHourlyUsage: [TokenUsagePoint]
    private var previousDailyUsage: [TokenUsagePoint]
    private var previousMonthlyUsage: [TokenUsagePoint]

    private let calendar: Calendar

    public init(calendar: Calendar = .current, now: Date = .now, sessions: [Session] = []) {
        self.calendar = calendar

        let metrics = TokenUsageAggregator.dashboardMetrics(
            from: sessions,
            calendar: calendar,
            now: now
        )
        hourlyUsage = metrics.hourlyUsage
        dailyUsage = metrics.dailyUsage
        monthlyUsage = metrics.monthlyUsage
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
            hourlyUsage
        case .month:
            dailyUsage
        case .year:
            monthlyUsage
        }
    }

    public var totalTokens: Int {
        total(for: visibleUsage)
    }

    public var averageTokens: Int {
        guard !visibleUsage.isEmpty else { return 0 }
        return totalTokens / visibleUsage.count
    }

    public var peakUsage: TokenUsagePoint? {
        visibleUsage.max { $0.tokens < $1.tokens }
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
        root: URL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".codex"),
        now: Date = .now
    ) async {
        status = "Scanning local logs..."

        do {
            let sessions = try await Task.detached(priority: .userInitiated) {
                try CodexSessionImporter(root: root).importSessions()
            }.value
            apply(sessions: sessions, now: now)
        } catch {
            status = "Scan failed"
        }
    }

    public func formatPeakLabel(_ point: TokenUsagePoint) -> String {
        switch selectedRange {
        case .day:
            point.date.formatted(.dateTime.hour(.defaultDigits(amPM: .abbreviated)))
        case .month:
            point.date.formatted(.dateTime.month(.abbreviated).day())
        case .year:
            point.date.formatted(.dateTime.month(.abbreviated))
        }
    }

    private var previousTotalTokens: Int {
        switch selectedRange {
        case .day:
            total(for: previousHourlyUsage)
        case .month:
            total(for: previousDailyUsage)
        case .year:
            total(for: previousMonthlyUsage)
        }
    }

    private func total(for points: [TokenUsagePoint]) -> Int {
        points.reduce(0) { $0 + $1.tokens }
    }

    private func apply(sessions: [Session], now: Date) {
        let metrics = TokenUsageAggregator.dashboardMetrics(
            from: sessions,
            calendar: calendar,
            now: now
        )
        hourlyUsage = metrics.hourlyUsage
        dailyUsage = metrics.dailyUsage
        monthlyUsage = metrics.monthlyUsage
        previousHourlyUsage = metrics.previousHourlyUsage
        previousDailyUsage = metrics.previousDailyUsage
        previousMonthlyUsage = metrics.previousMonthlyUsage
        sessionCount = metrics.sessionCount
        turnCount = metrics.turnCount
        latestActivityAt = metrics.latestActivityAt
        status = turnCount == 0 ? "No Codex usage found" : "Updated just now"
    }
}
