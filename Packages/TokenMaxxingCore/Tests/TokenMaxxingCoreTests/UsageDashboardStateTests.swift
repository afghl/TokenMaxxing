import XCTest
@testable import TokenMaxxingCore

final class UsageDashboardStateTests: XCTestCase {
    func testRangeSelectionControlsVisibleUsage() throws {
        let state = makeState()

        XCTAssertEqual(state.visibleUsage.count, 24)

        state.selectedRange = .month
        XCTAssertEqual(state.visibleUsage.count, 30)

        state.selectedRange = .year
        XCTAssertEqual(state.visibleUsage.count, 12)
    }

    func testTotalTokensUsesSelectedRange() throws {
        let state = makeState()
        XCTAssertEqual(state.totalTokens, state.visibleUsage.reduce(0) { $0 + $1.tokens })

        state.selectedRange = .month
        XCTAssertEqual(state.totalTokens, state.visibleUsage.reduce(0) { $0 + $1.tokens })
    }

    func testScanUpdatesStatus() throws {
        let state = makeState()

        state.triggerScan()

        XCTAssertEqual(state.status, "Local scan queued")
    }

    private func makeState() -> UsageDashboardState {
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

        return UsageDashboardState(calendar: calendar, now: now)
    }
}
