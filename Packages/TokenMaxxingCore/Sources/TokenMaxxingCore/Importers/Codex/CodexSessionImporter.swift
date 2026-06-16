import Foundation

public final class CodexSessionImporter: SessionImporter {
    public let root: URL

    private let fileManager: FileManager

    public init(
        root: URL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".codex"),
        fileManager: FileManager = .default
    ) {
        self.root = root
        self.fileManager = fileManager
    }

    public func importSessions() throws -> [Session] {
        tokenMaxxingDebugLog("Codex importer scanning root: \(root.path)")
        let urls = try sessionFileURLs()
        tokenMaxxingDebugLog("Codex importer found \(urls.count) JSONL files")

        let sessions = try urls
            .compactMap { try importSession(at: $0) }
            .sorted { $0.startedAt > $1.startedAt }
        tokenMaxxingDebugLog("Codex importer imported \(sessions.count) sessions")
        return sessions
    }

    public func importSession(id: Session.ID) throws -> Session? {
        guard let url = try sessionFileURLs().first(where: { sessionID(for: $0) == id }) else {
            return nil
        }

        return try importSession(at: url)
    }

    public func importSession(at url: URL) throws -> Session {
        let events = try readEvents(at: url)
        guard let firstEvent = events.first, let lastEvent = events.last else {
            tokenMaxxingDebugLog("Codex importer found empty session file: \(url.path)")
            throw CodexSessionImportError.emptySession(url)
        }

        let sessionID = sessionID(for: url)
        let turns = buildTurns(from: events, sessionID: sessionID)
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

private extension CodexSessionImporter {
    func sessionFileURLs() throws -> [URL] {
        var urls: [URL] = []

        let sessionsRoot = root.appendingPathComponent("sessions", isDirectory: true)
        urls.append(contentsOf: try jsonlFiles(under: sessionsRoot))

        let archivedRoot = root.appendingPathComponent("archived_sessions", isDirectory: true)
        urls.append(contentsOf: try jsonlFiles(under: archivedRoot))

        tokenMaxxingDebugLog("Codex importer discovered \(urls.count) session files")
        return urls.sorted { $0.path < $1.path }
    }

    func jsonlFiles(under directory: URL) throws -> [URL] {
        guard fileManager.fileExists(atPath: directory.path) else {
            tokenMaxxingDebugLog("Codex importer directory not found or inaccessible: \(directory.path)")
            return []
        }

        guard let enumerator = fileManager.enumerator(
            at: directory,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            tokenMaxxingDebugLog("Codex importer could not enumerate directory: \(directory.path)")
            return []
        }

        var urls: [URL] = []
        for case let url as URL in enumerator where url.pathExtension == "jsonl" {
            let values = try url.resourceValues(forKeys: [.isRegularFileKey])
            if values.isRegularFile == true {
                urls.append(url)
            }
        }
        tokenMaxxingDebugLog("Codex importer found \(urls.count) JSONL files under \(directory.path)")
        return urls
    }

    func readEvents(at url: URL) throws -> [NumberedCodexEvent] {
        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch {
            tokenMaxxingDebugLog("Codex importer could not read \(url.path): \(error.localizedDescription)")
            throw error
        }
        let contents = String(decoding: data, as: UTF8.self)
        let decoder = JSONDecoder()

        return try contents
            .split(separator: "\n", omittingEmptySubsequences: false)
            .enumerated()
            .compactMap { offset, line in
                let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else {
                    return nil
                }

                do {
                    let event = try decoder.decode(CodexLogEntry.self, from: Data(trimmed.utf8))
                    return NumberedCodexEvent(event: event, line: offset + 1)
                } catch {
                    tokenMaxxingDebugLog(
                        "Codex importer decode failed at \(url.path):\(offset + 1): \(error.localizedDescription)"
                    )
                    throw CodexSessionImportError.decodingFailed(url, line: offset + 1)
                }
            }
    }

    func buildTurns(from events: [NumberedCodexEvent], sessionID: String) -> [Turn] {
        let userEventIndices = events.indices.filter { events[$0].isEventMessage("user_message") }

        return userEventIndices.enumerated().map { offset, startIndex in
            let nextStartIndex = userEventIndices.dropFirst(offset + 1).first ?? events.endIndex
            let window = Array(events[startIndex..<nextStartIndex])
            let beforeUsage = Array(events[..<startIndex]).lastUsageSnapshot
            let latestUsage = window.lastUsageSnapshot
            let usage = latestUsage?.subtracting(beforeUsage)
            let completedAt = window.first { $0.isEventMessage("task_complete") }?.event.timestamp
            let messages = window.compactMap { makeMessage(from: $0, sessionID: sessionID) }

            return Turn(
                id: "\(sessionID)-turn-\(offset + 1)",
                startedAt: events[startIndex].event.timestamp,
                completedAt: completedAt,
                messages: messages,
                usage: usage
            )
        }
    }

    func makeMessage(from event: NumberedCodexEvent, sessionID: String) -> Message? {
        let rawType = event.rawType
        let messageID = "\(sessionID):\(event.line)"

        if event.event.type == "event_msg" {
            switch event.event.payload?.type {
            case "user_message":
                return Message(
                    id: messageID,
                    role: .user,
                    timestamp: event.event.timestamp,
                    preview: event.event.payload?.message?.trimmedPreview(),
                    rawType: rawType,
                    sourceLine: event.line
                )
            case "agent_message":
                return Message(
                    id: messageID,
                    role: .assistant,
                    timestamp: event.event.timestamp,
                    preview: event.event.payload?.message?.trimmedPreview(),
                    rawType: rawType,
                    sourceLine: event.line
                )
            case "token_count":
                return Message(
                    id: messageID,
                    role: .internal,
                    timestamp: event.event.timestamp,
                    usageSnapshot: event.usageSnapshot,
                    rawType: rawType,
                    sourceLine: event.line
                )
            case .some:
                return Message(
                    id: messageID,
                    role: .internal,
                    timestamp: event.event.timestamp,
                    rawType: rawType,
                    sourceLine: event.line
                )
            case .none:
                return nil
            }
        }

        guard event.event.type == "response_item" else {
            return nil
        }

        switch event.event.payload?.type {
        case "function_call":
            return Message(
                id: messageID,
                role: .tool,
                timestamp: event.event.timestamp,
                preview: event.event.payload?.name?.trimmedPreview(),
                rawType: rawType,
                sourceLine: event.line
            )
        case "function_call_output":
            return Message(
                id: messageID,
                role: .tool,
                timestamp: event.event.timestamp,
                rawType: rawType,
                sourceLine: event.line
            )
        case "reasoning":
            return Message(
                id: messageID,
                role: .internal,
                timestamp: event.event.timestamp,
                rawType: rawType,
                sourceLine: event.line
            )
        default:
            return nil
        }
    }

    func sessionID(for url: URL) -> String {
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

private struct NumberedCodexEvent {
    let event: CodexLogEntry
    let line: Int

    var rawType: String {
        [event.type, event.payload?.type].compactMap { $0 }.joined(separator: ".")
    }

    var usageSnapshot: TokenUsage? {
        guard isEventMessage("token_count") else {
            return nil
        }
        return event.payload?.info?.totalTokenUsage.tokenUsage
    }

    func isEventMessage(_ payloadType: String) -> Bool {
        event.type == "event_msg" && event.payload?.type == payloadType
    }
}

private extension Array where Element == NumberedCodexEvent {
    var lastUsageSnapshot: TokenUsage? {
        compactMap(\.usageSnapshot).last
    }
}

private struct CodexLogEntry: Decodable {
    let timestamp: Date
    let type: String
    let payload: CodexPayload?

    enum CodingKeys: String, CodingKey {
        case timestamp
        case type
        case payload
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let timestampString = try container.decode(String.self, forKey: .timestamp)

        guard let timestamp = Self.dateFormatter.date(from: timestampString)
            ?? Self.fallbackDateFormatter.date(from: timestampString)
        else {
            throw DecodingError.dataCorruptedError(
                forKey: .timestamp,
                in: container,
                debugDescription: "Invalid ISO8601 timestamp: \(timestampString)"
            )
        }

        self.timestamp = timestamp
        type = try container.decode(String.self, forKey: .type)
        payload = try container.decodeIfPresent(CodexPayload.self, forKey: .payload)
    }

    private static let dateFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static let fallbackDateFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()
}

private struct CodexPayload: Decodable {
    let type: String?
    let role: String?
    let message: String?
    let name: String?
    let info: CodexTokenInfo?
}

private extension String {
    func trimmedPreview(limit: Int = 160) -> String {
        let normalized = split(whereSeparator: \.isWhitespace).joined(separator: " ")
        guard normalized.count > limit else {
            return normalized
        }

        let end = normalized.index(normalized.startIndex, offsetBy: limit)
        return String(normalized[..<end])
    }
}

private struct CodexTokenInfo: Decodable {
    let totalTokenUsage: CodexTokenUsage

    enum CodingKeys: String, CodingKey {
        case totalTokenUsage = "total_token_usage"
    }
}

private struct CodexTokenUsage: Decodable {
    let inputTokens: Int
    let cachedInputTokens: Int
    let outputTokens: Int
    let reasoningOutputTokens: Int
    let totalTokens: Int

    var tokenUsage: TokenUsage {
        TokenUsage(
            inputTokens: inputTokens,
            cachedInputTokens: cachedInputTokens,
            outputTokens: outputTokens,
            reasoningOutputTokens: reasoningOutputTokens,
            totalTokens: totalTokens
        )
    }

    enum CodingKeys: String, CodingKey {
        case inputTokens = "input_tokens"
        case cachedInputTokens = "cached_input_tokens"
        case outputTokens = "output_tokens"
        case reasoningOutputTokens = "reasoning_output_tokens"
        case totalTokens = "total_tokens"
    }
}
