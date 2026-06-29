import Foundation
import SQLite3

private let sqliteTransient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

final class SQLiteStatement {
    private let statement: OpaquePointer
    private unowned let connection: SQLiteConnection

    init(statement: OpaquePointer, connection: SQLiteConnection) {
        self.statement = statement
        self.connection = connection
    }

    deinit {
        sqlite3_finalize(statement)
    }

    func bind(_ value: String, at index: Int32) throws {
        let result = sqlite3_bind_text(statement, index, value, -1, sqliteTransient)
        try check(result)
    }

    func bind(_ value: Int, at index: Int32) throws {
        try check(sqlite3_bind_int64(statement, index, sqlite3_int64(value)))
    }

    func bind(_ value: Int64, at index: Int32) throws {
        try check(sqlite3_bind_int64(statement, index, sqlite3_int64(value)))
    }

    func bind(_ value: Double, at index: Int32) throws {
        try check(sqlite3_bind_double(statement, index, value))
    }

    func bind(_ value: Date, at index: Int32) throws {
        try bind(value.timeIntervalSince1970, at: index)
    }

    func bindNull(at index: Int32) throws {
        try check(sqlite3_bind_null(statement, index))
    }

    func bind(_ value: String?, at index: Int32) throws {
        if let value {
            try bind(value, at: index)
        } else {
            try bindNull(at: index)
        }
    }

    func bind(_ value: Int?, at index: Int32) throws {
        if let value {
            try bind(value, at: index)
        } else {
            try bindNull(at: index)
        }
    }

    func bind(_ value: Date?, at index: Int32) throws {
        if let value {
            try bind(value, at: index)
        } else {
            try bindNull(at: index)
        }
    }

    @discardableResult
    func step() throws -> Bool {
        let result = sqlite3_step(statement)
        switch result {
        case SQLITE_ROW:
            return true
        case SQLITE_DONE:
            return false
        default:
            throw SQLiteError(message: connection.lastErrorMessage)
        }
    }

    func reset() throws {
        try check(sqlite3_reset(statement))
        try check(sqlite3_clear_bindings(statement))
    }

    func columnString(_ index: Int32) -> String? {
        guard sqlite3_column_type(statement, index) != SQLITE_NULL,
            let text = sqlite3_column_text(statement, index)
        else {
            return nil
        }

        return String(cString: text)
    }

    func columnInt(_ index: Int32) -> Int {
        Int(sqlite3_column_int64(statement, index))
    }

    func columnInt64(_ index: Int32) -> Int64 {
        Int64(sqlite3_column_int64(statement, index))
    }

    func columnDouble(_ index: Int32) -> Double {
        sqlite3_column_double(statement, index)
    }

    func columnDate(_ index: Int32) -> Date {
        Date(timeIntervalSince1970: columnDouble(index))
    }

    func columnOptionalDate(_ index: Int32) -> Date? {
        guard !columnIsNull(index) else {
            return nil
        }
        return columnDate(index)
    }

    func columnIsNull(_ index: Int32) -> Bool {
        sqlite3_column_type(statement, index) == SQLITE_NULL
    }

    private func check(_ result: Int32) throws {
        guard result == SQLITE_OK else {
            throw SQLiteError(message: connection.lastErrorMessage)
        }
    }
}
