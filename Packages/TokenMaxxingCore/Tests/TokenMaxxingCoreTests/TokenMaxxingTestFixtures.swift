import Foundation

enum TokenMaxxingTestFixtures {
    static let sessionID = "019ecfc2-0c2b-71a3-bb30-b55331de26ad"
    static let fileName = "rollout-2026-06-16T09-00-00-\(sessionID).jsonl"

    static func temporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("TokenMaxxingCoreTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    static func writeCodexSession(
        root: URL,
        contents: String = codexFixture(),
        archived: Bool = false,
        fileName: String = fileName,
        modifiedAt: Date? = nil
    ) throws -> URL {
        let directory = root
            .appendingPathComponent(archived ? "archived_sessions" : "sessions", isDirectory: true)
            .appendingPathComponent("2026/06/16", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let url = directory.appendingPathComponent(fileName)
        try contents.write(to: url, atomically: true, encoding: .utf8)

        if let modifiedAt {
            try FileManager.default.setAttributes(
                [.modificationDate: modifiedAt],
                ofItemAtPath: url.path
            )
        }

        return url
    }

    static func codexFixture(includeSecondTurn: Bool = false) -> String {
        let secondTurn = includeSecondTurn
            ? """
            {"timestamp":"2026-06-16T10:00:00.000Z","type":"event_msg","payload":{"type":"task_started"}}
            {"timestamp":"2026-06-16T10:00:01.000Z","type":"event_msg","payload":{"type":"user_message","message":"second turn"}}
            {"timestamp":"2026-06-16T10:00:02.000Z","type":"event_msg","payload":{"type":"token_count","info":{"total_token_usage":{"input_tokens":250,"cached_input_tokens":0,"output_tokens":0,"reasoning_output_tokens":0,"total_tokens":250}}}}
            {"timestamp":"2026-06-16T10:00:03.000Z","type":"event_msg","payload":{"type":"task_complete"}}
            """
            : ""

        return """
        {"timestamp":"2026-06-16T09:00:00.000Z","type":"session_meta","payload":{}}
        {"timestamp":"2026-06-16T09:00:00.500Z","type":"event_msg","payload":{"type":"task_started"}}
        {"timestamp":"2026-06-16T09:00:01.000Z","type":"event_msg","payload":{"type":"user_message","message":"first turn"}}
        {"timestamp":"2026-06-16T09:00:02.000Z","type":"event_msg","payload":{"type":"token_count","info":{"total_token_usage":{"input_tokens":100,"cached_input_tokens":0,"output_tokens":0,"reasoning_output_tokens":0,"total_tokens":100}}}}
        {"timestamp":"2026-06-16T09:00:03.000Z","type":"event_msg","payload":{"type":"task_complete"}}
        \(secondTurn)
        """
    }
}
