import Foundation

public struct SourceLogFile: Equatable, Sendable {
    public let importerKind: SessionImporterKind
    public let sessionID: Session.ID
    public let url: URL
    public let modifiedAt: Date
    public let byteCount: Int64

    public init(
        importerKind: SessionImporterKind,
        sessionID: Session.ID,
        url: URL,
        modifiedAt: Date,
        byteCount: Int64
    ) {
        self.importerKind = importerKind
        self.sessionID = sessionID
        self.url = url
        self.modifiedAt = modifiedAt
        self.byteCount = byteCount
    }
}
