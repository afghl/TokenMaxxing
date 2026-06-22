import Foundation

struct NumberedCodexEvent {
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

extension Array where Element == NumberedCodexEvent {
    var lastUsageSnapshot: TokenUsage? {
        compactMap(\.usageSnapshot).last
    }
}

struct CodexLogEntry: Decodable {
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

struct CodexPayload: Decodable {
    let type: String?
    let role: String?
    let message: String?
    let name: String?
    let info: CodexTokenInfo?
}

struct CodexTokenInfo: Decodable {
    let totalTokenUsage: CodexTokenUsage

    enum CodingKeys: String, CodingKey {
        case totalTokenUsage = "total_token_usage"
    }
}

struct CodexTokenUsage: Decodable {
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
