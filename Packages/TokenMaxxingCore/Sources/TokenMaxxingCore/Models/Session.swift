import Foundation

public enum SessionSource: Equatable, Sendable {
    case codex(path: String)
    case claudeCode(path: String)
    case openCode(path: String)
    case unknown(path: String?)
}

public struct Session: Identifiable, Equatable, Sendable {
    public let id: String
    public let source: SessionSource
    public let startedAt: Date
    public let endedAt: Date?
    public let turns: [Turn]
    public let totalUsage: TokenUsage?

    public var messages: [Message] {
        turns.flatMap(\.messages)
    }

    public var completedWorkedDuration: TimeInterval {
        turns.compactMap(\.workedDuration).reduce(0, +)
    }

    public init(
        id: String,
        source: SessionSource,
        startedAt: Date,
        endedAt: Date?,
        turns: [Turn],
        totalUsage: TokenUsage?
    ) {
        self.id = id
        self.source = source
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.turns = turns
        self.totalUsage = totalUsage
    }
}
