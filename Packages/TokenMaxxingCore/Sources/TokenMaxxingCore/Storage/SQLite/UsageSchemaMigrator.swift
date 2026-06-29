import Foundation

enum UsageSchemaMigrator {
    static let currentVersion = 1

    static func migrate(connection: SQLiteConnection) throws {
        try connection.execute("PRAGMA foreign_keys = ON")

        let version = try userVersion(connection: connection)
        guard version < currentVersion else {
            return
        }

        if version == 0 {
            try createV1Schema(connection: connection)
            try connection.execute("PRAGMA user_version = \(currentVersion)")
        }
    }

    private static func userVersion(connection: SQLiteConnection) throws -> Int {
        let statement = try connection.prepare("PRAGMA user_version")
        guard try statement.step() else {
            return 0
        }
        return statement.columnInt(0)
    }

    private static func createV1Schema(connection: SQLiteConnection) throws {
        try connection.transaction {
            try connection.execute(
                """
                CREATE TABLE IF NOT EXISTS source_files (
                    importer_kind TEXT NOT NULL,
                    path TEXT NOT NULL,
                    session_id TEXT NOT NULL,
                    modified_at REAL NOT NULL,
                    byte_count INTEGER NOT NULL,
                    imported_at REAL NOT NULL,
                    missing_at REAL,
                    PRIMARY KEY (importer_kind, path)
                )
                """
            )

            try connection.execute(
                """
                CREATE TABLE IF NOT EXISTS sessions (
                    importer_kind TEXT NOT NULL,
                    id TEXT NOT NULL,
                    source_path TEXT NOT NULL,
                    started_at REAL NOT NULL,
                    ended_at REAL,
                    total_input_tokens INTEGER,
                    total_cached_input_tokens INTEGER,
                    total_output_tokens INTEGER,
                    total_reasoning_output_tokens INTEGER,
                    total_tokens INTEGER,
                    PRIMARY KEY (importer_kind, id)
                )
                """
            )

            try connection.execute(
                """
                CREATE TABLE IF NOT EXISTS turns (
                    importer_kind TEXT NOT NULL,
                    id TEXT NOT NULL,
                    session_id TEXT NOT NULL,
                    ordinal INTEGER NOT NULL,
                    started_at REAL NOT NULL,
                    completed_at REAL,
                    usage_input_tokens INTEGER,
                    usage_cached_input_tokens INTEGER,
                    usage_output_tokens INTEGER,
                    usage_reasoning_output_tokens INTEGER,
                    usage_total_tokens INTEGER,
                    PRIMARY KEY (importer_kind, id),
                    FOREIGN KEY (importer_kind, session_id)
                        REFERENCES sessions(importer_kind, id)
                        ON DELETE CASCADE
                )
                """
            )

            try connection.execute(
                """
                CREATE TABLE IF NOT EXISTS messages (
                    importer_kind TEXT NOT NULL,
                    id TEXT NOT NULL,
                    turn_id TEXT NOT NULL,
                    ordinal INTEGER NOT NULL,
                    role TEXT NOT NULL,
                    timestamp REAL NOT NULL,
                    preview TEXT,
                    raw_type TEXT,
                    source_line INTEGER,
                    usage_snapshot_input_tokens INTEGER,
                    usage_snapshot_cached_input_tokens INTEGER,
                    usage_snapshot_output_tokens INTEGER,
                    usage_snapshot_reasoning_output_tokens INTEGER,
                    usage_snapshot_total_tokens INTEGER,
                    PRIMARY KEY (importer_kind, id),
                    FOREIGN KEY (importer_kind, turn_id)
                        REFERENCES turns(importer_kind, id)
                        ON DELETE CASCADE
                )
                """
            )

            try connection.execute(
                "CREATE INDEX IF NOT EXISTS sessions_started_at_idx ON sessions(started_at)"
            )
            try connection.execute(
                "CREATE INDEX IF NOT EXISTS turns_session_idx ON turns(importer_kind, session_id, ordinal)"
            )
            try connection.execute(
                "CREATE INDEX IF NOT EXISTS messages_turn_idx ON messages(importer_kind, turn_id, ordinal)"
            )
        }
    }
}
