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

// MARK: - Today foods view

struct TodayFoodsView: View {
    @Environment(AppState.self) private var state
    @State private var editingFood: Food? = nil
    @State private var showAddForm = false

    private var today: String {
        let fmt = DateFormatter(); fmt.dateFormat = "yyyy-MM-dd"
        return fmt.string(from: Date())
    }

    private var todayLabel: String {
        let fmt = DateFormatter()
        fmt.dateFormat = "M月d日"
        fmt.locale = Locale(identifier: "zh_CN")
        return fmt.string(from: Date())
    }

    var body: some View {
        let foods = state.foodsForDate(today)
        VStack(spacing: 0) {
            HStack {
                Text(todayLabel).font(.subheadline).foregroundStyle(.secondary)
                Spacer()
                Text("\(foods.count) 条记录").font(.caption).foregroundStyle(.secondary)
                Button { showAddForm = true } label: {
                    Label("添加", systemImage: "plus")
                }
                .keyboardShortcut("n", modifiers: .command)
            }
            .padding(.horizontal, 14).padding(.vertical, 8)
            .background(.bar)

            Divider()

            if foods.isEmpty {
                ContentUnavailableView("今天还没有记录",
                    systemImage: "fork.knife",
                    description: Text("点击「添加」记录今天吃了什么"))
            } else {
                FoodTable(foods: foods, columns: ColumnMeta.defaultKeys) { food in
                    editingFood = food
                } onDuplicate: { food in
                    state.loadRatings()
                    var copy = food; copy.id = 0
                    copy.rating = state.findFreeRating(near: food.rating)
                    editingFood = copy
                }
            }
        }
        .navigationTitle("今天吃什么")
        .sheet(isPresented: $showAddForm) {
            let newFood: Food = { var f = Food(); f.purchaseDate = today; return f }()
            FoodFormView(food: newFood) { saved in
                state.saveFood(saved)
                showAddForm = false
            }
            .environment(state)
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
