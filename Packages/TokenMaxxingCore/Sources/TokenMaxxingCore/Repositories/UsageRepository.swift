import Foundation

protocol UsageRepository: Sendable {
    func prepare() async throws

    func loadSourceFiles(for importerKind: SessionImporterKind) async throws -> [StoredSourceLogFile]

    func replaceImportedSession(
        _ session: Session,
        sourceFile: SourceLogFile,
        importedAt: Date
    ) async throws

    func markSourceFileMissing(
        _ sourceFile: StoredSourceLogFile,
        missingAt: Date
    ) async throws

    func loadSessions(matching query: SessionQuery) async throws -> [Session]
}

struct StoredSourceLogFile: Equatable, Sendable {
    let importerKind: SessionImporterKind
    let sessionID: Session.ID
    let path: String
    let modifiedAt: Date
    let byteCount: Int64
    let importedAt: Date
    let missingAt: Date?

    var fingerprint: SourceLogFileFingerprint {
        SourceLogFileFingerprint(modifiedAt: modifiedAt, byteCount: byteCount)
    }
}

struct SessionQuery: Equatable, Sendable {
    var importerKinds: Set<SessionImporterKind>?
    var startedAtOrAfter: Date?
    var startedBefore: Date?

    static let all = SessionQuery()

    init(
        importerKinds: Set<SessionImporterKind>? = nil,
        startedAtOrAfter: Date? = nil,
        startedBefore: Date? = nil
    ) {
        self.importerKinds = importerKinds
        self.startedAtOrAfter = startedAtOrAfter
        self.startedBefore = startedBefore
    }
}

struct SourceLogFileFingerprint: Equatable, Sendable {
    let modifiedAt: Date
    let byteCount: Int64

    func matches(_ sourceFile: SourceLogFile) -> Bool {
        byteCount == sourceFile.byteCount
            && abs(modifiedAt.timeIntervalSince(sourceFile.modifiedAt)) < 0.001
    }
}
