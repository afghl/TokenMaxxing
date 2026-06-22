import Foundation

struct CodexLogDecoder {
    func readEvents(at url: URL) throws -> [NumberedCodexEvent] {
        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch {
            tokenMaxxingDebugLog("Codex importer could not read \(url.path): \(error.localizedDescription)")
            throw error
        }

        let contents = String(decoding: data, as: UTF8.self)
        let decoder = JSONDecoder()

        return try contents
            .split(separator: "\n", omittingEmptySubsequences: false)
            .enumerated()
            .compactMap { offset, line in
                let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else {
                    return nil
                }

                do {
                    let event = try decoder.decode(CodexLogEntry.self, from: Data(trimmed.utf8))
                    return NumberedCodexEvent(event: event, line: offset + 1)
                } catch {
                    tokenMaxxingDebugLog(
                        "Codex importer decode failed at \(url.path):\(offset + 1): \(error.localizedDescription)"
                    )
                    throw CodexSessionImportError.decodingFailed(url, line: offset + 1)
                }
            }
    }
}
