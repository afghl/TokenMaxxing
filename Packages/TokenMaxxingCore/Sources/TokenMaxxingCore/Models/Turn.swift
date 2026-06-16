import Foundation

public enum TurnStatus: String, Equatable, Sendable {
    case completed
    case inProgress
}

public struct Turn: Identifiable, Equatable, Sendable {
    public let id: String
    public let startedAt: Date
    public let completedAt: Date?
    public let messages: [Message]
    public let usage: TokenUsage?

    public var status: TurnStatus {
        completedAt == nil ? .inProgress : .completed
    }

    public var userMessage: Message? {
        messages.first { $0.role == .user }
    }

    public var workedDuration: TimeInterval? {
        guard let completedAt else { return nil }
        return completedAt.timeIntervalSince(startedAt)
    }

    public init(
        id: String,
        startedAt: Date,
        completedAt: Date?,
        messages: [Message],
        usage: TokenUsage?
    ) {
        self.id = id
        self.startedAt = startedAt
        self.completedAt = completedAt
        self.messages = messages
        self.usage = usage
    }
}
