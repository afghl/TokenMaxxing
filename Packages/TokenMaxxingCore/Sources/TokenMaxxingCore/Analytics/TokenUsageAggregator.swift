import Foundation

public enum TokenUsageAggregator {
    public static func dashboardMetrics(
        from sessions: [Session],
        calendar: Calendar = .current,
        now: Date = .now,
        dayBucketMinutes: Int = UsageDashboardConfiguration.defaultDayBucketMinutes
    ) -> UsageDashboardMetrics {
        let previousDay = calendar.date(byAdding: .day, value: -1, to: now) ?? now
        let previousThirtyDays = calendar.date(byAdding: .day, value: -30, to: now) ?? now
        let previousYear = calendar.date(byAdding: .year, value: -1, to: now) ?? now
        let turns = sessions.flatMap(\.turns)
        let dayBucketMinutes = UsageDashboardConfiguration.normalizedDayBucketMinutes(dayBucketMinutes)

        return UsageDashboardMetrics(
            intradayUsage: intradayUsage(
                from: sessions,
                calendar: calendar,
                dayContaining: now,
                bucketMinutes: dayBucketMinutes
            ),
            hourlyUsage: hourlyUsage(from: sessions, calendar: calendar, dayContaining: now),
            dailyUsage: dailyUsage(from: sessions, calendar: calendar, days: 30, endingAt: now),
            monthlyUsage: monthlyUsage(from: sessions, calendar: calendar, months: 12, endingAt: now),
            previousIntradayUsage: intradayUsage(
                from: sessions,
                calendar: calendar,
                dayContaining: previousDay,
                bucketMinutes: dayBucketMinutes
            ),
            previousHourlyUsage: hourlyUsage(from: sessions, calendar: calendar, dayContaining: previousDay),
            previousDailyUsage: dailyUsage(from: sessions, calendar: calendar, days: 30, endingAt: previousThirtyDays),
            previousMonthlyUsage: monthlyUsage(from: sessions, calendar: calendar, months: 12, endingAt: previousYear),
            sessionCount: sessions.count,
            turnCount: turns.count,
            latestActivityAt: turns.map { $0.completedAt ?? $0.startedAt }.max()
        )
    }

    public static func intradayUsage(
        from sessions: [Session],
        calendar: Calendar = .current,
        dayContaining date: Date = .now,
        bucketMinutes: Int = UsageDashboardConfiguration.defaultDayBucketMinutes
    ) -> [TokenUsagePoint] {
        let start = calendar.startOfDay(for: date)
        let bucketMinutes = UsageDashboardConfiguration.normalizedDayBucketMinutes(bucketMinutes)
        let totals = intradayTokenTotals(
            from: sessions,
            calendar: calendar,
            dayStart: start,
            bucketMinutes: bucketMinutes
        )
        let bucketCount = (minutesPerDay + bucketMinutes - 1) / bucketMinutes

        return (0..<bucketCount).compactMap { offset in
            guard let date = calendar.date(byAdding: .minute, value: offset * bucketMinutes, to: start) else {
                return nil
            }
            return TokenUsagePoint(date: date, tokens: totals[date, default: 0])
        }
    }

    public static func hourlyUsage(
        from sessions: [Session],
        calendar: Calendar = .current,
        dayContaining date: Date = .now
    ) -> [TokenUsagePoint] {
        let start = calendar.startOfDay(for: date)
        return points(
            from: sessions,
            calendar: calendar,
            component: .hour,
            start: start,
            count: 24
        )
    }

    public static func dailyUsage(
        from sessions: [Session],
        calendar: Calendar = .current,
        days: Int = 30,
        endingAt date: Date = .now
    ) -> [TokenUsagePoint] {
        guard days > 0 else { return [] }

        let end = calendar.startOfDay(for: date)
        guard let start = calendar.date(byAdding: .day, value: 1 - days, to: end) else {
            return []
        }

        return points(
            from: sessions,
            calendar: calendar,
            component: .day,
            start: start,
            count: days
        )
    }

    public static func monthlyUsage(
        from sessions: [Session],
        calendar: Calendar = .current,
        months: Int = 12,
        endingAt date: Date = .now
    ) -> [TokenUsagePoint] {
        guard months > 0 else { return [] }

        let end = startOfMonth(containing: date, calendar: calendar)
        guard let start = calendar.date(byAdding: .month, value: 1 - months, to: end) else {
            return []
        }

        return points(
            from: sessions,
            calendar: calendar,
            component: .month,
            start: start,
            count: months
        )
    }
}

private extension TokenUsageAggregator {
    static var minutesPerDay: Int { 24 * 60 }

    static func points(
        from sessions: [Session],
        calendar: Calendar,
        component: Calendar.Component,
        start: Date,
        count: Int
    ) -> [TokenUsagePoint] {
        let totals = tokenTotals(from: sessions, calendar: calendar, component: component)

        return (0..<count).compactMap { offset in
            guard let date = calendar.date(byAdding: component, value: offset, to: start) else {
                return nil
            }
            return TokenUsagePoint(date: date, tokens: totals[date, default: 0])
        }
    }

    static func tokenTotals(
        from sessions: [Session],
        calendar: Calendar,
        component: Calendar.Component
    ) -> [Date: Int] {
        sessions
            .flatMap(\.turns)
            .reduce(into: [:]) { totals, turn in
                guard let tokens = turn.usage?.totalTokens else {
                    return
                }

                let date = bucketStart(for: turn.startedAt, calendar: calendar, component: component)
                totals[date, default: 0] += tokens
            }
    }

    static func intradayTokenTotals(
        from sessions: [Session],
        calendar: Calendar,
        dayStart: Date,
        bucketMinutes: Int
    ) -> [Date: Int] {
        guard let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) else {
            return [:]
        }

        return sessions
            .flatMap(\.turns)
            .reduce(into: [:]) { totals, turn in
                guard let tokens = turn.usage?.totalTokens,
                      turn.startedAt >= dayStart,
                      turn.startedAt < dayEnd
                else {
                    return
                }

                let minuteOffset = calendar
                    .dateComponents([.minute], from: dayStart, to: turn.startedAt)
                    .minute ?? 0
                let bucketOffset = (minuteOffset / bucketMinutes) * bucketMinutes

                guard let date = calendar.date(byAdding: .minute, value: bucketOffset, to: dayStart) else {
                    return
                }
                totals[date, default: 0] += tokens
            }
    }

    static func bucketStart(
        for date: Date,
        calendar: Calendar,
        component: Calendar.Component
    ) -> Date {
        switch component {
        case .minute:
            let parts = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
            return calendar.date(from: parts) ?? date
        case .hour:
            let parts = calendar.dateComponents([.year, .month, .day, .hour], from: date)
            return calendar.date(from: parts) ?? date
        case .day:
            return calendar.startOfDay(for: date)
        case .month:
            return startOfMonth(containing: date, calendar: calendar)
        default:
            return date
        }
    }

    static func startOfMonth(containing date: Date, calendar: Calendar) -> Date {
        let parts = calendar.dateComponents([.year, .month], from: date)
        return calendar.date(from: parts) ?? calendar.startOfDay(for: date)
    }
}
