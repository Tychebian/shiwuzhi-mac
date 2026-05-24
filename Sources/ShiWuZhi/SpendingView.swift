import SwiftUI

struct SpendingView: View {
    @Environment(AppState.self) private var state
    @State private var period: String = "month"
    @State private var data: [SpendPeriod] = []
    @State private var expandedDay: String? = nil
    @State private var dayFoods: [Food] = []

    var body: some View {
        VStack(spacing: 0) {
            // Segment
            HStack(spacing: 0) {
                ForEach([("month","按月"),("week","按周"),("day","按日")], id: \.0) { p, label in
                    Button(label) { period = p; load(); expandedDay = nil }
                        .buttonStyle(.borderless)
                        .padding(.horizontal, 16).padding(.vertical, 7)
                        .background(period == p ? Color.orange : Color.clear)
                        .foregroundStyle(period == p ? .white : .primary)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
            }
            .padding(10)
            .background(.bar)

            Divider()

            if data.isEmpty {
                ContentUnavailableView(
                    "暂无花费数据",
                    systemImage: "cart",
                    description: Text("添加食物时填写「购入价格」即可")
                )
            } else {
                let grandTotal = data.reduce(0) { $0 + $1.total }
                let maxTotal   = data.map(\.total).max() ?? 1

                ScrollView {
                    VStack(spacing: 0) {
                        // Overview card
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("¥\(String(format: "%.2f", grandTotal))")
                                    .font(.system(size: 28, weight: .bold)).foregroundStyle(.orange)
                                Text("全部已记录花费").font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 4) {
                                Text("\(data.count)\(periodUnit)")
                                    .font(.headline).foregroundStyle(.secondary)
                                Text("\(data.reduce(0) { $0 + $1.count }) 件有价格记录")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        .padding(16)
                        .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 10))
                        .padding(14)

                        // Rows
                        VStack(spacing: 0) {
                            ForEach(data) { row in
                                VStack(spacing: 0) {
                                    SpendRow(
                                        row: row,
                                        period: period,
                                        maxTotal: maxTotal,
                                        isExpanded: expandedDay == row.period,
                                        isClickable: period == "day"
                                    ) {
                                        if period == "day" {
                                            if expandedDay == row.period {
                                                expandedDay = nil
                                            } else {
                                                expandedDay = row.period
                                                dayFoods = state.foodsForDate(row.period)
                                            }
                                        }
                                    }

                                    if period == "day" && expandedDay == row.period {
                                        DayDetailView(foods: dayFoods)
                                    }

                                    Divider()
                                }
                            }
                        }
                        .background(.background)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(.separator))
                        .padding(.horizontal, 14)
                        .padding(.bottom, 20)
                    }
                }
            }
        }
        .navigationTitle("花费统计")
        .onAppear { load() }
    }

    private var periodUnit: String {
        switch period {
        case "month": return "个月"
        case "week":  return "个周"
        default:      return "天"
        }
    }

    private func load() {
        data = state.spendSummary(period: period)
    }
}

// MARK: - Spend row

struct SpendRow: View {
    let row: SpendPeriod
    let period: String
    let maxTotal: Double
    let isExpanded: Bool
    let isClickable: Bool
    let onTap: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Text(periodLabel)
                .font(.subheadline).fontWeight(.semibold)
                .frame(width: 120, alignment: .leading)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3).fill(.quaternary).frame(height: 6)
                    RoundedRectangle(cornerRadius: 3)
                        .fill(LinearGradient(colors: [.orange, .yellow], startPoint: .leading, endPoint: .trailing))
                        .frame(width: geo.size.width * CGFloat(maxTotal > 0 ? row.total / maxTotal : 0), height: 6)
                }
                .frame(maxHeight: .infinity)
            }

            Text("\(row.count)件")
                .font(.caption).foregroundStyle(.secondary).frame(width: 44, alignment: .trailing)

            Text("¥\(String(format: "%.2f", row.total))")
                .font(.subheadline).fontWeight(.bold).foregroundStyle(.orange)
                .frame(width: 80, alignment: .trailing)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(isExpanded ? Color.orange.opacity(0.06) : Color.clear)
        .contentShape(Rectangle())
        .onTapGesture { if isClickable { onTap() } }
        .cursor(isClickable ? .pointingHand : .arrow)
    }

    private var periodLabel: String {
        switch period {
        case "month":
            let parts = row.period.split(separator: "-")
            if parts.count >= 2, let m = Int(parts[1]) { return "\(parts[0])年\(m)月" }
        case "week":
            let parts = row.period.split(separator: "-")
            if parts.count >= 2, let w = Int(parts[1]) { return "\(parts[0]) W\(String(format: "%02d", w))" }
        default:
            let parts = row.period.split(separator: "-")
            if parts.count >= 3, let m = Int(parts[1]), let d = Int(parts[2]) { return "\(m)月\(d)日" }
        }
        return row.period
    }
}

// MARK: - Day detail

struct DayDetailView: View {
    let foods: [Food]

    var body: some View {
        VStack(spacing: 0) {
            ForEach(foods) { food in
                HStack {
                    Text(food.name)
                        .font(.subheadline).foregroundStyle(.secondary)
                        .padding(.leading, 32)
                    Spacer()
                    if let price = food.price {
                        Text("¥\(String(format: "%.2f", price))")
                            .font(.subheadline).fontWeight(.semibold).foregroundStyle(.orange)
                    } else {
                        Text("—").foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.orange.opacity(0.03))
                Divider().padding(.leading, 32)
            }
        }
    }
}

// MARK: - Cursor modifier

extension View {
    func cursor(_ cursor: NSCursor) -> some View {
        self.onHover { inside in
            if inside { cursor.push() } else { NSCursor.pop() }
        }
    }
}
