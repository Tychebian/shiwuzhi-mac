import SwiftUI

// MARK: - FoodListView

struct FoodListView: View {
    @Environment(AppState.self) private var state
    @State private var showAddForm = false
    @State private var editingFood: Food? = nil

    private let presetCategories = ["咖啡和茶", "正餐", "零食"]

    var body: some View {
        @Bindable var state = state
        VStack(spacing: 0) {
            // Toolbar
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField("搜索食物…", text: $state.searchQuery)
                    .textFieldStyle(.plain)
                    .onChange(of: state.searchQuery) { _, _ in state.loadFoods() }

                Divider().frame(height: 16)

                Picker("分类", selection: $state.selectedCategory) {
                    Text("全部分类").tag("")
                    ForEach(allCategories, id: \.self) { Text($0).tag($0) }
                }
                .frame(width: 110)
                .onChange(of: state.selectedCategory) { _, _ in state.loadFoods() }

                SortPicker(sort: $state.mainSort) { state.loadFoods() }

                Button { showAddForm = true } label: {
                    Label("添加", systemImage: "plus")
                }
                .keyboardShortcut("n", modifiers: .command)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.bar)

            Divider()

            if state.foods.isEmpty {
                emptyView
            } else {
                FoodTable(foods: state.foods, columns: ColumnMeta.defaultKeys) { food in
                    editingFood = food
                } onDuplicate: { food in
                    duplicateFood(food)
                }
            }
        }
        .navigationTitle("全部记录")
        .sheet(isPresented: $showAddForm) {
            FoodFormView(food: Food()) { saved in
                state.saveFood(saved)
                showAddForm = false
            }
            .environment(state)
        }
        .sheet(item: $editingFood) { food in
            FoodFormView(food: food) { saved in
                state.saveFood(saved)
                editingFood = nil
            } onDelete: {
                state.deleteFood(food)
                editingFood = nil
            }
            .environment(state)
        }
    }

    private var allCategories: [String] {
        let custom = state.allCategories.filter { !presetCategories.contains($0) }
        return presetCategories + custom
    }

    private var emptyView: some View {
        ContentUnavailableView(
            "暂无记录",
            systemImage: "fork.knife",
            description: Text("点击「添加」开始收录食物")
        )
    }

    private func duplicateFood(_ f: Food) {
        state.loadRatings()
        var copy = f
        copy.id = 0
        copy.purchaseDate = {
            let fmt = DateFormatter(); fmt.dateFormat = "yyyy-MM-dd"
            return fmt.string(from: Date())
        }()
        copy.rating = state.findFreeRating(near: f.rating)
        editingFood = copy
    }
}

// MARK: - FoodTable

struct FoodTable: View {
    let foods: [Food]
    let columns: [String]
    var onSelect: (Food) -> Void
    var onDuplicate: (Food) -> Void

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                // Header
                FoodRowHeader(columns: columns)
                Divider()

                ForEach(foods) { food in
                    FoodRow(food: food, columns: columns)
                        .contentShape(Rectangle())
                        .onTapGesture { onSelect(food) }
                        .contextMenu {
                            Button("复制记录") { onDuplicate(food) }
                        }
                    Divider().padding(.leading, 12)
                }
            }
        }
    }
}

// MARK: - FoodRowHeader

struct FoodRowHeader: View {
    let columns: [String]
    var body: some View {
        HStack(spacing: 0) {
            ForEach(columns, id: \.self) { col in
                Text(ColumnMeta.label(for: col))
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: col == "name" || col == "note" ? .infinity : colWidth(col), alignment: .leading)
                    .padding(.horizontal, 6)
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 6)
        .background(.quaternary.opacity(0.5))
    }

    private func colWidth(_ col: String) -> CGFloat {
        switch col {
        case "rating": return 48
        case "buy_again": return 68
        case "price": return 72
        case "calories":  return 72
        case "meal_type": return 60
        case "purchase_date": return 90
        default: return 80
        }
    }
}

// MARK: - FoodRow

struct FoodRow: View {
    let food: Food
    let columns: [String]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(columns, id: \.self) { col in
                foodCell(col)
                    .frame(maxWidth: col == "name" || col == "note" ? .infinity : colWidth(col), alignment: .leading)
                    .padding(.horizontal, 6)
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 8)
    }

    @ViewBuilder
    private func foodCell(_ col: String) -> some View {
        switch col {
        case "name":
            Text(food.name).fontWeight(.semibold).lineLimit(1)
        case "category":
            Text(food.category.isEmpty ? "—" : food.category).font(.subheadline).foregroundStyle(.secondary).lineLimit(1)
        case "brand":
            Text(food.brand.isEmpty ? "—" : food.brand).font(.subheadline).foregroundStyle(.secondary).lineLimit(1)
        case "source":
            Text(food.source.isEmpty ? "—" : food.source).font(.subheadline).foregroundStyle(.secondary).lineLimit(1)
        case "packaging":
            Text(food.packaging.isEmpty ? "—" : food.packaging).font(.caption).foregroundStyle(.secondary).lineLimit(1)
        case "rating":
            Text("\(food.rating)").fontWeight(.bold).foregroundStyle(.orange)
        case "buy_again":
            Text(food.buyAgain ? "会再购" : "不再购")
                .font(.caption).fontWeight(.semibold)
                .padding(.horizontal, 6).padding(.vertical, 2)
                .background(food.buyAgain ? Color.green.opacity(0.15) : Color.red.opacity(0.12))
                .foregroundStyle(food.buyAgain ? .green : .red)
                .clipShape(RoundedRectangle(cornerRadius: 4))
        case "price":
            if let price = food.price {
                Text("¥\(String(format: "%.2f", price))").fontWeight(.semibold).foregroundStyle(.orange)
            } else {
                Text("—").foregroundStyle(.secondary)
            }
        case "calories":
            if let cal = food.calories {
                Text("\(cal) kcal").font(.subheadline).foregroundStyle(.secondary)
            } else {
                Text("—").foregroundStyle(.secondary)
            }
        case "purchase_date":
            Text(food.purchaseDate.isEmpty ? "—" : food.purchaseDate).font(.subheadline).foregroundStyle(.secondary)
        case "meal_type":
            Text(food.mealType.isEmpty ? "—" : food.mealType).font(.subheadline).foregroundStyle(.secondary)
        case "note":
            Text(food.note.isEmpty ? "" : food.note).font(.subheadline).foregroundStyle(.secondary).lineLimit(1)
        default:
            EmptyView()
        }
    }

    private func colWidth(_ col: String) -> CGFloat {
        switch col {
        case "rating": return 48
        case "buy_again": return 68
        case "price": return 72
        case "calories":  return 72
        case "meal_type": return 60
        case "purchase_date": return 90
        default: return 80
        }
    }
}

// MARK: - SortPicker

struct SortPicker: View {
    @Binding var sort: SortState
    var onChange: () -> Void

    var body: some View {
        HStack(spacing: 4) {
            Picker("排序", selection: $sort.field) {
                ForEach(SortState.allFields, id: \.key) { f in
                    Text(f.label).tag(f.key)
                }
            }
            .frame(width: 90)
            .onChange(of: sort.field) { _, _ in onChange() }

            Button {
                sort.ascending.toggle()
                onChange()
            } label: {
                Image(systemName: sort.ascending ? "arrow.up" : "arrow.down")
                    .font(.caption)
            }
            .buttonStyle(.borderless)
        }
    }
}
