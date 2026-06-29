import Foundation

struct CodexUsageSyncService: Sendable {
    private let repository: any UsageRepository
    private let scanner: any SessionSourceScanner

    init(
        repository: any UsageRepository,
        scanner: any SessionSourceScanner = CodexSessionFileScanner()
    ) {
        self.repository = repository
        self.scanner = scanner
    }

    func sync(root: URL, importedAt: Date) async throws {
        try await repository.prepare()

        let sourceFiles = try scanner.scan(root: root)
        let storedSourceFiles = try await repository.loadSourceFiles(for: scanner.importerKind)
        let storedByPath = Dictionary(uniqueKeysWithValues: storedSourceFiles.map { ($0.path, $0) })
        let currentPaths = Set(sourceFiles.map { $0.url.path })

        for sourceFile in sourceFiles {
            if let storedSourceFile = storedByPath[sourceFile.url.path],
                storedSourceFile.missingAt == nil,
                storedSourceFile.fingerprint.matches(sourceFile)
            {
                continue
            }

            let session = try CodexSessionImporter(root: root).importSession(at: sourceFile.url)
            try await repository.replaceImportedSession(
                session,
                sourceFile: sourceFile,
                importedAt: importedAt
            )
        }

        for storedSourceFile in storedSourceFiles where !currentPaths.contains(storedSourceFile.path) {
            guard storedSourceFile.missingAt == nil else {
                continue
            }
            try await repository.markSourceFileMissing(storedSourceFile, missingAt: importedAt)
        }
    }
}
