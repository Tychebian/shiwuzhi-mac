import SwiftUI

struct SettingsView: View {
    @Environment(AppState.self) private var state

    var body: some View {
        @Bindable var state = state
        Form {
            Section("显示设置") {
                Toggle(isOn: $state.dedup) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("同名食物自动去重")
                        Text("勾选后，每种食物只显示最近一条记录；取消勾选则显示该食物的全部购买记录。")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Section("关于") {
                LabeledContent("版本", value: "1.0.0")
                LabeledContent("数据文件", value: "~/.shiwuzhi.db")
                Text("与网页版（shiwuzhi）共享同一份数据库，可以互相切换使用。")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .navigationTitle("设置")
        .frame(minWidth: 400)
    }
}
