import SwiftUI

struct ContentView: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        Group {
            switch state.currentScreen {
            case .dashboard:
                DashboardView()
            case .newProject:
                DashboardView()
            case .project(let project):
                ProjectWorkspace(project: project)
            case .scriptStudio(let project, _):
                ProjectWorkspace(project: project)
            case .sceneBuilder(let project):
                ProjectWorkspace(project: project)
            case .assetLibrary(let project):
                ProjectWorkspace(project: project)
            case .storyboard(let project, let shot):
                ProjectWorkspace(project: project)
                    .onAppear { state.selectedShot = shot }
            case .settings:
                SettingsView()
            }
        }
        .frame(minWidth: 1000, minHeight: 660)
        .alert("Error", isPresented: $state.showError) {
            Button("OK") { state.showError = false }
        } message: {
            Text(state.errorMessage ?? "An error occurred")
        }
        .task { await state.onLaunch() }
    }
}

// MARK: - Project Workspace

struct ProjectWorkspace: View {
    @EnvironmentObject var state: AppState
    let project: Project

    var body: some View {
        NavigationSplitView {
            sidebar
                .navigationSplitViewColumnWidth(min: 180, ideal: 200, max: 240)
        } detail: {
            mainContent
        }
        .toolbar {
            ToolbarItem(placement: .navigation) {
                Button {
                    state.currentScreen = .dashboard
                    state.selectedProject = nil
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                        Text("Projects")
                    }
                }
                .buttonStyle(.plain)
            }
            ToolbarItem {
                HStack(spacing: 6) {
                    if !state.backendReachable {
                        Label("Backend offline", systemImage: "exclamationmark.triangle.fill")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                    if project.localOnly {
                        Label("Local", systemImage: "lock.fill")
                            .font(.caption)
                            .foregroundStyle(.green)
                    }
                }
            }
        }
    }

    private var sidebar: some View {
        List(selection: $state.sidebarItem) {
            Text(project.title)
                .font(.headline)
                .foregroundStyle(.primary)
                .listRowSeparator(.hidden)
                .padding(.bottom, 4)

            Section("Production") {
                SidebarItem(icon: "doc.text", label: "Script Studio", id: "script")
                SidebarItem(icon: "film.stack", label: "Scenes & Shots", id: "scenes")
                SidebarItem(icon: "photo.on.rectangle.angled", label: "Storyboard", id: "storyboard", badge: approvedShotCount)
                SidebarItem(icon: "photo.stack", label: "Asset Library", id: "assets", badge: state.assets.count)
            }

            Section("Pipeline") {
                SidebarItem(icon: "video.fill", label: "Preview Lab", id: "preview")
                SidebarItem(icon: "film", label: "Timeline", id: "timeline")
                SidebarItem(icon: "square.and.arrow.up", label: "Export", id: "export")
            }

            Section("Settings") {
                SidebarItem(icon: "gear", label: "Settings", id: "settings")
            }
        }
        .listStyle(.sidebar)
    }

    private var mainContent: some View {
        Group {
            switch state.sidebarItem {
            case "script":
                ScriptStudioView(project: project)
            case "scenes":
                SceneBuilderView(project: project)
            case "storyboard":
                if let shot = state.selectedShot {
                    StoryboardView(project: project, shot: shot)
                } else {
                    SceneBuilderView(project: project)
                }
            case "assets":
                AssetLibraryView(project: project)
            case "settings":
                SettingsView()
            default:
                ComingSoonView(feature: state.sidebarItem.capitalized)
            }
        }
    }

    private var approvedShotCount: Int {
        // placeholder — would tally approved shots across scenes
        0
    }
}

// MARK: - Sidebar Item

struct SidebarItem: View {
    let icon: String
    let label: String
    let id: String
    var badge: Int = 0

    var body: some View {
        Label {
            HStack {
                Text(label)
                Spacer()
                if badge > 0 {
                    Text("\(badge)")
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.secondary.opacity(0.2))
                        .clipShape(Capsule())
                }
            }
        } icon: {
            Image(systemName: icon)
        }
        .tag(id)
    }
}

// MARK: - Coming Soon

struct ComingSoonView: View {
    let feature: String
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "hammer")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("\(feature)")
                .font(.title2.bold())
            Text("This feature is planned for a future phase.")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
