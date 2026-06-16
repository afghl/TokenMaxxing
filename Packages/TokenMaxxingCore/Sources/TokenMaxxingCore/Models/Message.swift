import Foundation

public enum MessageRole: String, Equatable, Sendable {
    case user
    case assistant
    case tool
    case system
    case `internal`
}

public struct Message: Identifiable, Equatable, Sendable {
    public let id: String
    public let role: MessageRole
    public let timestamp: Date
    public let text: String?
    public let usageSnapshot: TokenUsage?
    public let rawType: String?
    public let sourceLine: Int?

    public init(
        id: String,
        role: MessageRole,
        timestamp: Date,
        text: String? = nil,
        usageSnapshot: TokenUsage? = nil,
        rawType: String? = nil,
        sourceLine: Int? = nil
    ) {
        self.id = id
        self.role = role
        self.timestamp = timestamp
        self.text = text
        self.usageSnapshot = usageSnapshot
        self.rawType = rawType
        self.sourceLine = sourceLine
    }
}
