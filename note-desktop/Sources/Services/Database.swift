import Foundation
import SQLite3

public final class Database {
    private var dbPointer: OpaquePointer?
    
    public init(dbName: String = "note_app_db.sqlite") {
        openDatabase(name: dbName)
        createTables()
    }
    
    deinit {
        if dbPointer != nil {
            sqlite3_close(dbPointer)
        }
    }
    
    private func openDatabase(name: String) {
        if name == ":memory:" {
            if sqlite3_open(":memory:", &dbPointer) != SQLITE_OK {
                fatalError("Unable to open in-memory database")
            }
            return
        }
        
        let fileManager = FileManager.default
        guard let appSupportURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            fatalError("Unable to access Application Support directory")
        }
        
        let appDirectory = appSupportURL.appendingPathComponent("Note")
        
        // Ensure Application Support subfolder exists
        if !fileManager.fileExists(atPath: appDirectory.path) {
            try? fileManager.createDirectory(at: appDirectory, withIntermediateDirectories: true, attributes: nil)
        }
        
        let dbURL = appDirectory.appendingPathComponent(name)
        
        if sqlite3_open(dbURL.path, &dbPointer) != SQLITE_OK {
            fatalError("Unable to open database at \(dbURL.path)")
        }
    }
    
    private func createTables() {
        for sql in Schema.allCreations {
            _ = execute(sql: sql)
        }
    }
    
    /// Executes write statements (INSERT, UPDATE, DELETE).
    public func execute(sql: String, params: [Any] = []) -> Bool {
        var statementPointer: OpaquePointer?
        
        if sqlite3_prepare_v2(dbPointer, sql, -1, &statementPointer, nil) != SQLITE_OK {
            let error = String(cString: sqlite3_errmsg(dbPointer))
            print("SQLite prepare error: \(error)")
            return false
        }
        
        bind(params: params, to: statementPointer)
        
        let result = sqlite3_step(statementPointer)
        sqlite3_finalize(statementPointer)
        
        if result != SQLITE_DONE && result != SQLITE_ROW {
            let error = String(cString: sqlite3_errmsg(dbPointer))
            print("SQLite execute error: \(error)")
            return false
        }
        
        return true
    }
    
    /// Executes read queries (SELECT) and returns a mapped array of dictionaries.
    public func query(sql: String, params: [Any] = []) -> [[String: Any]] {
        var statementPointer: OpaquePointer?
        var rows: [[String: Any]] = []
        
        if sqlite3_prepare_v2(dbPointer, sql, -1, &statementPointer, nil) != SQLITE_OK {
            let error = String(cString: sqlite3_errmsg(dbPointer))
            print("SQLite prepare query error: \(error)")
            return []
        }
        
        bind(params: params, to: statementPointer)
        
        while sqlite3_step(statementPointer) == SQLITE_ROW {
            var row: [String: Any] = [:]
            let columnCount = sqlite3_column_count(statementPointer)
            
            for i in 0..<columnCount {
                let name = String(cString: sqlite3_column_name(statementPointer, i))
                let type = sqlite3_column_type(statementPointer, i)
                
                switch type {
                case SQLITE_INTEGER:
                    row[name] = Int(sqlite3_column_int64(statementPointer, i))
                case SQLITE_FLOAT:
                    row[name] = Double(sqlite3_column_double(statementPointer, i))
                case SQLITE_TEXT:
                    if let cString = sqlite3_column_text(statementPointer, i) {
                        row[name] = String(cString: cString)
                    }
                case SQLITE_NULL:
                    row[name] = NSNull()
                default:
                    if let cString = sqlite3_column_text(statementPointer, i) {
                        row[name] = String(cString: cString)
                    }
                }
            }
            rows.append(row)
        }
        
        sqlite3_finalize(statementPointer)
        return rows
    }
    
    private func bind(params: [Any], to statement: OpaquePointer?) {
        let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        for (index, param) in params.enumerated() {
            let bindIndex = Int32(index + 1)
            
            if let string = param as? String {
                sqlite3_bind_text(statement, bindIndex, string, -1, SQLITE_TRANSIENT)
            } else if let int = param as? Int {
                sqlite3_bind_int64(statement, bindIndex, Int64(int))
            } else if let double = param as? Double {
                sqlite3_bind_double(statement, bindIndex, double)
            } else if let bool = param as? Bool {
                sqlite3_bind_int(statement, bindIndex, bool ? 1 : 0)
            } else if param is NSNull {
                sqlite3_bind_null(statement, bindIndex)
            } else {
                sqlite3_bind_text(statement, bindIndex, "\(param)", -1, SQLITE_TRANSIENT)
            }
        }
    }
}
