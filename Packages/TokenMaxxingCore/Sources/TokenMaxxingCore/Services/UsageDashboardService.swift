import Foundation

public final class UsageDashboardService: @unchecked Sendable {
    private let databaseURL: URL?

    public init(databaseURL: URL? = nil) {
        self.databaseURL = databaseURL
    }

    public func refreshFromCodexLogs(
        root: URL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(
            ".codex"),
        now: Date = .now,
        calendar: Calendar = .current,
        configuration: UsageDashboardConfiguration = UsageDashboardConfiguration()
    ) async throws -> UsageDashboardMetrics {
        let repository = SQLiteUsageRepository(databaseURL: try resolvedDatabaseURL())
        let syncService = CodexUsageSyncService(repository: repository)

        try await syncService.sync(root: root, importedAt: now)
        let sessions = try await repository.loadSessions(
            matching: SessionQuery(importerKinds: [.codex])
        )

        return TokenUsageAggregator.dashboardMetrics(
            from: sessions,
            calendar: calendar,
            now: now,
            dayBucketMinutes: configuration.dayBucketMinutes
        )
    }

    private func resolvedDatabaseURL() throws -> URL {
        if let databaseURL {
            return databaseURL
        }

        let baseURL = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first ?? FileManager.default.temporaryDirectory

        return baseURL
            .appendingPathComponent("TokenMaxxing", isDirectory: true)
            .appendingPathComponent("TokenMaxxing.sqlite3")
    }
}
