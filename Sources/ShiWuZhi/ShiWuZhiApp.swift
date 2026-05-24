import SwiftUI

@main
struct ShiWuZhiApp: App {
    @State private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(appState)
        }
        .windowStyle(.titleBar)
        .defaultSize(width: 960, height: 640)

        Settings {
            SettingsView()
                .environment(appState)
        }
    }
}
