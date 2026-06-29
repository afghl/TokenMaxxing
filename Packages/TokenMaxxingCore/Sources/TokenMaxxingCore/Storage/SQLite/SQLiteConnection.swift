import Foundation
import SQLite3

struct SQLiteError: Error, LocalizedError {
    let message: String

    var errorDescription: String? { message }
}

final class SQLiteConnection {
    private var database: OpaquePointer?

    init(url: URL) throws {
        let flags = SQLITE_OPEN_CREATE | SQLITE_OPEN_READWRITE | SQLITE_OPEN_FULLMUTEX
        let result = sqlite3_open_v2(url.path, &database, flags, nil)
        guard result == SQLITE_OK else {
            let message = database.map { String(cString: sqlite3_errmsg($0)) }
                ?? "Unable to open SQLite database"
            sqlite3_close(database)
            throw SQLiteError(message: message)
        }

        sqlite3_busy_timeout(database, 5_000)
    }

    deinit {
        sqlite3_close(database)
    }

    func execute(_ sql: String) throws {
        var errorMessage: UnsafeMutablePointer<CChar>?
        let result = sqlite3_exec(database, sql, nil, nil, &errorMessage)
        guard result == SQLITE_OK else {
            let message = errorMessage.map { String(cString: $0) }
                ?? lastErrorMessage
            sqlite3_free(errorMessage)
            throw SQLiteError(message: message)
        }
    }

    func prepare(_ sql: String) throws -> SQLiteStatement {
        var statement: OpaquePointer?
        let result = sqlite3_prepare_v2(database, sql, -1, &statement, nil)
        guard result == SQLITE_OK, let statement else {
            throw SQLiteError(message: lastErrorMessage)
        }

        return SQLiteStatement(statement: statement, connection: self)
    }

    func transaction(_ block: () throws -> Void) throws {
        try execute("BEGIN IMMEDIATE TRANSACTION")
        do {
            try block()
            try execute("COMMIT")
        } catch {
            try? execute("ROLLBACK")
            throw error
        }
    }

    var lastErrorMessage: String {
        guard let database else {
            return "SQLite database is closed"
        }
        return String(cString: sqlite3_errmsg(database))
    }
}
