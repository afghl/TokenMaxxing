import Foundation

actor SQLiteUsageRepository: UsageRepository {
    private let databaseURL: URL
    private var sqliteConnection: SQLiteConnection?
    private var didPrepare = false

    init(databaseURL: URL) {
        self.databaseURL = databaseURL
    }

    func prepare() async throws {
        _ = try preparedConnection()
    }

    func loadSourceFiles(for importerKind: SessionImporterKind) async throws
        -> [StoredSourceLogFile]
    {
        let connection = try preparedConnection()
        let statement = try connection.prepare(
            """
            SELECT importer_kind, path, session_id, modified_at, byte_count, imported_at, missing_at
            FROM source_files
            WHERE importer_kind = ?
            ORDER BY path
            """
        )
        try statement.bind(importerKind.rawValue, at: 1)

        var files: [StoredSourceLogFile] = []
        while try statement.step() {
            guard let storedImporterKind = SessionImporterKind(rawValue: statement.columnString(0) ?? "")
            else {
                throw SQLiteUsageRepositoryError.invalidImporterKind
            }

            files.append(
                StoredSourceLogFile(
                    importerKind: storedImporterKind,
                    sessionID: statement.columnString(2) ?? "",
                    path: statement.columnString(1) ?? "",
                    modifiedAt: statement.columnDate(3),
                    byteCount: statement.columnInt64(4),
                    importedAt: statement.columnDate(5),
                    missingAt: statement.columnOptionalDate(6)
                )
            )
        }

        return files
    }

    func replaceImportedSession(
        _ session: Session,
        sourceFile: SourceLogFile,
        importedAt: Date
    ) async throws {
        let connection = try preparedConnection()

        try connection.transaction {
            try deleteExistingTurns(
                connection: connection,
                importerKind: sourceFile.importerKind,
                sessionID: session.id
            )
            try upsertSession(
                connection: connection,
                session: session,
                importerKind: sourceFile.importerKind,
                sourcePath: sourceFile.url.path
            )

            for (turnOffset, turn) in session.turns.enumerated() {
                try insertTurn(
                    connection: connection,
                    turn: turn,
                    sessionID: session.id,
                    importerKind: sourceFile.importerKind,
                    ordinal: turnOffset
                )

                for (messageOffset, message) in turn.messages.enumerated() {
                    try insertMessage(
                        connection: connection,
                        message: message,
                        turnID: turn.id,
                        importerKind: sourceFile.importerKind,
                        ordinal: messageOffset
                    )
                }
            }

            try upsertSourceFile(
                connection: connection,
                sourceFile: sourceFile,
                importedAt: importedAt
            )
        }
    }

    func markSourceFileMissing(
        _ sourceFile: StoredSourceLogFile,
        missingAt: Date
    ) async throws {
        let connection = try preparedConnection()
        let statement = try connection.prepare(
            """
            UPDATE source_files
            SET missing_at = ?
            WHERE importer_kind = ? AND path = ?
            """
        )
        try statement.bind(missingAt, at: 1)
        try statement.bind(sourceFile.importerKind.rawValue, at: 2)
        try statement.bind(sourceFile.path, at: 3)
        try statement.step()
    }

    func loadSessions(matching query: SessionQuery = .all) async throws -> [Session] {
        let connection = try preparedConnection()
        var sql =
            """
            SELECT importer_kind, id, source_path, started_at, ended_at,
                   total_input_tokens, total_cached_input_tokens, total_output_tokens,
                   total_reasoning_output_tokens, total_tokens
            FROM sessions
            """
        var conditions: [String] = []
        var importerKinds: [SessionImporterKind] = []

        if let queryImporterKinds = query.importerKinds, !queryImporterKinds.isEmpty {
            importerKinds = queryImporterKinds.sorted { $0.rawValue < $1.rawValue }
            conditions.append(
                "importer_kind IN (\(Array(repeating: "?", count: importerKinds.count).joined(separator: ", ")))"
            )
        }
        if query.startedAtOrAfter != nil {
            conditions.append("started_at >= ?")
        }
        if query.startedBefore != nil {
            conditions.append("started_at < ?")
        }

        if !conditions.isEmpty {
            sql += " WHERE " + conditions.joined(separator: " AND ")
        }
        sql += " ORDER BY started_at DESC"

        let statement = try connection.prepare(sql)
        var bindIndex: Int32 = 1
        for importerKind in importerKinds {
            try statement.bind(importerKind.rawValue, at: bindIndex)
            bindIndex += 1
        }
        if let startedAtOrAfter = query.startedAtOrAfter {
            try statement.bind(startedAtOrAfter, at: bindIndex)
            bindIndex += 1
        }
        if let startedBefore = query.startedBefore {
            try statement.bind(startedBefore, at: bindIndex)
        }

        var sessions: [Session] = []
        while try statement.step() {
            guard let importerKind = SessionImporterKind(rawValue: statement.columnString(0) ?? "")
            else {
                throw SQLiteUsageRepositoryError.invalidImporterKind
            }

            let sessionID = statement.columnString(1) ?? ""
            let sourcePath = statement.columnString(2) ?? ""
            let turns = try loadTurns(
                connection: connection,
                importerKind: importerKind,
                sessionID: sessionID
            )

            sessions.append(
                Session(
                    id: sessionID,
                    source: sessionSource(importerKind: importerKind, path: sourcePath),
                    startedAt: statement.columnDate(3),
                    endedAt: statement.columnOptionalDate(4),
                    turns: turns,
                    totalUsage: tokenUsage(from: statement, startingAt: 5)
                )
            )
        }

        return sessions
    }

    private func preparedConnection() throws -> SQLiteConnection {
        let connection = try openConnection()
        guard !didPrepare else {
            return connection
        }

        try UsageSchemaMigrator.migrate(connection: connection)
        didPrepare = true
        return connection
    }

    private func openConnection() throws -> SQLiteConnection {
        if let sqliteConnection {
            return sqliteConnection
        }

        try FileManager.default.createDirectory(
            at: databaseURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        let connection = try SQLiteConnection(url: databaseURL)
        self.sqliteConnection = connection
        return connection
    }

    private func deleteExistingTurns(
        connection: SQLiteConnection,
        importerKind: SessionImporterKind,
        sessionID: Session.ID
    ) throws {
        let deleteMessages = try connection.prepare(
            """
            DELETE FROM messages
            WHERE importer_kind = ?
              AND turn_id IN (
                  SELECT id FROM turns WHERE importer_kind = ? AND session_id = ?
              )
            """
        )
        try deleteMessages.bind(importerKind.rawValue, at: 1)
        try deleteMessages.bind(importerKind.rawValue, at: 2)
        try deleteMessages.bind(sessionID, at: 3)
        try deleteMessages.step()

        let deleteTurns = try connection.prepare(
            "DELETE FROM turns WHERE importer_kind = ? AND session_id = ?"
        )
        try deleteTurns.bind(importerKind.rawValue, at: 1)
        try deleteTurns.bind(sessionID, at: 2)
        try deleteTurns.step()
    }

    private func upsertSession(
        connection: SQLiteConnection,
        session: Session,
        importerKind: SessionImporterKind,
        sourcePath: String
    ) throws {
        let statement = try connection.prepare(
            """
            INSERT OR REPLACE INTO sessions (
                importer_kind, id, source_path, started_at, ended_at,
                total_input_tokens, total_cached_input_tokens, total_output_tokens,
                total_reasoning_output_tokens, total_tokens
            )
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """
        )
        try statement.bind(importerKind.rawValue, at: 1)
        try statement.bind(session.id, at: 2)
        try statement.bind(sourcePath, at: 3)
        try statement.bind(session.startedAt, at: 4)
        try statement.bind(session.endedAt, at: 5)
        try bind(session.totalUsage, to: statement, startingAt: 6)
        try statement.step()
    }

    private func insertTurn(
        connection: SQLiteConnection,
        turn: Turn,
        sessionID: Session.ID,
        importerKind: SessionImporterKind,
        ordinal: Int
    ) throws {
        let statement = try connection.prepare(
            """
            INSERT INTO turns (
                importer_kind, id, session_id, ordinal, started_at, completed_at,
                usage_input_tokens, usage_cached_input_tokens, usage_output_tokens,
                usage_reasoning_output_tokens, usage_total_tokens
            )
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """
        )
        try statement.bind(importerKind.rawValue, at: 1)
        try statement.bind(turn.id, at: 2)
        try statement.bind(sessionID, at: 3)
        try statement.bind(ordinal, at: 4)
        try statement.bind(turn.startedAt, at: 5)
        try statement.bind(turn.completedAt, at: 6)
        try bind(turn.usage, to: statement, startingAt: 7)
        try statement.step()
    }

    private func insertMessage(
        connection: SQLiteConnection,
        message: Message,
        turnID: Turn.ID,
        importerKind: SessionImporterKind,
        ordinal: Int
    ) throws {
        let statement = try connection.prepare(
            """
            INSERT INTO messages (
                importer_kind, id, turn_id, ordinal, role, timestamp, preview,
                raw_type, source_line,
                usage_snapshot_input_tokens, usage_snapshot_cached_input_tokens,
                usage_snapshot_output_tokens, usage_snapshot_reasoning_output_tokens,
                usage_snapshot_total_tokens
            )
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """
        )
        try statement.bind(importerKind.rawValue, at: 1)
        try statement.bind(message.id, at: 2)
        try statement.bind(turnID, at: 3)
        try statement.bind(ordinal, at: 4)
        try statement.bind(message.role.rawValue, at: 5)
        try statement.bind(message.timestamp, at: 6)
        try statement.bind(message.preview, at: 7)
        try statement.bind(message.rawType, at: 8)
        try statement.bind(message.sourceLine, at: 9)
        try bind(message.usageSnapshot, to: statement, startingAt: 10)
        try statement.step()
    }

    private func upsertSourceFile(
        connection: SQLiteConnection,
        sourceFile: SourceLogFile,
        importedAt: Date
    ) throws {
        let statement = try connection.prepare(
            """
            INSERT OR REPLACE INTO source_files (
                importer_kind, path, session_id, modified_at, byte_count, imported_at, missing_at
            )
            VALUES (?, ?, ?, ?, ?, ?, NULL)
            """
        )
        try statement.bind(sourceFile.importerKind.rawValue, at: 1)
        try statement.bind(sourceFile.url.path, at: 2)
        try statement.bind(sourceFile.sessionID, at: 3)
        try statement.bind(sourceFile.modifiedAt, at: 4)
        try statement.bind(sourceFile.byteCount, at: 5)
        try statement.bind(importedAt, at: 6)
        try statement.step()
    }

    private func loadTurns(
        connection: SQLiteConnection,
        importerKind: SessionImporterKind,
        sessionID: Session.ID
    ) throws -> [Turn] {
        let statement = try connection.prepare(
            """
            SELECT id, started_at, completed_at,
                   usage_input_tokens, usage_cached_input_tokens, usage_output_tokens,
                   usage_reasoning_output_tokens, usage_total_tokens
            FROM turns
            WHERE importer_kind = ? AND session_id = ?
            ORDER BY ordinal
            """
        )
        try statement.bind(importerKind.rawValue, at: 1)
        try statement.bind(sessionID, at: 2)

        var turns: [Turn] = []
        while try statement.step() {
            let turnID = statement.columnString(0) ?? ""
            let messages = try loadMessages(
                connection: connection,
                importerKind: importerKind,
                turnID: turnID
            )
            turns.append(
                Turn(
                    id: turnID,
                    startedAt: statement.columnDate(1),
                    completedAt: statement.columnOptionalDate(2),
                    messages: messages,
                    usage: tokenUsage(from: statement, startingAt: 3)
                )
            )
        }

        return turns
    }

    private func loadMessages(
        connection: SQLiteConnection,
        importerKind: SessionImporterKind,
        turnID: Turn.ID
    ) throws -> [Message] {
        let statement = try connection.prepare(
            """
            SELECT id, role, timestamp, preview, raw_type, source_line,
                   usage_snapshot_input_tokens, usage_snapshot_cached_input_tokens,
                   usage_snapshot_output_tokens, usage_snapshot_reasoning_output_tokens,
                   usage_snapshot_total_tokens
            FROM messages
            WHERE importer_kind = ? AND turn_id = ?
            ORDER BY ordinal
            """
        )
        try statement.bind(importerKind.rawValue, at: 1)
        try statement.bind(turnID, at: 2)

        var messages: [Message] = []
        while try statement.step() {
            guard let role = MessageRole(rawValue: statement.columnString(1) ?? "") else {
                throw SQLiteUsageRepositoryError.invalidMessageRole
            }

            let sourceLine: Int?
            if statement.columnIsNull(5) {
                sourceLine = nil
            } else {
                sourceLine = statement.columnInt(5)
            }

            messages.append(
                Message(
                    id: statement.columnString(0) ?? "",
                    role: role,
                    timestamp: statement.columnDate(2),
                    preview: statement.columnString(3),
                    usageSnapshot: tokenUsage(from: statement, startingAt: 6),
                    rawType: statement.columnString(4),
                    sourceLine: sourceLine
                )
            )
        }

        return messages
    }

    private func bind(
        _ usage: TokenUsage?,
        to statement: SQLiteStatement,
        startingAt index: Int32
    ) throws {
        guard let usage else {
            try statement.bindNull(at: index)
            try statement.bindNull(at: index + 1)
            try statement.bindNull(at: index + 2)
            try statement.bindNull(at: index + 3)
            try statement.bindNull(at: index + 4)
            return
        }

        try statement.bind(usage.inputTokens, at: index)
        try statement.bind(usage.cachedInputTokens, at: index + 1)
        try statement.bind(usage.outputTokens, at: index + 2)
        try statement.bind(usage.reasoningOutputTokens, at: index + 3)
        try statement.bind(usage.totalTokens, at: index + 4)
    }

    private func tokenUsage(from statement: SQLiteStatement, startingAt index: Int32)
        -> TokenUsage?
    {
        guard !statement.columnIsNull(index + 4) else {
            return nil
        }

        return TokenUsage(
            inputTokens: statement.columnInt(index),
            cachedInputTokens: statement.columnInt(index + 1),
            outputTokens: statement.columnInt(index + 2),
            reasoningOutputTokens: statement.columnInt(index + 3),
            totalTokens: statement.columnInt(index + 4)
        )
    }

    private func sessionSource(importerKind: SessionImporterKind, path: String) -> SessionSource {
        switch importerKind {
        case .codex:
            return .codex(path: path)
        case .claudeCode:
            return .claudeCode(path: path)
        case .openCode:
            return .openCode(path: path)
        }
    }
}

private enum SQLiteUsageRepositoryError: Error {
    case invalidImporterKind
    case invalidMessageRole
}
