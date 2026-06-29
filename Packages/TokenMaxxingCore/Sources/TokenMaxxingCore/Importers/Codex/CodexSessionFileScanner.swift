import Foundation

struct CodexSessionFileScanner: SessionSourceScanner {
    let importerKind: SessionImporterKind = .codex

    func scan(root: URL) throws -> [SourceLogFile] {
        let fileManager = FileManager.default
        let roots = [
            root.appendingPathComponent("sessions", isDirectory: true),
            root.appendingPathComponent("archived_sessions", isDirectory: true),
        ]

        var files: [SourceLogFile] = []
        for directory in roots {
            guard fileManager.fileExists(atPath: directory.path),
                let enumerator = fileManager.enumerator(
                    at: directory,
                    includingPropertiesForKeys: [
                        .contentModificationDateKey,
                        .fileSizeKey,
                        .isRegularFileKey,
                    ],
                    options: [.skipsHiddenFiles]
                )
            else {
                continue
            }

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
                        modifiedAt: values.contentModificationDate
                            ?? Date(timeIntervalSince1970: 0),
                        byteCount: Int64(values.fileSize ?? 0)
                    )
                )
            }
        }

        return files.sorted { $0.url.path < $1.url.path }
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
