public struct UsageDashboardConfiguration: Equatable, Sendable {
    public static let dayBucketMinutesRange = 1...60
    public static let defaultDayBucketMinutes = 10

    public let dayBucketMinutes: Int

    public init(dayBucketMinutes: Int = Self.defaultDayBucketMinutes) {
        self.dayBucketMinutes = Self.normalizedDayBucketMinutes(dayBucketMinutes)
    }

    public static func normalizedDayBucketMinutes(_ minutes: Int) -> Int {
        min(max(minutes, dayBucketMinutesRange.lowerBound), dayBucketMinutesRange.upperBound)
    }
}
