import SwiftUI

// MARK: - Sidebar selection

enum SidebarItem: Hashable {
    case allFoods
    case spending
    case settings
    case savedView(Int64)
}

// MARK: - AppState

@MainActor
@Observable
final class AppState {
    // Navigation
    var selection: SidebarItem? = .allFoods

    // Foods
    var foods: [Food] = []
    var searchQuery: String = ""
    var selectedCategory: String = ""
    var mainSort: SortState = SortState()
    var dedup: Bool = false {
        didSet { UserDefaults.standard.set(dedup, forKey: "swz_dedup"); reload() }
    }

    // Saved views
    var savedViews: [FoodView] = []
    var viewSorts: [Int64: SortState] = [:]

    // Meta
    var metaTotal: Int = 0
    var metaBuyAgain: Int = 0
    var metaAvgRating: Double = 0

    // Categories & sources
    var allCategories: [String] = []
    var allSources: [String] = []

    // Rating map (deduplicated)
    var usedRatings: [Int: (id: Int64, name: String)] = [:]

    init() {
        dedup = UserDefaults.standard.bool(forKey: "swz_dedup")
        reload()
    }

    func reload() {
        loadFoods()
        loadMeta()
        loadCategories()
        loadViews()
    }

    func loadFoods() {
        foods = Database.shared.fetchFoods(
            query: searchQuery,
            category: selectedCategory,
            sort: mainSort,
            dedup: dedup
        )
    }

    func loadMeta() {
        let m = Database.shared.meta()
        metaTotal    = m.total
        metaBuyAgain = m.buyAgain
        metaAvgRating = m.avgRating
    }

    func loadCategories() {
        allCategories = Database.shared.categories()
        allSources    = Database.shared.sources()
    }

    func loadViews() {
        savedViews = Database.shared.fetchViews()
    }

    func loadRatings() {
        usedRatings = Database.shared.usedRatings()
    }

    // MARK: - Food mutations

    @discardableResult
    func saveFood(_ food: Food) -> String? {
        let err = food.id == 0
            ? Database.shared.insertFood(food)
            : Database.shared.updateFood(food)
        if err == nil { reload() }
        return err
    }

    func deleteFood(_ food: Food) {
        Database.shared.deleteFood(id: food.id)
        reload()
    }

    // MARK: - View mutations

    func saveView(_ view: FoodView) {
        if view.id == 0 { Database.shared.insertView(view) }
        else              { Database.shared.updateView(view) }
        loadViews()
    }

    func deleteView(_ view: FoodView) {
        Database.shared.deleteView(id: view.id)
        loadViews()
        if selection == .savedView(view.id) { selection = .allFoods }
    }

    // MARK: - View results

    func viewResults(for view: FoodView) -> [Food] {
        let sort = viewSorts[view.id] ?? SortState()
        return Database.shared.fetchViewResultsSafe(view: view, sort: sort, dedup: dedup)
    }

    func sortForView(_ vid: Int64) -> SortState {
        viewSorts[vid] ?? SortState()
    }

    func setViewSort(_ sort: SortState, for vid: Int64) {
        viewSorts[vid] = sort
    }

    // MARK: - Spending

    func spendSummary(period: String) -> [SpendPeriod] {
        Database.shared.spendSummary(period: period)
    }

    func foodsForDate(_ date: String) -> [Food] {
        Database.shared.fetchFoods(sort: SortState(field: "price", ascending: false), date: date)
    }

    // MARK: - Rating helpers

    func ratingClash(rating: Int, editingFood: Food) -> String? {
        guard let entry = usedRatings[rating] else { return nil }
        if entry.id == editingFood.id { return nil }       // same record
        if entry.name == editingFood.name { return nil }   // same food name
        return entry.name
    }

    func findFreeRating(near preferred: Int) -> Int {
        for offset in 0...99 {
            for candidate in [preferred + offset, preferred - offset] where candidate >= 1 && candidate <= 100 {
                if usedRatings[candidate] == nil { return candidate }
            }
        }
        return preferred
    }
}
