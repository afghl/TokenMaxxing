import Foundation

public final class CodexSessionImporter: SessionImporter {
    public let root: URL

    private let decoder: CodexLogDecoder
    private let fileScanner: CodexSessionFileScanner
    private let turnBuilder: CodexTurnBuilder

    public init(
        root: URL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".codex"),
        fileManager: FileManager = .default
    ) {
        self.root = root
        decoder = CodexLogDecoder()
        fileScanner = CodexSessionFileScanner(root: root, fileManager: fileManager)
        turnBuilder = CodexTurnBuilder()
    }

    public func importSessions() throws -> [Session] {
        tokenMaxxingDebugLog("Codex importer scanning root: \(root.path)")
        let urls = try fileScanner.sessionFileURLs()
        tokenMaxxingDebugLog("Codex importer found \(urls.count) JSONL files")

        let sessions = try urls
            .compactMap { try importSession(at: $0) }
            .sorted { $0.startedAt > $1.startedAt }
        tokenMaxxingDebugLog("Codex importer imported \(sessions.count) sessions")
        return sessions
    }

    public func importSession(id: Session.ID) throws -> Session? {
        guard let url = try fileScanner.sessionFileURLs().first(where: { Self.sessionID(for: $0) == id }) else {
            return nil
        }

        return try importSession(at: url)
    }

    public func importSession(at url: URL) throws -> Session {
        let events = try decoder.readEvents(at: url)
        guard let firstEvent = events.first, let lastEvent = events.last else {
            tokenMaxxingDebugLog("Codex importer found empty session file: \(url.path)")
            throw CodexSessionImportError.emptySession(url)
        }

        let sessionID = Self.sessionID(for: url)
        let turns = turnBuilder.buildTurns(from: events, sessionID: sessionID)
        let totalUsage = events.lastUsageSnapshot
        let endedAt = turns.last?.status == .inProgress ? nil : lastEvent.event.timestamp
        tokenMaxxingDebugLog(
            "Codex session \(sessionID): events=\(events.count), turns=\(turns.count), totalTokens=\(totalUsage?.totalTokens ?? 0)"
        )

        return Session(
            id: sessionID,
            source: .codex(path: url.path),
            startedAt: firstEvent.event.timestamp,
            endedAt: endedAt,
            turns: turns,
            totalUsage: totalUsage
        )
    }

    private static func sessionID(for url: URL) -> String {
        let fileName = url.deletingPathExtension().lastPathComponent
        let pattern = #"^rollout-\d{4}-\d{2}-\d{2}T\d{2}-\d{2}-\d{2}-(.+)$"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(
                in: fileName,
                range: NSRange(fileName.startIndex..., in: fileName)
              ),
              let range = Range(match.range(at: 1), in: fileName)
        else {
            return fileName
        }

        return String(fileName[range])
    }
}

public enum CodexSessionImportError: Error, Equatable, LocalizedError {
    case emptySession(URL)
    case decodingFailed(URL, line: Int)

    public var errorDescription: String? {
        switch self {
        case let .emptySession(url):
            "Empty Codex session file: \(url.path)"
        case let .decodingFailed(url, line):
            "Failed to decode Codex session file \(url.path) at line \(line)"
        }
    }
}
