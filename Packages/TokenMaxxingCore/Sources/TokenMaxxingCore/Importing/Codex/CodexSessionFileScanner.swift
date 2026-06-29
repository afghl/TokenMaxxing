import Foundation

struct CodexSessionFileScanner: SessionSourceScanner, @unchecked Sendable {
    let importerKind: SessionImporterKind = .codex

    private let root: URL
    private let fileManager: FileManager

    init(
        root: URL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(
            ".codex"),
        fileManager: FileManager = .default
    ) {
        self.root = root
        self.fileManager = fileManager
    }

    func sessionFileURLs() throws -> [URL] {
        try sourceFiles(root: root).map(\.url)
    }

    func scan(root: URL) throws -> [SourceLogFile] {
        try sourceFiles(root: root)
    }

    private func sourceFiles(root: URL) throws -> [SourceLogFile] {
        let roots = [
            root.appendingPathComponent("sessions", isDirectory: true),
            root.appendingPathComponent("archived_sessions", isDirectory: true),
        ]

        let files = try roots.flatMap { try jsonlFiles(under: $0) }
        tokenMaxxingDebugLog("Codex importer discovered \(files.count) session files")
        return files.sorted { $0.url.path < $1.url.path }
    }

    private func jsonlFiles(under directory: URL) throws -> [SourceLogFile] {
        guard fileManager.fileExists(atPath: directory.path) else {
            tokenMaxxingDebugLog("Codex importer directory not found or inaccessible: \(directory.path)")
            return []
        }

        guard let enumerator = fileManager.enumerator(
            at: directory,
            includingPropertiesForKeys: [
                .contentModificationDateKey,
                .fileSizeKey,
                .isRegularFileKey,
            ],
            options: [.skipsHiddenFiles]
        ) else {
            tokenMaxxingDebugLog("Codex importer could not enumerate directory: \(directory.path)")
            return []
        }

        var files: [SourceLogFile] = []
        for case let url as URL in enumerator where url.pathExtension == "jsonl" {
            let values = try url.resourceValues(forKeys: [
                .contentModificationDateKey,
                .fileSizeKey,
                .isRegularFileKey,
            ])
            guard values.isRegularFile == true else {
                continue
            }

            files.append(
                SourceLogFile(
                    importerKind: importerKind,
                    sessionID: Self.sessionID(for: url),
                    url: url,
                    modifiedAt: values.contentModificationDate ?? Date(timeIntervalSince1970: 0),
                    byteCount: Int64(values.fileSize ?? 0)
                )
            )
        }

        tokenMaxxingDebugLog("Codex importer found \(files.count) JSONL files under \(directory.path)")
        return files
    }

    static func sessionID(for url: URL) -> String {
        let fileName = url.deletingPathExtension().lastPathComponent
        let pattern = #"^rollout-\d{4}-\d{2}-\d{2}T\d{2}-\d{2}-\d{2}-(.+)$"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
            let match = regex.firstMatch(
                in: fileName,
                range: NSRange(fileName.startIndex..., in: fileName)
            ),
            let range = Range(match.range(at: 1), in: fileName)
        else {
            return fileName
        }

        return String(fileName[range])
    }
}
