import Foundation

// MARK: - Food

struct Food: Identifiable, Hashable, Sendable {
    var id: Int64 = 0
    var name: String = ""
    var category: String = ""
    var brand: String = ""
    var source: String = ""
    var packaging: String = ""
    var rating: Int = 50
    var buyAgain: Bool = true
    var purchaseDate: String = ""
    var price: Double? = nil
    var note: String = ""
    var createdAt: String = ""
    var updatedAt: String = ""
}

// MARK: - View / Filter

struct FilterCondition: Codable, Hashable, Equatable, Sendable {
    var field: String = "rating"
    var op: String = "gt"
    var value: String = ""
}

struct FoodView: Identifiable, Hashable, Sendable {
    var id: Int64 = 0
    var name: String = ""
    var filters: [FilterCondition] = []
    var columns: [String] = ColumnMeta.defaultKeys
    var createdAt: String = ""
}

// MARK: - Column metadata

struct ColumnMeta: Hashable, Sendable {
    let key: String
    let label: String

    static let all: [ColumnMeta] = [
        .init(key: "name",          label: "名称"),
        .init(key: "category",      label: "分类"),
        .init(key: "brand",         label: "品牌"),
        .init(key: "source",        label: "来源"),
        .init(key: "packaging",     label: "包装"),
        .init(key: "rating",        label: "评分"),
        .init(key: "buy_again",     label: "回购"),
        .init(key: "price",         label: "价格"),
        .init(key: "purchase_date", label: "购入日期"),
        .init(key: "note",          label: "备注"),
    ]
    static let defaultKeys = ["name", "buy_again", "price", "note"]
    static func label(for key: String) -> String {
        all.first { $0.key == key }?.label ?? key
    }
}

// MARK: - Sort

struct SortState: Hashable, Sendable {
    var field: String = "updated_at"
    var ascending: Bool = false

    var sqlClause: String { "\(safeField) \(ascending ? "ASC" : "DESC")" }

    private var safeField: String {
        let allowed = ["updated_at","created_at","name","rating","price","purchase_date"]
        return allowed.contains(field) ? field : "updated_at"
    }

    static let allFields: [(key: String, label: String)] = [
        ("updated_at",    "更新时间"),
        ("name",          "名称"),
        ("rating",        "评分"),
        ("price",         "价格"),
        ("purchase_date", "购入日期"),
        ("created_at",    "添加时间"),
    ]
}

// MARK: - Spending

struct SpendPeriod: Identifiable, Sendable {
    var id: String { period }
    var period: String
    var dateFrom: String
    var dateTo: String
    var count: Int
    var total: Double
}
