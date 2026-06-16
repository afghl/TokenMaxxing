import Foundation
import Observation

@Observable
public final class UsageDashboardState {
    public var selectedRange: UsageRange = .day
    public var status = "Updated just now"

    public let hourlyUsage: [TokenUsagePoint]
    public let dailyUsage: [TokenUsagePoint]
    public let monthlyUsage: [TokenUsagePoint]

    private let previousHourlyUsage: [TokenUsagePoint]
    private let previousDailyUsage: [TokenUsagePoint]
    private let previousMonthlyUsage: [TokenUsagePoint]

    public init(calendar: Calendar = .current, now: Date = .now) {
        hourlyUsage = Self.makeHourlyUsage(calendar: calendar, now: now)
        dailyUsage = Self.makeDailyUsage(calendar: calendar, now: now)
        monthlyUsage = Self.makeMonthlyUsage(calendar: calendar, now: now)
        previousHourlyUsage = Self.makePreviousHourlyUsage(calendar: calendar, now: now)
        previousDailyUsage = Self.makePreviousDailyUsage(calendar: calendar, now: now)
        previousMonthlyUsage = Self.makePreviousMonthlyUsage(calendar: calendar, now: now)
    }

    public var visibleUsage: [TokenUsagePoint] {
        switch selectedRange {
        case .day:
            hourlyUsage
        case .month:
            dailyUsage
        case .year:
            monthlyUsage
        }
    }

    public var totalTokens: Int {
        total(for: visibleUsage)
    }

    public var averageTokens: Int {
        guard !visibleUsage.isEmpty else { return 0 }
        return totalTokens / visibleUsage.count
    }

    public var peakUsage: TokenUsagePoint? {
        visibleUsage.max { $0.tokens < $1.tokens }
    }

    public var trendDescription: String {
        let previous = previousTotalTokens
        guard previous > 0 else { return "No previous period yet" }

        let difference = totalTokens - previous
        let percentage = Int((Double(abs(difference)) / Double(previous) * 100).rounded())
        let direction = difference >= 0 ? "Up" : "Down"
        return "\(direction) \(percentage)% vs \(selectedRange.previousPeriodLabel)"
    }

    public var projectedMonthTokens: Int {
        let elapsedDays = max(dailyUsage.count, 1)
        return (total(for: dailyUsage) / elapsedDays) * 30
    }

    public var weekAverageTokens: Int {
        let lastSevenDays = dailyUsage.suffix(7)
        guard !lastSevenDays.isEmpty else { return 0 }
        return lastSevenDays.reduce(0) { $0 + $1.tokens } / lastSevenDays.count
    }

    public func triggerScan() {
        status = "Local scan queued"
    }

    public func formatPeakLabel(_ point: TokenUsagePoint) -> String {
        switch selectedRange {
        case .day:
            point.date.formatted(.dateTime.hour(.defaultDigits(amPM: .abbreviated)))
        case .month:
            point.date.formatted(.dateTime.month(.abbreviated).day())
        case .year:
            point.date.formatted(.dateTime.month(.abbreviated))
        }
    }

    private var previousTotalTokens: Int {
        switch selectedRange {
        case .day:
            total(for: previousHourlyUsage)
        case .month:
            total(for: previousDailyUsage)
        case .year:
            total(for: previousMonthlyUsage)
        }
    }

    private func total(for points: [TokenUsagePoint]) -> Int {
        points.reduce(0) { $0 + $1.tokens }
    }
}

private extension UsageDashboardState {
    static func makeHourlyUsage(calendar: Calendar, now: Date) -> [TokenUsagePoint] {
        let values = [
            120, 80, 45, 30, 50, 90, 180, 420,
            740, 1_120, 1_560, 1_430, 860, 980, 1_680, 2_120,
            1_890, 1_460, 1_120, 760, 1_240, 1_520, 1_100, 540,
        ]
        return hourlyPoints(values: values, calendar: calendar, now: now, dayOffset: 0)
    }

    static func makePreviousHourlyUsage(calendar: Calendar, now: Date) -> [TokenUsagePoint] {
        let values = [
            90, 70, 40, 25, 45, 60, 140, 360,
            680, 1_000, 1_420, 1_350, 900, 920, 1_380, 1_710,
            1_560, 1_210, 960, 700, 1_050, 1_230, 890, 420,
        ]
        return hourlyPoints(values: values, calendar: calendar, now: now, dayOffset: -1)
    }

    static func makeDailyUsage(calendar: Calendar, now: Date) -> [TokenUsagePoint] {
        let values = [
            14_200, 17_450, 12_900, 19_800, 22_300, 18_750,
            16_400, 24_100, 21_260, 20_880, 15_930, 18_420,
            26_500, 29_700, 25_900, 24_640, 19_350, 17_880,
            23_700, 31_250, 28_940, 27_520, 22_430, 18_960,
            24_800, 30_100, 33_420, 29_860, 26_700, 27_255,
        ]
        return datedPoints(values: values, calendar: calendar, now: now, component: .day)
    }

    static func makePreviousDailyUsage(calendar: Calendar, now: Date) -> [TokenUsagePoint] {
        let values = [
            11_700, 13_850, 12_100, 15_920, 17_600, 14_300,
            13_750, 18_200, 19_440, 16_900, 13_280, 14_720,
            20_100, 21_850, 19_600, 17_930, 16_200, 14_780,
            18_460, 22_900, 21_330, 20_750, 17_220, 16_980,
            20_400, 23_600, 25_920, 22_180, 21_540, 23_200,
        ]
        guard let previousNow = calendar.date(byAdding: .day, value: -30, to: now) else {
            return []
        }
        return datedPoints(values: values, calendar: calendar, now: previousNow, component: .day)
    }

    static func makeMonthlyUsage(calendar: Calendar, now: Date) -> [TokenUsagePoint] {
        let values = [
            382_000, 424_500, 398_200, 456_900, 510_300, 488_000,
            534_700, 572_900, 625_400, 604_200, 642_800, 703_500,
        ]
        return datedPoints(values: values, calendar: calendar, now: now, component: .month)
    }

    static func makePreviousMonthlyUsage(calendar: Calendar, now: Date) -> [TokenUsagePoint] {
        let values = [
            308_000, 336_500, 329_200, 358_900, 396_300, 410_000,
            432_700, 451_900, 490_400, 482_200, 512_800, 556_500,
        ]
        guard let previousNow = calendar.date(byAdding: .year, value: -1, to: now) else {
            return []
        }
        return datedPoints(values: values, calendar: calendar, now: previousNow, component: .month)
    }

    static func hourlyPoints(values: [Int], calendar: Calendar, now: Date, dayOffset: Int) -> [TokenUsagePoint] {
        guard let targetDay = calendar.date(byAdding: .day, value: dayOffset, to: now) else {
            return []
        }

        let startOfDay = calendar.startOfDay(for: targetDay)
        return values.enumerated().compactMap { offset, value in
            guard let date = calendar.date(byAdding: .hour, value: offset, to: startOfDay) else {
                return nil
            }
            return TokenUsagePoint(date: date, tokens: value)
        }
    }

    static func datedPoints(values: [Int], calendar: Calendar, now: Date, component: Calendar.Component) -> [TokenUsagePoint] {
        let unitCount = values.count - 1
        return values.enumerated().compactMap { offset, value in
            guard let date = calendar.date(byAdding: component, value: offset - unitCount, to: now) else {
                return nil
            }

            let normalizedDate: Date
            if component == .day {
                normalizedDate = calendar.startOfDay(for: date)
            } else {
                let parts = calendar.dateComponents([.year, .month], from: date)
                normalizedDate = calendar.date(from: parts) ?? date
            }

            return TokenUsagePoint(date: normalizedDate, tokens: value)
        }
    }
}
