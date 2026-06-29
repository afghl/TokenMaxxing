import XCTest
@testable import TokenMaxxingCore

final class CodexUsageSyncServiceTests: XCTestCase {
    func testSyncImportsSkipsReimportsAndMarksMissingFiles() async throws {
        let root = try TokenMaxxingTestFixtures.temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }

        let databaseURL = root.appendingPathComponent("usage.sqlite3")
        let repository = SQLiteUsageRepository(databaseURL: databaseURL)
        let service = CodexUsageSyncService(repository: repository)
        let sessionURL = try TokenMaxxingTestFixtures.writeCodexSession(root: root)

        try await service.sync(root: root, importedAt: date(hour: 11))

        var sessions = try await repository.loadSessions(matching: .all)
        XCTAssertEqual(sessions.count, 1)
        XCTAssertEqual(sessions.first?.turns.count, 1)
        XCTAssertEqual(sessions.first?.totalUsage?.totalTokens, 100)

        try await service.sync(root: root, importedAt: date(hour: 12))
        var storedFiles = try await repository.loadSourceFiles(for: .codex)
        var storedFile = try XCTUnwrap(storedFiles.first)
        XCTAssertEqual(storedFile.importedAt, date(hour: 11))

        try TokenMaxxingTestFixtures.codexFixture(includeSecondTurn: true)
            .write(to: sessionURL, atomically: true, encoding: .utf8)
        try await service.sync(root: root, importedAt: date(hour: 13))

        sessions = try await repository.loadSessions(matching: .all)
        XCTAssertEqual(sessions.first?.turns.count, 2)
        XCTAssertEqual(sessions.first?.totalUsage?.totalTokens, 250)
        storedFiles = try await repository.loadSourceFiles(for: .codex)
        storedFile = try XCTUnwrap(storedFiles.first)
        XCTAssertEqual(storedFile.importedAt, date(hour: 13))

        try FileManager.default.removeItem(at: sessionURL)
        try await service.sync(root: root, importedAt: date(hour: 14))

        storedFiles = try await repository.loadSourceFiles(for: .codex)
        storedFile = try XCTUnwrap(storedFiles.first)
        XCTAssertEqual(storedFile.missingAt, date(hour: 14))
        sessions = try await repository.loadSessions(matching: .all)
        XCTAssertEqual(sessions.count, 1)
    }

    private func date(hour: Int) -> Date {
        DateComponents(
            calendar: Calendar(identifier: .gregorian),
            timeZone: TimeZone(secondsFromGMT: 0),
            year: 2026,
            month: 6,
            day: 16,
            hour: hour
        ).date!
    }
}
