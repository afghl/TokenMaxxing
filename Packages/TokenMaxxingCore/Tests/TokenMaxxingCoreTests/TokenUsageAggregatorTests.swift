import XCTest
@testable import TokenMaxxingCore

final class TokenUsageAggregatorTests: XCTestCase {
    func testDailyUsageAggregatesTurnUsageByStartDayAndFillsMissingDays() throws {
        let calendar = makeCalendar()
        let now = date(calendar, month: 6, day: 16, hour: 12)
        let sessions = [
            session(
                turns: [
                    turn(calendar, month: 6, day: 15, hour: 10, tokens: 100),
                    turn(calendar, month: 6, day: 16, hour: 9, tokens: 200),
                    turn(calendar, month: 6, day: 16, hour: 18, tokens: 50),
                    turn(calendar, month: 6, day: 14, hour: 23, tokens: 999),
                    Turn(
                        id: "no-usage",
                        startedAt: date(calendar, month: 6, day: 16, hour: 20),
                        completedAt: nil,
                        messages: [],
                        usage: nil
                    ),
                ]
            ),
        ]

        let points = TokenUsageAggregator.dailyUsage(
            from: sessions,
            calendar: calendar,
            days: 2,
            endingAt: now
        )

        XCTAssertEqual(points.map(\.date), [
            date(calendar, month: 6, day: 15, hour: 0),
            date(calendar, month: 6, day: 16, hour: 0),
        ])
        XCTAssertEqual(points.map(\.tokens), [100, 250])
    }

    func testDashboardMetricsIncludesPreviousPeriodAndLatestActivity() throws {
        let calendar = makeCalendar()
        let now = date(calendar, month: 6, day: 16, hour: 12)
        let sessions = [
            session(
                turns: [
                    turn(calendar, month: 6, day: 16, hour: 9, tokens: 200),
                    turn(calendar, month: 5, day: 17, hour: 9, tokens: 75),
                ]
            ),
        ]

        let metrics = TokenUsageAggregator.dashboardMetrics(
            from: sessions,
            calendar: calendar,
            now: now
        )

        XCTAssertEqual(metrics.sessionCount, 1)
        XCTAssertEqual(metrics.turnCount, 2)
        XCTAssertEqual(metrics.dailyUsage.last?.tokens, 200)
        XCTAssertEqual(metrics.previousDailyUsage.last?.tokens, 75)
        XCTAssertEqual(metrics.latestActivityAt, date(calendar, month: 6, day: 16, hour: 10))
    }

    private func makeCalendar() -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    private func session(turns: [Turn]) -> Session {
        Session(
            id: UUID().uuidString,
            source: .unknown(path: nil),
            startedAt: turns.first?.startedAt ?? Date(timeIntervalSince1970: 0),
            endedAt: turns.last?.completedAt,
            turns: turns,
            totalUsage: nil
        )
    }

    private func turn(
        _ calendar: Calendar,
        month: Int,
        day: Int,
        hour: Int,
        tokens: Int
    ) -> Turn {
        Turn(
            id: "\(month)-\(day)-\(hour)",
            startedAt: date(calendar, month: month, day: day, hour: hour),
            completedAt: date(calendar, month: month, day: day, hour: hour + 1),
            messages: [],
            usage: TokenUsage(
                inputTokens: tokens,
                cachedInputTokens: 0,
                outputTokens: 0,
                reasoningOutputTokens: 0,
                totalTokens: tokens
            )
        )
    }

    private func date(_ calendar: Calendar, month: Int, day: Int, hour: Int) -> Date {
        DateComponents(
            calendar: calendar,
            timeZone: calendar.timeZone,
            year: 2026,
            month: month,
            day: day,
            hour: hour
        ).date!
    }
}
