import XCTest
@testable import TokenMaxxingCore

final class SQLiteUsageRepositoryTests: XCTestCase {
    func testRepositoryRoundTripsAndReplacesImportedSession() async throws {
        let root = try TokenMaxxingTestFixtures.temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }

        let repository = SQLiteUsageRepository(databaseURL: root.appendingPathComponent("usage.sqlite3"))
        let sourceFile = SourceLogFile(
            importerKind: .codex,
            sessionID: "session",
            url: root.appendingPathComponent("session.jsonl"),
            modifiedAt: date(hour: 9),
            byteCount: 100
        )

        try await repository.replaceImportedSession(
            session(tokens: 100, messagePreview: "first"),
            sourceFile: sourceFile,
            importedAt: date(hour: 10)
        )

        var sessions = try await repository.loadSessions(matching: .all)
        XCTAssertEqual(sessions.count, 1)
        XCTAssertEqual(sessions.first?.turns.first?.usage?.totalTokens, 100)
        XCTAssertEqual(sessions.first?.turns.first?.messages.first?.preview, "first")

        let updatedSourceFile = SourceLogFile(
            importerKind: .codex,
            sessionID: "session",
            url: sourceFile.url,
            modifiedAt: date(hour: 11),
            byteCount: 200
        )
        try await repository.replaceImportedSession(
            session(tokens: 250, messagePreview: "updated"),
            sourceFile: updatedSourceFile,
            importedAt: date(hour: 12)
        )

        sessions = try await repository.loadSessions(
            matching: SessionQuery(importerKinds: [.codex], startedAtOrAfter: date(hour: 8))
        )
        XCTAssertEqual(sessions.count, 1)
        XCTAssertEqual(sessions.first?.totalUsage?.totalTokens, 250)
        XCTAssertEqual(sessions.first?.turns.count, 1)
        XCTAssertEqual(sessions.first?.turns.first?.usage?.totalTokens, 250)
        XCTAssertEqual(sessions.first?.turns.first?.messages.map(\.preview), ["updated"])

        let storedFiles = try await repository.loadSourceFiles(for: .codex)
        XCTAssertEqual(storedFiles.count, 1)
        XCTAssertEqual(storedFiles.first?.byteCount, 200)
        XCTAssertNil(storedFiles.first?.missingAt)

        let storedFile = try XCTUnwrap(storedFiles.first)
        try await repository.markSourceFileMissing(storedFile, missingAt: date(hour: 13))

        let missingFiles = try await repository.loadSourceFiles(for: .codex)
        let missingFile = try XCTUnwrap(missingFiles.first)
        XCTAssertEqual(missingFile.missingAt, date(hour: 13))
    }

    private func session(tokens: Int, messagePreview: String) -> Session {
        Session(
            id: "session",
            source: .codex(path: "/tmp/session.jsonl"),
            startedAt: date(hour: 9),
            endedAt: date(hour: 10),
            turns: [
                Turn(
                    id: "turn",
                    startedAt: date(hour: 9),
                    completedAt: date(hour: 10),
                    messages: [
                        Message(
                            id: "message",
                            role: .user,
                            timestamp: date(hour: 9),
                            preview: messagePreview,
                            rawType: "event_msg.user_message",
                            sourceLine: 3
                        ),
                    ],
                    usage: usage(tokens: tokens)
                ),
            ],
            totalUsage: usage(tokens: tokens)
        )
    }

    private func usage(tokens: Int) -> TokenUsage {
        TokenUsage(
            inputTokens: tokens,
            cachedInputTokens: 0,
            outputTokens: 0,
            reasoningOutputTokens: 0,
            totalTokens: tokens
        )
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
