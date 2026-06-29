import XCTest
@testable import TokenMaxxingCore

final class CodexSessionFileScannerTests: XCTestCase {
    func testScannerFindsCodexSessionFilesAndMetadata() throws {
        let root = try TokenMaxxingTestFixtures.temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }

        let modifiedAt = Date(timeIntervalSince1970: 1_780_000_000)
        let activeURL = try TokenMaxxingTestFixtures.writeCodexSession(
            root: root,
            modifiedAt: modifiedAt
        )
        _ = try TokenMaxxingTestFixtures.writeCodexSession(
            root: root,
            archived: true,
            fileName: "plain-session-name.jsonl"
        )
        let ignoredURL = activeURL.deletingLastPathComponent().appendingPathComponent("ignored.txt")
        try "not jsonl".write(to: ignoredURL, atomically: true, encoding: .utf8)

        let files = try CodexSessionFileScanner().scan(root: root)

        XCTAssertEqual(files.count, 2)
        XCTAssertEqual(files.map(\.sessionID), [
            "plain-session-name",
            TokenMaxxingTestFixtures.sessionID,
        ])

        let activeFile = try XCTUnwrap(
            files.first { $0.sessionID == TokenMaxxingTestFixtures.sessionID }
        )
        XCTAssertEqual(activeFile.importerKind, .codex)
        XCTAssertEqual(activeFile.modifiedAt.timeIntervalSince1970, modifiedAt.timeIntervalSince1970, accuracy: 0.001)
        XCTAssertEqual(activeFile.byteCount, Int64(TokenMaxxingTestFixtures.codexFixture().utf8.count))
    }
}
