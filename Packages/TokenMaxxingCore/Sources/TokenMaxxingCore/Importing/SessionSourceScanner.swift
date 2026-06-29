import Foundation

protocol SessionSourceScanner: Sendable {
    var importerKind: SessionImporterKind { get }

    func scan(root: URL) throws -> [SourceLogFile]
}
