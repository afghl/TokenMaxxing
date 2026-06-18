import XCTest
@testable import TokenMaxxingCore

final class UsageDashboardStateTests: XCTestCase {
    func testRangeSelectionControlsVisibleUsage() throws {
        let state = makeState()

        XCTAssertEqual(state.selectedRange, .month)
        XCTAssertEqual(state.visibleUsage.count, 30)

        state.selectedRange = .day
        XCTAssertEqual(state.visibleUsage.count, 24 * 60)

        state.selectedRange = .year
        XCTAssertEqual(state.visibleUsage.count, 12)
    }

    func testTotalTokensUsesSelectedRange() throws {
        let state = makeState()
        XCTAssertEqual(state.totalTokens, 800)

        state.selectedRange = .day
        XCTAssertEqual(state.totalTokens, 350)
    }

    func testDayVisibleUsageIsCumulativeWithinDay() throws {
        let state = makeState()

        state.selectedRange = .day

        XCTAssertEqual(state.visibleUsage[8 * 60].tokens, 0)
        XCTAssertEqual(state.visibleUsage[9 * 60].tokens, 250)
        XCTAssertEqual(state.visibleUsage[10 * 60].tokens, 250)
        XCTAssertEqual(state.visibleUsage[11 * 60].tokens, 350)
        XCTAssertEqual(state.visibleUsage[23 * 60 + 59].tokens, 350)
        XCTAssertEqual(state.totalTokens, 350)
        XCTAssertEqual(state.peakUsage?.tokens, 250)
    }

    func testDayVisibleUsageUsesConfiguredGranularity() throws {
        let state = makeState(configuration: UsageDashboardConfiguration(dayBucketMinutes: 15))

        state.selectedRange = .day

        XCTAssertEqual(state.visibleUsage.count, 96)
        XCTAssertEqual(state.visibleUsage[8 * 4].tokens, 0)
        XCTAssertEqual(state.visibleUsage[9 * 4].tokens, 250)
        XCTAssertEqual(state.visibleUsage[10 * 4].tokens, 250)
        XCTAssertEqual(state.visibleUsage[11 * 4].tokens, 350)
        XCTAssertEqual(state.visibleUsage[23 * 4 + 3].tokens, 350)
        XCTAssertEqual(state.totalTokens, 350)
        XCTAssertEqual(state.peakUsage?.tokens, 250)
    }

    func testDayGranularityIsClampedToSupportedRange() throws {
        XCTAssertEqual(UsageDashboardConfiguration(dayBucketMinutes: 0).dayBucketMinutes, 1)
        XCTAssertEqual(UsageDashboardConfiguration(dayBucketMinutes: 61).dayBucketMinutes, 60)
    }

    func testStatusReflectsInitialSessionData() throws {
        let state = makeState()

        XCTAssertEqual(state.status, "Updated just now")
        XCTAssertEqual(state.sessionCount, 2)
        XCTAssertEqual(state.turnCount, 4)
        XCTAssertEqual(state.activeDays, 3)
    }

    private func makeState(
        configuration: UsageDashboardConfiguration = UsageDashboardConfiguration()
    ) -> UsageDashboardState {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let now = DateComponents(
            calendar: calendar,
            timeZone: calendar.timeZone,
            year: 2026,
            month: 6,
            day: 9,
            hour: 12
        ).date!

        return UsageDashboardState(
            configuration: configuration,
            calendar: calendar,
            now: now,
            sessions: makeSessions(calendar: calendar)
        )
    }

    private func makeSessions(calendar: Calendar) -> [Session] {
        [
            Session(
                id: "first",
                source: .unknown(path: nil),
                startedAt: date(calendar, year: 2026, month: 6, day: 8, hour: 10),
                endedAt: date(calendar, year: 2026, month: 6, day: 9, hour: 9),
                turns: [
                    turn(id: "first-1", calendar: calendar, day: 8, hour: 10, tokens: 300),
                    turn(id: "first-2", calendar: calendar, day: 9, hour: 9, tokens: 250),
                ],
                totalUsage: nil
            ),
            Session(
                id: "second",
                source: .unknown(path: nil),
                startedAt: date(calendar, year: 2026, month: 5, day: 20, hour: 14),
                endedAt: nil,
                turns: [
                    turn(id: "second-1", calendar: calendar, day: 9, hour: 11, tokens: 100),
                    turn(id: "second-2", calendar: calendar, month: 5, day: 20, hour: 14, tokens: 150),
                ],
                totalUsage: nil
            ),
        ]
    }

    private func turn(
        id: String,
        calendar: Calendar,
        month: Int = 6,
        day: Int,
        hour: Int,
        tokens: Int
    ) -> Turn {
        Turn(
            id: id,
            startedAt: date(calendar, year: 2026, month: month, day: day, hour: hour),
            completedAt: date(calendar, year: 2026, month: month, day: day, hour: hour + 1),
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

    private func date(
        _ calendar: Calendar,
        year: Int,
        month: Int,
        day: Int,
        hour: Int
    ) -> Date {
        DateComponents(
            calendar: calendar,
            timeZone: calendar.timeZone,
            year: year,
            month: month,
            day: day,
            hour: hour
        ).date!
    }
}
