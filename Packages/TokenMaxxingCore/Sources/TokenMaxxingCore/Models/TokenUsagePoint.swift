import Foundation

public struct TokenUsagePoint: Identifiable, Equatable, Sendable {
    public let date: Date
    public let tokens: Int

    public var id: Date { date }

    public init(date: Date, tokens: Int) {
        self.date = date
        self.tokens = tokens
    }
}
