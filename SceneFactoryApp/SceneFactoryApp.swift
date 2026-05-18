import SwiftUI

@main
struct SceneFactoryApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified(showsTitle: true))
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New Project") {
                    appState.currentScreen = .newProject
                }
                .keyboardShortcut("n", modifiers: .command)
            }

            CommandGroup(after: .windowArrangement) {
                Divider()
                Button("Dashboard") {
                    appState.currentScreen = .dashboard
                }
                .keyboardShortcut("d", modifiers: [.command, .shift])

                if let project = appState.selectedProject {
                    Button("Script Studio") {
                        appState.sidebarItem = "script"
                    }
                    .keyboardShortcut("1", modifiers: .command)

                    Button("Scenes & Shots") {
                        appState.sidebarItem = "scenes"
                    }
                    .keyboardShortcut("2", modifiers: .command)

                    Button("Asset Library") {
                        appState.sidebarItem = "assets"
                    }
                    .keyboardShortcut("3", modifiers: .command)
                }
            }

            CommandGroup(replacing: .help) {
                Button("Scene Factory Documentation") { }
                Button("Check Service Status") {
                    Task { await appState.checkBackend() }
                }
            }
        }

        Settings {
            SettingsView()
                .environmentObject(appState)
                .frame(width: 680, height: 700)
        }
    }
}
