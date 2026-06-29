import XCTest
@testable import TokenMaxxingCore

final class UsageDashboardSQLiteEndToEndTests: XCTestCase {
    func testCodexLogsSyncThroughSQLiteIntoDashboardMetricsEndToEnd() async throws {
        let root = try TokenMaxxingTestFixtures.temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }

        let databaseURL = root.appendingPathComponent("usage.sqlite3")
        let sessionURL = try TokenMaxxingTestFixtures.writeCodexSession(root: root)
        let service = UsageDashboardService(databaseURL: databaseURL)
        let repository = SQLiteUsageRepository(databaseURL: databaseURL)
        let calendar = makeCalendar()

        let firstMetrics = try await service.refreshFromCodexLogs(
            root: root,
            now: date(hour: 11),
            calendar: calendar,
            configuration: UsageDashboardConfiguration(dayBucketMinutes: 60)
        )
        XCTAssertEqual(firstMetrics.sessionCount, 1)
        XCTAssertEqual(firstMetrics.turnCount, 1)
        XCTAssertEqual(firstMetrics.dailyUsage.last?.tokens, 100)

        var storedFiles = try await repository.loadSourceFiles(for: .codex)
        var storedFile = try XCTUnwrap(storedFiles.first)
        XCTAssertEqual(storedFile.importedAt, date(hour: 11))
        XCTAssertNil(storedFile.missingAt)

        let unchangedMetrics = try await service.refreshFromCodexLogs(
            root: root,
            now: date(hour: 12),
            calendar: calendar,
            configuration: UsageDashboardConfiguration(dayBucketMinutes: 60)
        )
        XCTAssertEqual(unchangedMetrics.turnCount, 1)

        storedFiles = try await repository.loadSourceFiles(for: .codex)
        storedFile = try XCTUnwrap(storedFiles.first)
        XCTAssertEqual(storedFile.importedAt, date(hour: 11))

        try TokenMaxxingTestFixtures.codexFixture(includeSecondTurn: true)
            .write(to: sessionURL, atomically: true, encoding: .utf8)

        let changedMetrics = try await service.refreshFromCodexLogs(
            root: root,
            now: date(hour: 13),
            calendar: calendar,
            configuration: UsageDashboardConfiguration(dayBucketMinutes: 60)
        )
        XCTAssertEqual(changedMetrics.turnCount, 2)
        XCTAssertEqual(changedMetrics.dailyUsage.last?.tokens, 250)

        storedFiles = try await repository.loadSourceFiles(for: .codex)
        storedFile = try XCTUnwrap(storedFiles.first)
        XCTAssertEqual(storedFile.importedAt, date(hour: 13))

        try FileManager.default.removeItem(at: sessionURL)

        let missingSourceMetrics = try await service.refreshFromCodexLogs(
            root: root,
            now: date(hour: 14),
            calendar: calendar,
            configuration: UsageDashboardConfiguration(dayBucketMinutes: 60)
        )
        XCTAssertEqual(missingSourceMetrics.sessionCount, 1)
        XCTAssertEqual(missingSourceMetrics.turnCount, 2)

        storedFiles = try await repository.loadSourceFiles(for: .codex)
        storedFile = try XCTUnwrap(storedFiles.first)
        XCTAssertEqual(storedFile.missingAt, date(hour: 14))
    }

    private func makeCalendar() -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    private func date(hour: Int) -> Date {
        DateComponents(
            calendar: makeCalendar(),
            timeZone: TimeZone(secondsFromGMT: 0),
            year: 2026,
            month: 6,
            day: 16,
            hour: hour
        ).date!
    }
}
