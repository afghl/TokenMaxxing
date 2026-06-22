import Foundation
import Observation
import TokenMaxxingCore

@Observable
final class HomeDashboardViewModel {
    var selectedRange: UsageRange = .month
    var status = "No local scan yet"

    private(set) var intradayUsage: [TokenUsagePoint]
    private(set) var hourlyUsage: [TokenUsagePoint]
    private(set) var dailyUsage: [TokenUsagePoint]
    private(set) var monthlyUsage: [TokenUsagePoint]

    private(set) var sessionCount: Int
    private(set) var turnCount: Int
    private(set) var latestActivityAt: Date?

    private var previousIntradayUsage: [TokenUsagePoint]
    private var previousHourlyUsage: [TokenUsagePoint]
    private var previousDailyUsage: [TokenUsagePoint]
    private var previousMonthlyUsage: [TokenUsagePoint]

    private let scanCodexDashboardUseCase: ScanCodexDashboardUseCase

    init(
        configuration: UsageDashboardConfiguration = UsageDashboardConfiguration(),
        calendar: Calendar = .current,
        now: Date = .now,
        sessions: [Session] = []
    ) {
        let buildDashboardUseCase = BuildDashboardUseCase(
            configuration: configuration,
            calendar: calendar
        )
        scanCodexDashboardUseCase = ScanCodexDashboardUseCase(
            buildDashboard: buildDashboardUseCase
        )

        let metrics = buildDashboardUseCase.execute(sessions: sessions, now: now)
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

    var visibleUsage: [TokenUsagePoint] {
        switch selectedRange {
        case .day:
            cumulativeUsage(from: intradayUsage)
        case .month:
            dailyUsage
        case .year:
            monthlyUsage
        }
    }

    var totalTokens: Int {
        total(for: usageForSelectedRange)
    }

    var averageTokens: Int {
        let points = usageForSelectedRange
        guard !points.isEmpty else { return 0 }
        return totalTokens / points.count
    }

    var peakUsage: TokenUsagePoint? {
        usageForSelectedRange.max { $0.tokens < $1.tokens }
    }

    var trendDescription: String {
        let previous = previousTotalTokens
        guard previous > 0 else { return "No previous period yet" }

        let difference = totalTokens - previous
        let percentage = Int((Double(abs(difference)) / Double(previous) * 100).rounded())
        let direction = difference >= 0 ? "Up" : "Down"
        return "\(direction) \(percentage)% vs \(selectedRange.previousPeriodLabel)"
    }

    var projectedMonthTokens: Int {
        let elapsedDays = max(dailyUsage.count, 1)
        return (total(for: dailyUsage) / elapsedDays) * 30
    }

    var weekAverageTokens: Int {
        let lastSevenDays = dailyUsage.suffix(7)
        guard !lastSevenDays.isEmpty else { return 0 }
        return lastSevenDays.reduce(0) { $0 + $1.tokens } / lastSevenDays.count
    }

    var activeDays: Int {
        dailyUsage.filter { $0.tokens > 0 }.count
    }

    @MainActor
    func refreshFromCodexLogs(
        root: URL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(
            ".codex"),
        now: Date = .now
    ) async {
        status = "Scanning local logs..."
        homeDashboardDebugLog("Starting Codex log scan at \(root.path)")

        do {
            let scanCodexDashboardUseCase = scanCodexDashboardUseCase
            let metrics = try await Task.detached(priority: .userInitiated) {
                try scanCodexDashboardUseCase.execute(root: root, now: now)
            }.value

            homeDashboardDebugLog("Codex log scan returned \(metrics.sessionCount) sessions")
            apply(metrics: metrics)
        } catch {
            homeDashboardDebugLog("Codex log scan failed: \(error.localizedDescription)")
            status = "Scan failed"
        }
    }

    func formatPeakLabel(_ point: TokenUsagePoint) -> String {
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
        homeDashboardDebugLog(
            "Dashboard metrics: sessions=\(sessionCount), turns=\(turnCount), totalTokens=\(totalTokens)"
        )
        status = turnCount == 0 ? "No Codex usage found" : "Updated just now"
    }
}

private func homeDashboardDebugLog(_ message: @autoclosure () -> String) {
#if DEBUG
    print("[TokenMaxxing] \(message())")
#endif
}
