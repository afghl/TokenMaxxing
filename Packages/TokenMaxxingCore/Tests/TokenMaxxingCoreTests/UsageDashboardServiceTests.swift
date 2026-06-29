import XCTest
@testable import TokenMaxxingCore

final class UsageDashboardServiceTests: XCTestCase {
    func testDashboardServiceSyncsSQLiteAndReturnsAggregatorMetrics() async throws {
        let root = try TokenMaxxingTestFixtures.temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }

        _ = try TokenMaxxingTestFixtures.writeCodexSession(
            root: root,
            contents: TokenMaxxingTestFixtures.codexFixture(includeSecondTurn: true)
        )

        let calendar = makeCalendar()
        let now = DateComponents(
            calendar: calendar,
            timeZone: calendar.timeZone,
            year: 2026,
            month: 6,
            day: 16,
            hour: 12
        ).date!
        let service = UsageDashboardService(databaseURL: root.appendingPathComponent("usage.sqlite3"))

        let metrics = try await service.refreshFromCodexLogs(
            root: root,
            now: now,
            calendar: calendar,
            configuration: UsageDashboardConfiguration(dayBucketMinutes: 60)
        )

        XCTAssertEqual(metrics.sessionCount, 1)
        XCTAssertEqual(metrics.turnCount, 2)
        XCTAssertEqual(metrics.dailyUsage.last?.tokens, 250)
        XCTAssertEqual(metrics.intradayComparison.currentTotal, 250)
    }

    private func makeCalendar() -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }
}
