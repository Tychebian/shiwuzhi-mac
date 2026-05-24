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
                Label("花费统计", systemImage: "chart.bar").tag(SidebarItem.spending)
            }

            if !state.savedViews.isEmpty {
                Section("自定义视图") {
                    ForEach(state.savedViews) { view in
                        HStack {
                            Label(view.name, systemImage: "line.3.horizontal.decrease.circle")
                            Spacer()
                            Button {
                                state.deleteView(view)
                            } label: {
                                Image(systemName: "xmark").font(.caption).foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                            .opacity(0.4)
                        }
                        .tag(SidebarItem.savedView(view.id))
                    }
                }
            }

            Section("设置") {
                Label("偏好设置", systemImage: "gearshape").tag(SidebarItem.settings)
            }
        }
        .navigationSplitViewColumnWidth(min: 180, ideal: 200)
        .navigationTitle("食物志")
    }
}

// MARK: - Detail router

struct DetailRouter: View {
    @Environment(AppState.self) private var state

    var body: some View {
        switch state.selection {
        case .allFoods, nil:
            FoodListView().environment(state)
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
