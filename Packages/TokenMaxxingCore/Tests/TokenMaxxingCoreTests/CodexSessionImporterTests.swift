import Foundation
import XCTest
@testable import TokenMaxxingCore

final class CodexSessionImporterTests: XCTestCase {
    func testImporterBuildsSessionTurnsAndMessagesFromCodexJSONL() throws {
        let root = try makeFixtureRoot()
        defer { try? FileManager.default.removeItem(at: root) }

        let importer = CodexSessionImporter(root: root)
        let sessions = try importer.importSessions()

        XCTAssertEqual(sessions.count, 1)

        let session = try XCTUnwrap(sessions.first)
        XCTAssertEqual(session.id, "019ecfc2-0c2b-71a3-bb30-b55331de26ad")
        XCTAssertEqual(session.turns.count, 2)
        XCTAssertEqual(session.totalUsage?.totalTokens, 250)
        XCTAssertNil(session.endedAt)

        let firstTurn = session.turns[0]
        XCTAssertEqual(firstTurn.status, .completed)
        XCTAssertEqual(firstTurn.workedDuration, 3)
        XCTAssertEqual(firstTurn.usage?.totalTokens, 100)
        XCTAssertEqual(firstTurn.messages.filter { $0.role == .user }.count, 1)
        XCTAssertEqual(firstTurn.messages.filter { $0.role == .assistant }.count, 1)
        XCTAssertEqual(firstTurn.messages.filter { $0.usageSnapshot != nil }.count, 1)

        let secondTurn = session.turns[1]
        XCTAssertEqual(secondTurn.status, .inProgress)
        XCTAssertNil(secondTurn.workedDuration)
        XCTAssertEqual(secondTurn.usage?.totalTokens, 150)
        XCTAssertEqual(secondTurn.userMessage?.text, "second turn\n")
    }

    func testImporterCanLoadSingleSessionByID() throws {
        let root = try makeFixtureRoot()
        defer { try? FileManager.default.removeItem(at: root) }

        let importer = CodexSessionImporter(root: root)
        let session = try importer.importSession(id: "019ecfc2-0c2b-71a3-bb30-b55331de26ad")

        XCTAssertEqual(session?.turns.count, 2)
        XCTAssertNil(try importer.importSession(id: "missing"))
    }

    private func makeFixtureRoot() throws -> URL {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("TokenMaxxingCoreTests-\(UUID().uuidString)", isDirectory: true)
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
        {"timestamp":"2026-06-16T09:28:01.000Z","type":"response_item","payload":{"type":"message","role":"user","content":[{"type":"input_text","text":"first turn\\n"}]}}
        {"timestamp":"2026-06-16T09:28:01.000Z","type":"event_msg","payload":{"type":"user_message","message":"first turn\\n"}}
        {"timestamp":"2026-06-16T09:28:02.000Z","type":"event_msg","payload":{"type":"agent_message","message":"working"}}
        {"timestamp":"2026-06-16T09:28:03.000Z","type":"event_msg","payload":{"type":"token_count","info":{"total_token_usage":{"input_tokens":90,"cached_input_tokens":40,"output_tokens":10,"reasoning_output_tokens":5,"total_tokens":100}}}}
        {"timestamp":"2026-06-16T09:28:04.000Z","type":"event_msg","payload":{"type":"task_complete"}}
        {"timestamp":"2026-06-16T09:29:00.000Z","type":"event_msg","payload":{"type":"task_started"}}
        {"timestamp":"2026-06-16T09:29:01.000Z","type":"event_msg","payload":{"type":"user_message","message":"second turn\\n"}}
        {"timestamp":"2026-06-16T09:29:03.000Z","type":"response_item","payload":{"type":"function_call","name":"exec_command"}}
        {"timestamp":"2026-06-16T09:29:04.000Z","type":"response_item","payload":{"type":"function_call_output","output":"ok"}}
        {"timestamp":"2026-06-16T09:29:05.000Z","type":"event_msg","payload":{"type":"token_count","info":{"total_token_usage":{"input_tokens":230,"cached_input_tokens":100,"output_tokens":20,"reasoning_output_tokens":8,"total_tokens":250}}}}
        """
    }
}
