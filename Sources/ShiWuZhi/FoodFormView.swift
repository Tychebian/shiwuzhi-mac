import SwiftUI

struct FoodFormView: View {
    @Environment(AppState.self) private var state
    @State private var food: Food
    @State private var errorMsg: String = ""
    @State private var ratingConflict: String = ""

    private let isEditing: Bool
    private let onSave: (Food) -> Void
    private let onDelete: (() -> Void)?

    private let presetCategories = ["咖啡和茶", "正餐", "零食"]
    private let presetPackaging  = ["♻️ 环保", "🟡 比较环保（纸杯+涂层）", "🟠 不太环保（塑料包装）", "🔴 很不环保（大量塑料包装）"]

    init(food: Food, onSave: @escaping (Food) -> Void, onDelete: (() -> Void)? = nil) {
        _food = State(initialValue: food)
        self.isEditing = food.id != 0
        self.onSave    = onSave
        self.onDelete  = onDelete
    }

    var body: some View {
        VStack(spacing: 0) {
            // Title bar
            HStack {
                Text(isEditing ? "编辑记录" : "添加食物")
                    .font(.headline)
                Spacer()
                if isEditing, let del = onDelete {
                    Button(role: .destructive) { del() } label: {
                        Label("删除", systemImage: "trash").foregroundStyle(.red)
                    }
                    .buttonStyle(.borderless)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 12)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {

                    // Name
                    field("食物名称") {
                        TextField("例：老干妈豆豉酱", text: $food.name)
                            .textFieldStyle(.roundedBorder)
                    }

                    // Category + Brand
                    HStack(spacing: 12) {
                        field("分类") {
                            categoryPicker
                        }
                        field("品牌") {
                            TextField("老干妈 / 三只松鼠…", text: $food.brand)
                                .textFieldStyle(.roundedBorder)
                        }
                    }

                    // Source + Packaging
                    HStack(spacing: 12) {
                        field("来源") {
                            TextField("外卖 / 叮咚 / 盒马…", text: $food.source)
                                .textFieldStyle(.roundedBorder)
                        }
                        field("包装形式") {
                            Picker("", selection: $food.packaging) {
                                Text("请选择").tag("")
                                ForEach(presetPackaging, id: \.self) { Text($0).tag($0) }
                            }
                        }
                    }

                    // Date + Price
                    HStack(spacing: 12) {
                        field("购入日期") {
                            TextField("2026-01-01", text: $food.purchaseDate)
                                .textFieldStyle(.roundedBorder)
                        }
                        field("购入价格（元）") {
                            TextField("9.90", value: $food.price, format: .number)
                                .textFieldStyle(.roundedBorder)
                        }
                    }

                    // Rating
                    field("喜好评分：\(food.rating) / 100") {
                        VStack(alignment: .leading, spacing: 4) {
                            Slider(value: Binding(
                                get: { Double(food.rating) },
                                set: { v in
                                    food.rating = Int(v)
                                    checkRatingConflict()
                                }
                            ), in: 1...100, step: 1)
                            .tint(.orange)

                            if !ratingConflict.isEmpty {
                                Label("评分 \(food.rating) 已被「\(ratingConflict)」占用", systemImage: "exclamationmark.triangle")
                                    .font(.caption)
                                    .foregroundStyle(.red)
                            }
                        }
                    }

                    // Buy again
                    field("是否会再次购买") {
                        Picker("", selection: $food.buyAgain) {
                            Text("✓ 会").tag(true)
                            Text("✕ 不会").tag(false)
                        }
                        .pickerStyle(.segmented)
                    }

                    // Note
                    field("备注") {
                        TextEditor(text: $food.note)
                            .frame(height: 64)
                            .overlay(RoundedRectangle(cornerRadius: 6).stroke(.quaternary))
                            .font(.body)
                    }

                    if !errorMsg.isEmpty {
                        Text(errorMsg).font(.caption).foregroundStyle(.red)
                    }
                }
                .padding(20)
            }

            Divider()

            // Buttons
            HStack {
                Spacer()
                Button("取消", role: .cancel) { onSave(food) }
                    .keyboardShortcut(.escape, modifiers: [])
                    .onAppear { /* dismiss workaround not needed */ }
                Button("保存") { save() }
                    .keyboardShortcut(.return, modifiers: .command)
                    .buttonStyle(.borderedProminent)
                    .tint(.orange)
                    .disabled(!ratingConflict.isEmpty || food.name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(16)
        }
        .frame(width: 480)
        .onAppear {
            state.loadRatings()
            checkRatingConflict()
        }
    }

    // MARK: - Helpers

    @ViewBuilder
    private func field<Content: View>(_ label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.caption).foregroundStyle(.secondary)
            content()
        }
    }

    private var categoryPicker: some View {
        let allCats = presetCategories + state.allCategories.filter { !presetCategories.contains($0) }
        return Picker("", selection: $food.category) {
            Text("请选择").tag("")
            ForEach(allCats, id: \.self) { Text($0).tag($0) }
        }
    }

    private func checkRatingConflict() {
        ratingConflict = state.ratingClash(rating: food.rating, editingFood: food) ?? ""
    }

    private func save() {
        let trimmed = food.name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { errorMsg = "请输入食物名称"; return }
        guard ratingConflict.isEmpty else { errorMsg = "评分已被占用"; return }
        var f = food; f.name = trimmed
        onSave(f)
    }
}
