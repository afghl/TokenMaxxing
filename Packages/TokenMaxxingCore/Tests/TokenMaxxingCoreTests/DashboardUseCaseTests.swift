import XCTest
@testable import TokenMaxxingCore

final class DashboardUseCaseTests: XCTestCase {
    func testBuildDashboardUseCaseMatchesAggregatorOutput() throws {
        let calendar = makeCalendar()
        let now = date(calendar, month: 6, day: 16, hour: 12)
        let configuration = UsageDashboardConfiguration(dayBucketMinutes: 15)
        let sessions = [
            session(
                turns: [
                    turn(calendar, month: 6, day: 16, hour: 9, tokens: 200),
                    turn(calendar, month: 5, day: 17, hour: 9, tokens: 75),
                ]
            ),
        ]

        let useCase = BuildDashboardUseCase(
            configuration: configuration,
            calendar: calendar
        )

        let metrics = useCase.execute(sessions: sessions, now: now)
        let expected = TokenUsageAggregator.dashboardMetrics(
            from: sessions,
            calendar: calendar,
            now: now,
            dayBucketMinutes: configuration.dayBucketMinutes
        )

        XCTAssertEqual(metrics, expected)
        XCTAssertEqual(metrics.sessionCount, 1)
        XCTAssertEqual(metrics.turnCount, 2)
        XCTAssertEqual(metrics.dailyUsage.last?.tokens, 200)
    }

    func testScanCodexDashboardUseCaseImportsLogsAndBuildsMetrics() throws {
        let root = try makeFixtureRoot()
        defer { try? FileManager.default.removeItem(at: root) }

        let calendar = makeCalendar()
        let now = date(calendar, month: 6, day: 16, hour: 12)
        let useCase = ScanCodexDashboardUseCase(
            buildDashboard: BuildDashboardUseCase(
                configuration: UsageDashboardConfiguration(dayBucketMinutes: 15),
                calendar: calendar
            )
        )

        let metrics = try useCase.execute(root: root, now: now)

        XCTAssertEqual(metrics.sessionCount, 1)
        XCTAssertEqual(metrics.turnCount, 2)
        XCTAssertEqual(metrics.dailyUsage.last?.tokens, 250)
        XCTAssertEqual(metrics.monthlyUsage.last?.tokens, 250)
        XCTAssertEqual(metrics.intradayUsage[9 * 4 + 1].tokens, 250)
        XCTAssertEqual(
            metrics.latestActivityAt,
            date(calendar, month: 6, day: 16, hour: 9, minute: 29, second: 1)
        )
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
        minute: Int = 0,
        tokens: Int
    ) -> Turn {
        Turn(
            id: "\(month)-\(day)-\(hour)-\(minute)",
            startedAt: date(calendar, month: month, day: day, hour: hour, minute: minute),
            completedAt: date(calendar, month: month, day: day, hour: hour + 1, minute: minute),
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
        month: Int,
        day: Int,
        hour: Int,
        minute: Int = 0,
        second: Int = 0
    ) -> Date {
        DateComponents(
            calendar: calendar,
            timeZone: calendar.timeZone,
            year: 2026,
            month: month,
            day: day,
            hour: hour,
            minute: minute,
            second: second
        ).date!
    }

    private func makeFixtureRoot() throws -> URL {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("TokenMaxxingUseCaseTests-\(UUID().uuidString)", isDirectory: true)
        let sessionDirectory = root
            .appendingPathComponent("sessions/2026/06/16", isDirectory: true)
        try FileManager.default.createDirectory(at: sessionDirectory, withIntermediateDirectories: true)

        let fileURL = sessionDirectory
            .appendingPathComponent("rollout-2026-06-16T17-27-41-019ecfc2-0c2b-71a3-bb30-b55331de26ad.jsonl")
        try codexFixture.write(to: fileURL, atomically: true, encoding: .utf8)

        return root
    }

    private var codexFixture: String {
        """
        {"timestamp":"2026-06-16T09:28:00.000Z","type":"session_meta","payload":{}}
        {"timestamp":"2026-06-16T09:28:00.500Z","type":"event_msg","payload":{"type":"task_started"}}
        {"timestamp":"2026-06-16T09:28:01.000Z","type":"event_msg","payload":{"type":"user_message","message":"first turn\\n"}}
        {"timestamp":"2026-06-16T09:28:02.000Z","type":"event_msg","payload":{"type":"agent_message","message":"working"}}
        {"timestamp":"2026-06-16T09:28:03.000Z","type":"event_msg","payload":{"type":"token_count","info":{"total_token_usage":{"input_tokens":90,"cached_input_tokens":40,"output_tokens":10,"reasoning_output_tokens":5,"total_tokens":100}}}}
        {"timestamp":"2026-06-16T09:28:04.000Z","type":"event_msg","payload":{"type":"task_complete"}}
        {"timestamp":"2026-06-16T09:29:00.000Z","type":"event_msg","payload":{"type":"task_started"}}
        {"timestamp":"2026-06-16T09:29:01.000Z","type":"event_msg","payload":{"type":"user_message","message":"second turn\\n"}}
        {"timestamp":"2026-06-16T09:29:05.000Z","type":"event_msg","payload":{"type":"token_count","info":{"total_token_usage":{"input_tokens":230,"cached_input_tokens":100,"output_tokens":20,"reasoning_output_tokens":8,"total_tokens":250}}}}
        """
    }
}
