import Foundation

struct CodexSessionFileScanner {
    let root: URL
    let fileManager: FileManager

    init(root: URL, fileManager: FileManager = .default) {
        self.root = root
        self.fileManager = fileManager
    }

    func sessionFileURLs() throws -> [URL] {
        var urls: [URL] = []

        let sessionsRoot = root.appendingPathComponent("sessions", isDirectory: true)
        urls.append(contentsOf: try jsonlFiles(under: sessionsRoot))

        let archivedRoot = root.appendingPathComponent("archived_sessions", isDirectory: true)
        urls.append(contentsOf: try jsonlFiles(under: archivedRoot))

        tokenMaxxingDebugLog("Codex importer discovered \(urls.count) session files")
        return urls.sorted { $0.path < $1.path }
    }

    private func jsonlFiles(under directory: URL) throws -> [URL] {
        guard fileManager.fileExists(atPath: directory.path) else {
            tokenMaxxingDebugLog("Codex importer directory not found or inaccessible: \(directory.path)")
            return []
        }

        guard let enumerator = fileManager.enumerator(
            at: directory,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            tokenMaxxingDebugLog("Codex importer could not enumerate directory: \(directory.path)")
            return []
        }

        var urls: [URL] = []
        for case let url as URL in enumerator where url.pathExtension == "jsonl" {
            let values = try url.resourceValues(forKeys: [.isRegularFileKey])
            if values.isRegularFile == true {
                urls.append(url)
            }
        }
        tokenMaxxingDebugLog("Codex importer found \(urls.count) JSONL files under \(directory.path)")
        return urls
    }
}
