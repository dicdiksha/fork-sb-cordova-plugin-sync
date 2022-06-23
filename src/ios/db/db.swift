import Foundation
import SQLite3

protocol DbService {
    func seed() -> [[String: Any]]
    func insert(_ request: [String: Any]) -> UInt64?
    func delete(_ id: String) -> UInt64?
    func update(_ columnName: String, _ whereArgs: [String], _ request: [String: Any]) -> UInt64?
    func read(_ query: String) -> [[String: Any]]
}

class DbServiceImpl : DbService {

    private func executeQuery(_ statementString: String) -> Array<Dictionary<String,Any>>? {
        let db = getOperator()
        var result:Array<Dictionary<String,Any>>=[]

        if db != nil {
            var statement: OpaquePointer? = nil
            guard sqlite3_prepare_v2(db, statementString, -1, &statement, nil) == SQLITE_OK else {
                print("Error message: \(String(cString: sqlite3_errmsg(db)!)) Code:  \(sqlite3_errcode(db)) Method: db: execute")
                return nil
            }
            
            while sqlite3_step(statement) == SQLITE_ROW {
                let columnsCount:Int32 = sqlite3_column_count(statement)
                var columnIndex: Int32 = 0
                var eachRow:[String: Any] = [:]
                while columnIndex < columnsCount {
                    let columnName = String(cString: sqlite3_column_name(statement, columnIndex))
                    let columnType = sqlite3_column_type(statement, columnIndex)
                    if(columnType  == SQLITE_FLOAT){
                        eachRow[columnName] = Double(sqlite3_column_double(statement, columnIndex))
                    } else if(columnType  == SQLITE_INTEGER){
                        eachRow[columnName] = Int64(sqlite3_column_int64(statement, columnIndex))
                    } else if(columnType  == SQLITE_TEXT){
                        eachRow[columnName] = String(cString:sqlite3_column_text(statement, columnIndex) )
                    } else if(columnType  == SQLITE_NULL){
                        eachRow[columnName] = nil
                    }
                    columnIndex += 1
                }
                result.append(eachRow)
            }
            defer {
                sqlite3_finalize(statement)
            }
            return result
            
        }
        return nil
    }
    
    
    func seed() -> [[String: Any]] {
        if let result = self.executeQuery("SELECT * from network_queue order by priority") {
            return result
        }
        return []
    }
    
    func insert(_ request: [String: Any]) -> UInt64? {
        let db = getOperator()
        let table = "network_queue"
        let data = request
        var queryStringQuestionString = ""
        for _ in 1..<data.keys.count {
            queryStringQuestionString += "?,"
        }
        queryStringQuestionString += "?"
        var statement: OpaquePointer?
        let queryString = "INSERT INTO \(table) (\(data.keys.joined(separator: ","))) VALUES (\(queryStringQuestionString))"
        guard sqlite3_prepare_v2(db, queryString, -1, &statement, nil) == SQLITE_OK else {
            print("Error message: \(String(cString: sqlite3_errmsg(db)!)) Code:  \(sqlite3_errcode(db)) Method: Insert")
            return nil
        }
        var valueIndex: Int32 = 1
        let SQLITE_TRANSIENT = unsafeBitCast(OpaquePointer(bitPattern: -1), to: sqlite3_destructor_type.self)
        if data != nil {
            for (_, value) in data {
                if let value = value as? String {
                    guard sqlite3_bind_text(statement, valueIndex, value as String, -1, SQLITE_TRANSIENT) == SQLITE_OK else {
                        print("sqlite3_bind_text failed with \(value) at index \(valueIndex)")
                        print("Error message: \(String(cString: sqlite3_errmsg(db)!)) Code:  \(sqlite3_errcode(db)) Method: Insert")
                        return nil
                    }
                } else if let value = value as? Int {
                    guard sqlite3_bind_int64(statement, valueIndex, Int64(value)) == SQLITE_OK  else {
                        print("sqlite3_bind_int failed with \(value) at index \(valueIndex)")
                        print("Error message: \(String(cString: sqlite3_errmsg(db)!)) Code:  \(sqlite3_errcode(db)) Method: Insert")
                        return nil
                    }
                }  else if let value = value as? Int32 {
                    guard sqlite3_bind_int(statement, valueIndex, value as Int32) == SQLITE_OK else {
                        print("sqlite3_bind_int failed with \(value) at index \(valueIndex)")
                        print("Error message: \(String(cString: sqlite3_errmsg(db)!)) Code:  \(sqlite3_errcode(db)) Method: Insert")
                        return nil
                    }
                } else if let value = value as? Double {
                    guard sqlite3_bind_double(statement, valueIndex, value as Double) == SQLITE_OK else {
                        print("sqlite3_bind_double failed with \(value) at index \(valueIndex)")
                        print("Error message: \(String(cString: sqlite3_errmsg(db)!)) Code:  \(sqlite3_errcode(db)) Method: Insert")
                        return nil
                    }
                }
                valueIndex += 1
            }
        }

        for i in 1...3 {
            // print(i)
            // print("i Value")
            guard sqlite3_step(statement) == SQLITE_DONE else {
                print("Error message: \(String(cString: sqlite3_errmsg(db)!)) Code:  \(sqlite3_errcode(db)) Method: Insert")
                if (i == 3) {
                    return nil
                }
                continue
            }
        }
        
        let rowId = sqlite3_last_insert_rowid(db)
        defer {
            sqlite3_finalize(statement)
        }
        
        return UInt64(rowId)
    }
    
    func delete(_ id: String) -> UInt64? {
        self.executeQuery("DELETE from network_queue where msg_id='" + id + "'")
        return 0
    }
    
    func update(_ columnName: String, _ whereArgs: [String], _ request: [String: Any]) -> UInt64? {
        let table = "network_queue"
        let db = self.getOperator()
        let whereClause = columnName + " = ?"
        let updateValues: [String: Any] = request
        let whereArgs =  whereArgs
        let statementString = "UPDATE \(table) SET " + updateValues.keys.joined(separator: " = ?, ") + " = ? WHERE \(whereClause)"
        var statement: OpaquePointer? = nil
        guard sqlite3_prepare_v2(db, statementString, -1, &statement, nil) == SQLITE_OK else {
            print("Error message: \(String(cString: sqlite3_errmsg(db)!)) Code:  \(sqlite3_errcode(db)) Method: Update")
            return nil
        }
        var valueIndex: Int32 = 1
        let SQLITE_TRANSIENT = unsafeBitCast(OpaquePointer(bitPattern: -1), to: sqlite3_destructor_type.self)
        for (_, value) in updateValues {
            if let value = value as? String {
                guard sqlite3_bind_text(statement, valueIndex, value as! String, -1, SQLITE_TRANSIENT) == SQLITE_OK else {
                    print("sqlite3_bind_text failed with \(value) at index \(valueIndex)")
                    print("Error message: \(String(cString: sqlite3_errmsg(db)!)) Code:  \(sqlite3_errcode(db)) Method: Update")
                    return nil
                }
            } else if let value = value as? Int {
                guard sqlite3_bind_int64(statement, valueIndex, Int64(value)) == SQLITE_OK  else {
                    print("sqlite3_bind_int failed with \(value) at index \(valueIndex)")
                    print("Error message: \(String(cString: sqlite3_errmsg(db)!)) Code:  \(sqlite3_errcode(db)) Method: Update")
                    return nil
                }
            }  else if(value is Int32) {
                guard sqlite3_bind_int(statement, valueIndex, value as! Int32) == SQLITE_OK else {
                    print("sqlite3_bind_int failed with \(value) at index \(valueIndex)")
                    print("Error message: \(String(cString: sqlite3_errmsg(db)!)) Code:  \(sqlite3_errcode(db)) Method: Update")
                    return nil
                }
            } else if(value is Double) {
                guard sqlite3_bind_double(statement, valueIndex, value as! Double) == SQLITE_OK else {
                    print("sqlite3_bind_double failed with \(value) at index \(valueIndex)")
                    print("Error message: \(String(cString: sqlite3_errmsg(db)!)) Code:  \(sqlite3_errcode(db)) Method: Update")
                    return nil
                }
            }
            valueIndex += 1
        }
        for (_, value) in whereArgs.enumerated() {
           guard sqlite3_bind_text(statement, valueIndex, value, -1, SQLITE_TRANSIENT) == SQLITE_OK else {
               print("Unable to bind the data \(value)")
            print("Error message: \(String(cString: sqlite3_errmsg(db)!)) Code:  \(sqlite3_errcode(db)) Method: Update")
               return nil
           }
           valueIndex += 1
        }
        for i in 1...3 {
            // print(i)
            // print("i Value")
            guard sqlite3_step(statement) == SQLITE_DONE else {
                print("Error message: \(String(cString: sqlite3_errmsg(db)!)) Code:  \(sqlite3_errcode(db)) Method: Insert")
                if (i == 3) {
                    return nil
                }
                continue
            }
        }        
        let updatedCount  = sqlite3_changes(db)
        print("Updated count: ", updatedCount)
        sqlite3_finalize(statement)
        return 0
    }

    func read(_ query: String) -> [[String: Any]] {
        var result: [[String: Any]] = []
        if let response = self.executeQuery(query) {
            result = response
        }
        return result
    }
    
    private func getOperator() -> OpaquePointer? {
        let instance = DBContext.getOperator()
        return instance
    }
    
}

