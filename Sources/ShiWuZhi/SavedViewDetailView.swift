import SwiftUI

// MARK: - Saved View Detail

struct SavedViewDetailView: View {
    @Environment(AppState.self) private var state
    let foodView: FoodView
    @State private var showEditor = false
    @State private var editingFood: Food? = nil
    @State private var localSort: SortState = SortState()

    var body: some View {
        let foods = state.fetchViewResultsCached(view: foodView, sort: localSort)

        VStack(spacing: 0) {
            // Header
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(foodView.name).font(.title3).fontWeight(.bold)
                    if foodView.filters.isEmpty {
                        Text("无筛选条件（显示全部）").font(.caption).foregroundStyle(.secondary)
                    } else {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 6) {
                                ForEach(Array(foodView.filters.enumerated()), id: \.offset) { _, f in
                                    FilterTag(condition: f)
                                }
                            }
                        }
                    }
                }
                Spacer()
                Button("编辑视图") { showEditor = true }
                Button(role: .destructive) { state.deleteView(foodView) } label: {
                    Text("删除视图").foregroundStyle(.red)
                }
            }
            .padding(14)
            .background(.bar)

            // Sort bar
            HStack(spacing: 8) {
                Text("排序：").font(.caption).foregroundStyle(.secondary)
                SortPicker(sort: $localSort) {}
                Spacer()
                Text("\(foods.count) 条").font(.caption).foregroundStyle(.secondary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .background(.quaternary.opacity(0.3))

            Divider()

            if foods.isEmpty {
                ContentUnavailableView("没有符合条件的记录", systemImage: "magnifyingglass")
            } else {
                FoodTable(foods: foods, columns: foodView.columns) { food in
                    editingFood = food
                } onDuplicate: { food in
                    var copy = food; copy.id = 0
                    state.loadRatings()
                    copy.rating = state.findFreeRating(near: food.rating)
                    editingFood = copy
                }
            }
        }
        .navigationTitle(foodView.name)
        .sheet(isPresented: $showEditor) {
            ViewBuilderView(existing: foodView) { updated in
                state.saveView(updated)
                showEditor = false
            }
        }
        .sheet(item: $editingFood) { food in
            let deleteHandler: (() -> Void)? = food.id == 0 ? nil : {
                state.deleteFood(food)
                editingFood = nil
            }
            FoodFormView(food: food, onSave: { saved in
                state.saveFood(saved)
                editingFood = nil
            }, onDelete: deleteHandler)
            .environment(state)
        }
    }
}

// MARK: - AppState extension for view results with local sort

extension AppState {
    func fetchViewResultsCached(view: FoodView, sort: SortState) -> [Food] {
        Database.shared.fetchViewResultsSafe(view: view, sort: sort, dedup: dedup)
    }
}

// MARK: - Filter tag

struct FilterTag: View {
    let condition: FilterCondition

    private static let fieldLabels = ["rating":"评分","price":"价格","calories":"卡路里",
                                      "packaging":"包装","category":"分类","buy_again":"回购"]
    private static let opLabels    = ["lt":"<","lte":"≤","gt":">","gte":"≥","eq":"="]

    var body: some View {
        let fl = Self.fieldLabels[condition.field] ?? condition.field
        let ol = Self.opLabels[condition.op] ?? condition.op
        let vl = condition.field == "buy_again"
            ? (condition.value == "1" ? "会再购" : "不再购")
            : condition.field == "rating"   ? "\(condition.value)分"
            : condition.field == "price"    ? "¥\(condition.value)"
            : condition.field == "calories" ? "\(condition.value)kcal"
            : condition.value

        Text("\(fl) \(ol) \(vl)")
            .font(.caption)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(.quaternary)
            .clipShape(RoundedRectangle(cornerRadius: 4))
    }
}

// MARK: - View Builder

struct ViewBuilderView: View {
    @State private var name: String
    @State private var filters: [FilterCondition]
    @State private var columns: [String]
    @State private var columnsEnabled: Set<String>
    @State private var orderedColumns: [ColumnMeta]
    private let existing: FoodView?
    private let onSave: (FoodView) -> Void

    init(existing: FoodView? = nil, onSave: @escaping (FoodView) -> Void) {
        self.existing = existing
        self.onSave   = onSave
        let savedCols = existing?.columns ?? ColumnMeta.defaultKeys
        _name    = State(initialValue: existing?.name ?? "")
        _filters = State(initialValue: existing?.filters ?? [])
        _columns = State(initialValue: savedCols)
        _columnsEnabled = State(initialValue: Set(savedCols))

        // Build ordered list: selected first, then rest
        let selSet = Set(savedCols)
        let ordered = savedCols.compactMap { k in ColumnMeta.all.first { $0.key == k } }
                    + ColumnMeta.all.filter { !selSet.contains($0.key) }
        _orderedColumns = State(initialValue: ordered)
    }

    var body: some View {
        VStack(spacing: 0) {
            Text(existing == nil ? "新建自定义视图" : "编辑视图")
                .font(.headline).padding(20)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {

                    // Name
                    VStack(alignment: .leading, spacing: 4) {
                        Text("视图名称").font(.caption).foregroundStyle(.secondary)
                        TextField("例：讨厌的食物清单", text: $name)
                            .textFieldStyle(.roundedBorder)
                    }

                    // Filters
                    VStack(alignment: .leading, spacing: 8) {
                        Text("筛选条件").font(.caption).fontWeight(.semibold).foregroundStyle(.secondary)
                        ForEach(Array(filters.enumerated()), id: \.offset) { i, _ in
                            FilterRow(condition: $filters[i]) { filters.remove(at: i) }
                        }
                        Button("＋ 添加条件") { filters.append(FilterCondition()) }
                            .buttonStyle(.borderless).foregroundStyle(.orange)
                    }

                    // Columns
                    VStack(alignment: .leading, spacing: 8) {
                        Text("列表字段（勾选并调整顺序）")
                            .font(.caption).fontWeight(.semibold).foregroundStyle(.secondary)
                        ForEach(orderedColumns, id: \.key) { col in
                            HStack {
                                Toggle(col.label, isOn: Binding(
                                    get: { columnsEnabled.contains(col.key) },
                                    set: { v in
                                        if v { columnsEnabled.insert(col.key) }
                                        else { columnsEnabled.remove(col.key) }
                                    }
                                ))
                                Spacer()
                                VStack(spacing: 2) {
                                    Button { moveUp(col) } label: { Image(systemName: "chevron.up") }
                                        .buttonStyle(.borderless).font(.caption2)
                                    Button { moveDown(col) } label: { Image(systemName: "chevron.down") }
                                        .buttonStyle(.borderless).font(.caption2)
                                }
                            }
                            .padding(.horizontal, 8).padding(.vertical, 4)
                            .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 4))
                        }
                    }
                }
                .padding(20)
            }

            Divider()

            HStack {
                Spacer()
                Button("取消") { onSave(existing ?? FoodView()) }
                Button("保存视图") { save() }
                    .buttonStyle(.borderedProminent).tint(.orange)
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(16)
        }
        .frame(width: 400, height: 560)
    }

    private func moveUp(_ col: ColumnMeta) {
        guard let i = orderedColumns.firstIndex(where: { $0.key == col.key }), i > 0 else { return }
        orderedColumns.swapAt(i, i - 1)
    }

    private func moveDown(_ col: ColumnMeta) {
        guard let i = orderedColumns.firstIndex(where: { $0.key == col.key }), i < orderedColumns.count - 1 else { return }
        orderedColumns.swapAt(i, i + 1)
    }

    private func save() {
        let finalCols = orderedColumns.filter { columnsEnabled.contains($0.key) }.map { $0.key }
        var v = existing ?? FoodView()
        v.name    = name.trimmingCharacters(in: .whitespaces)
        v.filters = filters
        v.columns = finalCols.isEmpty ? ColumnMeta.defaultKeys : finalCols
        onSave(v)
    }
}

// MARK: - Filter row

struct FilterRow: View {
    @Binding var condition: FilterCondition
    let onDelete: () -> Void

    private let fields: [(key: String, label: String)] = [
        ("rating",    "喜好评分"), ("price",    "购入价格"),
        ("calories",  "卡路里"),   ("packaging", "包装形式"),
        ("category",  "分类"),     ("buy_again", "是否再购"),
    ]
    private let numericOps = [("lt","<"),("lte","≤"),("gt",">"),("gte","≥"),("eq","=")]

    var body: some View {
        HStack(spacing: 6) {
            Picker("", selection: $condition.field) {
                ForEach(fields, id: \.key) { Text($0.label).tag($0.key) }
            }
            .frame(width: 90)
            .onChange(of: condition.field) { _, _ in condition.value = "" }

            if condition.field == "rating" || condition.field == "price" || condition.field == "calories" {
                Picker("", selection: $condition.op) {
                    ForEach(numericOps, id: \.0) { Text($1).tag($0) }
                }
                .frame(width: 52)
                TextField(condition.field == "rating" ? "60" : condition.field == "calories" ? "250" : "30", text: $condition.value)
                    .textFieldStyle(.roundedBorder).frame(width: 70)
            } else if condition.field == "buy_again" {
                Picker("", selection: $condition.value) {
                    Text("会再购").tag("1")
                    Text("不再购").tag("0")
                }
                .onAppear { if condition.value.isEmpty { condition.value = "1" } }
            } else if condition.field == "packaging" {
                Picker("", selection: $condition.value) {
                    Text("♻️ 环保").tag("环保")
                    Text("比较环保").tag("比较环保（纸杯+涂层）")
                    Text("不太环保").tag("不太环保（塑料包装）")
                    Text("很不环保").tag("很不环保（大量塑料包装）")
                }
            } else { // category
                TextField("分类名", text: $condition.value).textFieldStyle(.roundedBorder).frame(width: 80)
            }

            Spacer()
            Button(action: onDelete) { Image(systemName: "xmark").font(.caption) }
                .buttonStyle(.borderless).foregroundStyle(.secondary)
        }
    }
}
