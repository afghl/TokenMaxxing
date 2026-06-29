import Foundation

public struct IntradayUsageComparison: Equatable, Sendable {
    public let dayStart: Date
    public let dayEnd: Date
    public let referenceDate: Date
    public let currentUsage: [TokenUsagePoint]
    public let averageUsage: [TokenUsagePoint]
    public let currentTotal: Int
    public let averageTotal: Int

    public init(
        dayStart: Date,
        dayEnd: Date,
        referenceDate: Date,
        currentUsage: [TokenUsagePoint],
        averageUsage: [TokenUsagePoint],
        currentTotal: Int,
        averageTotal: Int
    ) {
        self.dayStart = dayStart
        self.dayEnd = dayEnd
        self.referenceDate = referenceDate
        self.currentUsage = currentUsage
        self.averageUsage = averageUsage
        self.currentTotal = currentTotal
        self.averageTotal = averageTotal
    }
}
