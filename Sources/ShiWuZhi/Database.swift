import Foundation
import SQLite3

// MARK: - Database

@MainActor
final class Database {
    static let shared = Database()
    private var db: OpaquePointer?

    private init() {
        let path = (NSHomeDirectory() as NSString).appendingPathComponent(".shiwuzhi.db")
        guard sqlite3_open(path, &db) == SQLITE_OK else { return }
        setupSchema()
    }

    // MARK: Schema

    private func exec(_ sql: String) {
        sqlite3_exec(db, sql, nil, nil, nil)
    }

    private func setupSchema() {
        exec("""
        CREATE TABLE IF NOT EXISTS foods (
            id            INTEGER PRIMARY KEY AUTOINCREMENT,
            name          TEXT NOT NULL,
            category      TEXT DEFAULT '',
            source        TEXT DEFAULT '',
            brand         TEXT DEFAULT '',
            packaging     TEXT DEFAULT '',
            rating        INTEGER DEFAULT 50,
            buy_again     INTEGER DEFAULT 1,
            purchase_date TEXT DEFAULT '',
            price         REAL,
            calories      INTEGER,
            meal_type     TEXT DEFAULT '',
            note          TEXT DEFAULT '',
            created_at    TEXT DEFAULT (datetime('now','localtime')),
            updated_at    TEXT DEFAULT (datetime('now','localtime'))
        )
        """)
        exec("""
        CREATE TABLE IF NOT EXISTS views (
            id         INTEGER PRIMARY KEY AUTOINCREMENT,
            name       TEXT NOT NULL,
            filters    TEXT NOT NULL DEFAULT '[]',
            columns    TEXT NOT NULL DEFAULT '["name","buy_again","price","note"]',
            created_at TEXT DEFAULT (datetime('now','localtime'))
        )
        """)
        // non-destructive migrations (errors are ignored)
        exec("ALTER TABLE foods ADD COLUMN brand TEXT DEFAULT ''")
        exec("ALTER TABLE foods ADD COLUMN purchase_date TEXT DEFAULT ''")
        exec("ALTER TABLE foods ADD COLUMN price REAL")
        exec("ALTER TABLE foods ADD COLUMN calories INTEGER")
        exec("ALTER TABLE foods ADD COLUMN meal_type TEXT DEFAULT ''")
        exec("ALTER TABLE views ADD COLUMN columns TEXT NOT NULL DEFAULT '[\"name\",\"buy_again\",\"price\",\"note\"]'")
    }

    // MARK: - Helpers

    private func prepare(_ sql: String) -> OpaquePointer? {
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return nil }
        return stmt
    }

    private func string(_ stmt: OpaquePointer, _ col: Int32) -> String {
        guard let ptr = sqlite3_column_text(stmt, col) else { return "" }
        return String(cString: ptr)
    }

    private func foodFromStmt(_ stmt: OpaquePointer) -> Food {
        Food(
            id:           sqlite3_column_int64(stmt, 0),
            name:         string(stmt, 1),
            category:     string(stmt, 2),
            brand:        string(stmt, 3),
            source:       string(stmt, 4),
            packaging:    string(stmt, 5),
            rating:       Int(sqlite3_column_int(stmt, 6)),
            buyAgain:     sqlite3_column_int(stmt, 7) != 0,
            purchaseDate: string(stmt, 8),
            price:        sqlite3_column_type(stmt, 9) == SQLITE_NULL ? nil : sqlite3_column_double(stmt, 9),
            calories:     sqlite3_column_type(stmt, 13) == SQLITE_NULL ? nil : Int(sqlite3_column_int(stmt, 13)),
            mealType:     string(stmt, 14),
            note:         string(stmt, 10),
            createdAt:    string(stmt, 11),
            updatedAt:    string(stmt, 12)
        )
    }

    // MARK: - Foods

    func fetchFoods(
        query: String = "",
        category: String = "",
        sort: SortState = SortState(),
        dedup: Bool = false,
        date: String = ""
    ) -> [Food] {
        var base = """
        SELECT id,name,brand,source,packaging,
               rating,buy_again,purchase_date,price,note,created_at,updated_at,
               category
        FROM foods WHERE 1=1
        """
        // We'll reorder columns to match foodFromStmt
        base = """
        SELECT id,name,category,brand,source,packaging,
               rating,buy_again,purchase_date,price,note,created_at,updated_at,calories,meal_type
        FROM foods WHERE 1=1
        """
        var params: [String] = []

        if !query.isEmpty {
            base += " AND (name LIKE ? OR source LIKE ? OR note LIKE ?)"
            let q = "%\(query)%"
            params += [q, q, q]
        }
        if !category.isEmpty {
            base += " AND category=?"
            params.append(category)
        }
        if !date.isEmpty {
            base += " AND purchase_date=?"
            params.append(date)
        }

        let sql: String
        if dedup {
            sql = """
            SELECT * FROM (
                SELECT *, ROW_NUMBER() OVER (PARTITION BY name ORDER BY updated_at DESC, id DESC) AS _rn
                FROM (\(base))
            ) WHERE _rn = 1 ORDER BY \(sort.sqlClause)
            """
        } else {
            sql = base + " ORDER BY \(sort.sqlClause)"
        }

        guard let stmt = prepare(sql) else { return [] }
        defer { sqlite3_finalize(stmt) }

        for (i, p) in params.enumerated() {
            sqlite3_bind_text(stmt, Int32(i + 1), (p as NSString).utf8String, -1, nil)
        }

        var foods: [Food] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            foods.append(foodFromStmt(stmt))
        }
        return foods
    }

    func insertFood(_ f: Food) -> String? {
        if let clash = ratingClash(rating: f.rating, excludeId: 0, ownName: f.name) {
            return "评分 \(f.rating) 已被「\(clash)」占用"
        }
        let sql = """
        INSERT INTO foods (name,category,brand,source,packaging,rating,buy_again,purchase_date,price,note,calories,meal_type)
        VALUES (?,?,?,?,?,?,?,?,?,?,?,?)
        """
        guard let stmt = prepare(sql) else { return "数据库错误" }
        defer { sqlite3_finalize(stmt) }
        bind(stmt, f)
        return sqlite3_step(stmt) == SQLITE_DONE ? nil : "插入失败"
    }

    func updateFood(_ f: Food) -> String? {
        if let clash = ratingClash(rating: f.rating, excludeId: f.id, ownName: f.name) {
            return "评分 \(f.rating) 已被「\(clash)」占用"
        }
        let sql = """
        UPDATE foods SET name=?,category=?,brand=?,source=?,packaging=?,
            rating=?,buy_again=?,purchase_date=?,price=?,note=?,calories=?,meal_type=?,
            updated_at=datetime('now','localtime')
        WHERE id=?
        """
        guard let stmt = prepare(sql) else { return "数据库错误" }
        defer { sqlite3_finalize(stmt) }
        bind(stmt, f)
        sqlite3_bind_int64(stmt, 13, f.id)
        return sqlite3_step(stmt) == SQLITE_DONE ? nil : "更新失败"
    }

    func deleteFood(id: Int64) {
        guard let stmt = prepare("DELETE FROM foods WHERE id=?") else { return }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_int64(stmt, 1, id)
        sqlite3_step(stmt)
    }

    private func bind(_ stmt: OpaquePointer, _ f: Food) {
        sqlite3_bind_text(stmt, 1,  (f.name        as NSString).utf8String, -1, nil)
        sqlite3_bind_text(stmt, 2,  (f.category    as NSString).utf8String, -1, nil)
        sqlite3_bind_text(stmt, 3,  (f.brand       as NSString).utf8String, -1, nil)
        sqlite3_bind_text(stmt, 4,  (f.source      as NSString).utf8String, -1, nil)
        sqlite3_bind_text(stmt, 5,  (f.packaging   as NSString).utf8String, -1, nil)
        sqlite3_bind_int(stmt,  6,  Int32(f.rating))
        sqlite3_bind_int(stmt,  7,  f.buyAgain ? 1 : 0)
        sqlite3_bind_text(stmt, 8,  (f.purchaseDate as NSString).utf8String, -1, nil)
        if let price = f.price {
            sqlite3_bind_double(stmt, 9, price)
        } else {
            sqlite3_bind_null(stmt, 9)
        }
        sqlite3_bind_text(stmt, 10, (f.note as NSString).utf8String, -1, nil)
        if let cal = f.calories {
            sqlite3_bind_int(stmt, 11, Int32(cal))
        } else {
            sqlite3_bind_null(stmt, 11)
        }
        sqlite3_bind_text(stmt, 12, (f.mealType as NSString).utf8String, -1, nil)
    }

    // MARK: - Rating uniqueness

    func ratingClash(rating: Int, excludeId: Int64, ownName: String) -> String? {
        let sql = "SELECT name FROM foods WHERE rating=? AND id!=? AND name!=?"
        guard let stmt = prepare(sql) else { return nil }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_int(stmt,   1, Int32(rating))
        sqlite3_bind_int64(stmt, 2, excludeId)
        sqlite3_bind_text(stmt,  3, (ownName as NSString).utf8String, -1, nil)
        if sqlite3_step(stmt) == SQLITE_ROW { return string(stmt, 0) }
        return nil
    }

    func usedRatings() -> [Int: (id: Int64, name: String)] {
        let sql = """
        SELECT id, name, rating FROM foods
        WHERE id IN (SELECT MAX(id) FROM foods GROUP BY name)
        AND rating IS NOT NULL
        """
        guard let stmt = prepare(sql) else { return [:] }
        defer { sqlite3_finalize(stmt) }
        var result: [Int: (id: Int64, name: String)] = [:]
        while sqlite3_step(stmt) == SQLITE_ROW {
            let id     = sqlite3_column_int64(stmt, 0)
            let name   = string(stmt, 1)
            let rating = Int(sqlite3_column_int(stmt, 2))
            result[rating] = (id, name)
        }
        return result
    }

    // MARK: - Categories / Sources

    func categories() -> [String] {
        return distinctValues(column: "category")
    }

    func sources() -> [String] {
        return distinctValues(column: "source")
    }

    private func distinctValues(column: String) -> [String] {
        let safe = ["category", "source"].contains(column) ? column : "category"
        guard let stmt = prepare("SELECT DISTINCT \(safe) FROM foods WHERE \(safe)!='' ORDER BY \(safe)") else { return [] }
        defer { sqlite3_finalize(stmt) }
        var values: [String] = []
        while sqlite3_step(stmt) == SQLITE_ROW { values.append(string(stmt, 0)) }
        return values
    }

    // MARK: - Saved Views

    func fetchViews() -> [FoodView] {
        guard let stmt = prepare("SELECT id,name,filters,columns,created_at FROM views ORDER BY created_at ASC") else { return [] }
        defer { sqlite3_finalize(stmt) }
        var views: [FoodView] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            let id        = sqlite3_column_int64(stmt, 0)
            let name      = string(stmt, 1)
            let filterStr = string(stmt, 2)
            let colStr    = string(stmt, 3)
            let createdAt = string(stmt, 4)
            let filters   = (try? JSONDecoder().decode([FilterCondition].self, from: Data(filterStr.utf8))) ?? []
            let columns   = (try? JSONDecoder().decode([String].self, from: Data(colStr.utf8))) ?? ColumnMeta.defaultKeys
            views.append(FoodView(id: id, name: name, filters: filters, columns: columns, createdAt: createdAt))
        }
        return views
    }

    func insertView(_ v: FoodView) {
        let fStr = (try? String(data: JSONEncoder().encode(v.filters), encoding: .utf8)) ?? "[]"
        let cStr = (try? String(data: JSONEncoder().encode(v.columns), encoding: .utf8)) ?? "[\"name\",\"buy_again\",\"price\",\"note\"]"
        guard let stmt = prepare("INSERT INTO views (name,filters,columns) VALUES (?,?,?)") else { return }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_text(stmt, 1, (v.name as NSString).utf8String, -1, nil)
        sqlite3_bind_text(stmt, 2, (fStr   as NSString).utf8String, -1, nil)
        sqlite3_bind_text(stmt, 3, (cStr   as NSString).utf8String, -1, nil)
        sqlite3_step(stmt)
    }

    func updateView(_ v: FoodView) {
        let fStr = (try? String(data: JSONEncoder().encode(v.filters), encoding: .utf8)) ?? "[]"
        let cStr = (try? String(data: JSONEncoder().encode(v.columns), encoding: .utf8)) ?? "[\"name\",\"buy_again\",\"price\",\"note\"]"
        guard let stmt = prepare("UPDATE views SET name=?,filters=?,columns=? WHERE id=?") else { return }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_text(stmt,  1, (v.name as NSString).utf8String, -1, nil)
        sqlite3_bind_text(stmt,  2, (fStr   as NSString).utf8String, -1, nil)
        sqlite3_bind_text(stmt,  3, (cStr   as NSString).utf8String, -1, nil)
        sqlite3_bind_int64(stmt, 4, v.id)
        sqlite3_step(stmt)
    }

    func deleteView(id: Int64) {
        guard let stmt = prepare("DELETE FROM views WHERE id=?") else { return }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_int64(stmt, 1, id)
        sqlite3_step(stmt)
    }

    // MARK: - Spending

    func spendSummary(period: String) -> [SpendPeriod] {
        let fmt: String
        switch period {
        case "month": fmt = "%Y-%m"
        case "week":  fmt = "%Y-%W"
        default:      fmt = "%Y-%m-%d"
        }
        let sql = """
        SELECT strftime('\(fmt)', purchase_date) as p,
               MIN(purchase_date) as date_from,
               MAX(purchase_date) as date_to,
               COUNT(*) as cnt,
               ROUND(SUM(price), 2) as total
        FROM foods
        WHERE purchase_date != '' AND purchase_date IS NOT NULL AND price IS NOT NULL
        GROUP BY p ORDER BY p DESC
        """
        guard let stmt = prepare(sql) else { return [] }
        defer { sqlite3_finalize(stmt) }
        var result: [SpendPeriod] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            result.append(SpendPeriod(
                period:   string(stmt, 0),
                dateFrom: string(stmt, 1),
                dateTo:   string(stmt, 2),
                count:    Int(sqlite3_column_int(stmt, 3)),
                total:    sqlite3_column_double(stmt, 4)
            ))
        }
        return result
    }

    // MARK: - Meta

    func meta() -> (total: Int, buyAgain: Int, avgRating: Double) {
        let total    = (prepare("SELECT COUNT(*) FROM foods").map { s in defer { sqlite3_finalize(s) }; sqlite3_step(s); return Int(sqlite3_column_int(s, 0)) }) ?? 0
        let buyAgain = (prepare("SELECT COUNT(*) FROM foods WHERE buy_again=1").map { s in defer { sqlite3_finalize(s) }; sqlite3_step(s); return Int(sqlite3_column_int(s, 0)) }) ?? 0
        let avgRating = (prepare("SELECT ROUND(AVG(rating),1) FROM foods").map { s in defer { sqlite3_finalize(s) }; sqlite3_step(s); return sqlite3_column_double(s, 0) }) ?? 0
        return (total, buyAgain, avgRating)
    }
}

// MARK: - fetchViewResults binding fix

extension Database {
    // Re-implemented with correct binding logic (field-aware)
    func fetchViewResultsSafe(view: FoodView, sort: SortState, dedup: Bool) -> [Food] {
        var base = """
        SELECT id,name,category,brand,source,packaging,
               rating,buy_again,purchase_date,price,note,created_at,updated_at,calories,meal_type
        FROM foods WHERE 1=1
        """
        typealias Binding = (index: Int32, isNumeric: Bool, value: String)
        var bindings: [Binding] = []
        var bindIndex: Int32 = 1

        for f in view.filters {
            let isNumeric = (f.field == "rating" || f.field == "price")
            switch f.field {
            case "rating", "price", "calories":
                switch f.op {
                case "lt":  base += " AND \(f.field)<?";  bindings.append((bindIndex, true, f.value));  bindIndex += 1
                case "lte": base += " AND \(f.field)<=?"; bindings.append((bindIndex, true, f.value));  bindIndex += 1
                case "gt":  base += " AND \(f.field)>?";  bindings.append((bindIndex, true, f.value));  bindIndex += 1
                case "gte": base += " AND \(f.field)>=?"; bindings.append((bindIndex, true, f.value));  bindIndex += 1
                case "eq":  base += " AND \(f.field)=?";  bindings.append((bindIndex, isNumeric, f.value)); bindIndex += 1
                default: break
                }
            case "packaging", "category":
                if f.op == "eq" { base += " AND \(f.field)=?"; bindings.append((bindIndex, false, f.value)); bindIndex += 1 }
            case "buy_again":
                if f.op == "eq" { base += " AND buy_again=?"; bindings.append((bindIndex, true, f.value)); bindIndex += 1 }
            default: break
            }
        }

        let sql = dedup ? """
            SELECT * FROM (
                SELECT *, ROW_NUMBER() OVER (PARTITION BY name ORDER BY updated_at DESC, id DESC) AS _rn
                FROM (\(base))
            ) WHERE _rn = 1 ORDER BY \(sort.sqlClause)
            """ : base + " ORDER BY \(sort.sqlClause)"

        guard let stmt = prepare(sql) else { return [] }
        defer { sqlite3_finalize(stmt) }

        for b in bindings {
            if b.isNumeric, let d = Double(b.value) {
                sqlite3_bind_double(stmt, b.index, d)
            } else {
                sqlite3_bind_text(stmt, b.index, (b.value as NSString).utf8String, -1, nil)
            }
        }

        var foods: [Food] = []
        while sqlite3_step(stmt) == SQLITE_ROW { foods.append(foodFromStmt(stmt)) }
        return foods
    }
}
