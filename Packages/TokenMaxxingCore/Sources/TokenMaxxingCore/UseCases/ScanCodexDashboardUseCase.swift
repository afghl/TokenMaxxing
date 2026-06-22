import Foundation

public struct ScanCodexDashboardUseCase: Sendable {
    public let buildDashboard: BuildDashboardUseCase

    public init(buildDashboard: BuildDashboardUseCase = BuildDashboardUseCase()) {
        self.buildDashboard = buildDashboard
    }

    public func execute(
        root: URL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".codex"),
        now: Date = .now
    ) throws -> UsageDashboardMetrics {
        let sessions = try CodexSessionImporter(root: root).importSessions()
        return buildDashboard.execute(sessions: sessions, now: now)
    }
}
