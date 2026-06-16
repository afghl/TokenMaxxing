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
    public let preview: String?
    public let usageSnapshot: TokenUsage?
    public let rawType: String?
    public let sourceLine: Int?

    public init(
        id: String,
        role: MessageRole,
        timestamp: Date,
        preview: String? = nil,
        usageSnapshot: TokenUsage? = nil,
        rawType: String? = nil,
        sourceLine: Int? = nil
    ) {
        self.id = id
        self.role = role
        self.timestamp = timestamp
        self.preview = preview
        self.usageSnapshot = usageSnapshot
        self.rawType = rawType
        self.sourceLine = sourceLine
    }
}
