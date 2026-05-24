import SwiftUI

struct ContentView: View {
    @Environment(AppState.self) private var state

    var body: some View {
        @Bindable var state = state
        NavigationSplitView {
            SidebarView()
                .environment(state)
        } detail: {
            DetailRouter()
                .environment(state)
        }
    }
}

// MARK: - Sidebar

struct SidebarView: View {
    @Environment(AppState.self) private var state
    @State private var showViewBuilder = false

    var body: some View {
        @Bindable var state = state
        List(selection: $state.selection) {
            // Meta cards
            HStack(spacing: 8) {
                MetaCard(value: "\(state.metaTotal)", label: "已收录")
                MetaCard(value: String(format: "%.1f", state.metaAvgRating), label: "平均评分")
                MetaCard(value: "\(state.metaBuyAgain)", label: "会再购")
            }
            .padding(.vertical, 4)
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)

            Section("视图") {
                Label("全部记录", systemImage: "list.bullet").tag(SidebarItem.allFoods)
                Label("今天吃什么", systemImage: "sun.horizon").tag(SidebarItem.todayFoods)
                Label("花费统计", systemImage: "chart.bar").tag(SidebarItem.spending)
            }

            Section {
                ForEach(state.savedViews) { view in
                    HStack {
                        Label(view.name, systemImage: "line.3.horizontal.decrease.circle")
                        Spacer()
                        Button { state.deleteView(view) } label: {
                            Image(systemName: "xmark").font(.caption).foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                        .opacity(0.4)
                    }
                    .tag(SidebarItem.savedView(view.id))
                }
                Button { showViewBuilder = true } label: {
                    Label("新建视图", systemImage: "plus").foregroundStyle(.orange)
                }
                .buttonStyle(.borderless)
            } header: {
                Text("自定义视图")
            }

            Section("设置") {
                Label("偏好设置", systemImage: "gearshape").tag(SidebarItem.settings)
            }
        }
        .navigationSplitViewColumnWidth(min: 180, ideal: 200)
        .navigationTitle("食物志")
        .sheet(isPresented: $showViewBuilder) {
            ViewBuilderView { newView in
                if !newView.name.trimmingCharacters(in: .whitespaces).isEmpty {
                    state.saveView(newView)
                }
                showViewBuilder = false
            }
            .environment(state)
        }
    }
}

// MARK: - Detail router

struct DetailRouter: View {
    @Environment(AppState.self) private var state

    var body: some View {
        switch state.selection {
        case .allFoods, nil:
            FoodListView().environment(state)
        case .todayFoods:
            TodayFoodsView().environment(state)
        case .spending:
            SpendingView().environment(state)
        case .settings:
            SettingsView().environment(state)
        case .savedView(let id):
            if let view = state.savedViews.first(where: { $0.id == id }) {
                SavedViewDetailView(foodView: view).environment(state)
            } else {
                FoodListView().environment(state)
            }
        }
    }
}

// MARK: - Today foods view (timeline)

struct TodayFoodsView: View {
    @Environment(AppState.self) private var state
    @State private var editingFood: Food? = nil
    @State private var showAddForm = false
    @State private var newFoodMealType: String = ""

    static let mealOrder   = ["早餐", "午餐", "晚餐", "零食", "夜宵", ""]
    static let mealLabels  = ["早餐":"早餐","午餐":"午餐","晚餐":"晚餐","零食":"零食","夜宵":"夜宵","":"未分类"]
    static let mealIcons   = ["早餐":"sunrise.fill","午餐":"sun.max.fill","晚餐":"moon.stars.fill",
                               "零食":"popcorn.fill","夜宵":"moon.fill","":"fork.knife"]

    private var today: String {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"; return f.string(from: Date())
    }
    private var todayLabel: String {
        let f = DateFormatter(); f.dateFormat = "M月d日 EEEE"
        f.locale = Locale(identifier: "zh_CN"); return f.string(from: Date())
    }

    var body: some View {
        let foods   = state.foodsForDate(today)
        let grouped = Dictionary(grouping: foods) { $0.mealType }
        let present = Self.mealOrder.filter { grouped[$0] != nil }

        VStack(spacing: 0) {
            HStack {
                Text(todayLabel).font(.subheadline).foregroundStyle(.secondary)
                Spacer()
                Text("\(foods.count) 条记录").font(.caption).foregroundStyle(.secondary)
                Button { newFoodMealType = ""; showAddForm = true } label: {
                    Label("添加", systemImage: "plus")
                }
                .keyboardShortcut("n", modifiers: .command)
            }
            .padding(.horizontal, 14).padding(.vertical, 8)
            .background(.bar)

            Divider()

            if foods.isEmpty {
                ContentUnavailableView("今天还没有记录", systemImage: "fork.knife",
                    description: Text("点击「添加」记录今天吃了什么"))
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(Array(present.enumerated()), id: \.element) { idx, meal in
                            MealTimelineSection(
                                meal: meal,
                                label: Self.mealLabels[meal] ?? meal,
                                icon: Self.mealIcons[meal] ?? "fork.knife",
                                foods: grouped[meal] ?? [],
                                isLast: idx == present.count - 1,
                                onEdit: { editingFood = $0 },
                                onAdd: { newFoodMealType = meal; showAddForm = true }
                            )
                        }
                    }
                    .padding(.vertical, 16)
                }
            }
        }
        .navigationTitle("今天吃什么")
        .sheet(isPresented: $showAddForm) {
            let newFood: Food = {
                var f = Food(); f.purchaseDate = today; f.mealType = newFoodMealType; return f
            }()
            FoodFormView(food: newFood) { saved in
                state.saveFood(saved); showAddForm = false
            }
            .environment(state)
        }
        .sheet(item: $editingFood) { food in
            let del: (() -> Void)? = food.id == 0 ? nil : { state.deleteFood(food); editingFood = nil }
            FoodFormView(food: food, onSave: { saved in
                state.saveFood(saved); editingFood = nil
            }, onDelete: del)
            .environment(state)
        }
    }
}

// MARK: - Meal timeline section

struct MealTimelineSection: View {
    let meal: String
    let label: String
    let icon: String
    let foods: [Food]
    let isLast: Bool
    let onEdit: (Food) -> Void
    let onAdd: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            // Left: dot + vertical line
            VStack(spacing: 0) {
                ZStack {
                    Circle().fill(Color.orange).frame(width: 28, height: 28)
                    Image(systemName: icon).font(.system(size: 12, weight: .semibold)).foregroundStyle(.white)
                }
                if !isLast {
                    Rectangle().fill(Color.orange.opacity(0.2)).frame(width: 2).frame(maxHeight: .infinity)
                }
            }
            .frame(width: 48)

            // Right: header + food cards
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(label).font(.headline)
                    Spacer()
                    Button { onAdd() } label: {
                        Label("添加", systemImage: "plus.circle").font(.caption)
                    }
                    .buttonStyle(.borderless).foregroundStyle(.orange)
                }

                ForEach(foods) { food in
                    FoodTimelineCard(food: food)
                        .contentShape(Rectangle())
                        .onTapGesture { onEdit(food) }
                        .cursor(.pointingHand)
                }
            }
            .padding(.leading, 8)
            .padding(.trailing, 20)
            .padding(.bottom, 28)
        }
        .padding(.leading, 16)
    }
}

// MARK: - Food timeline card

struct FoodTimelineCard: View {
    let food: Food

    var body: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                Text(food.name).fontWeight(.semibold).lineLimit(1)
                let sub = [food.category, food.note].filter { !$0.isEmpty }.joined(separator: " · ")
                if !sub.isEmpty {
                    Text(sub).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                if let price = food.price {
                    Text("¥\(String(format: "%.2f", price))")
                        .font(.caption).fontWeight(.semibold).foregroundStyle(.orange)
                }
                if let cal = food.calories {
                    Text("\(cal) kcal").font(.caption2).foregroundStyle(.secondary)
                }
            }
            ZStack {
                Circle().fill(ratingBg(food.rating)).frame(width: 32, height: 32)
                Text("\(food.rating)").font(.caption).fontWeight(.bold).foregroundStyle(.white)
            }
        }
        .padding(.horizontal, 12).padding(.vertical, 9)
        .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 8))
    }

    private func ratingBg(_ r: Int) -> Color {
        r >= 80 ? .green : r >= 60 ? .orange : .red
    }
}

// MARK: - Meta card

struct MetaCard: View {
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 2) {
            Text(value).font(.system(size: 18, weight: .bold)).foregroundStyle(.orange)
            Text(label).font(.caption2).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(8)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
    }
}
