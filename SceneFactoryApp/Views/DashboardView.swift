import SwiftUI

struct DashboardView: View {
    @EnvironmentObject var state: AppState
    @State private var showNewProject = false
    @State private var searchText = ""
    @State private var deleteTarget: Project?

    var filteredProjects: [Project] {
        if searchText.isEmpty { return state.projects }
        return state.projects.filter {
            $0.title.localizedCaseInsensitiveContains(searchText) ||
            ($0.description ?? "").localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            Divider()
            if state.isLoadingProjects {
                Spacer()
                ProgressView("Loading projects…")
                Spacer()
            } else if filteredProjects.isEmpty {
                emptyState
            } else {
                projectGrid
            }
        }
        .background(Color(NSColor.windowBackgroundColor))
        .sheet(isPresented: $showNewProject) {
            NewProjectView { project in
                Task { await state.openProject(project) }
            }
        }
        .alert("Delete Project", isPresented: Binding(
            get: { deleteTarget != nil },
            set: { if !$0 { deleteTarget = nil } }
        )) {
            Button("Cancel", role: .cancel) { deleteTarget = nil }
            Button("Delete", role: .destructive) {
                if let p = deleteTarget {
                    Task { await state.deleteProject(p) }
                }
                deleteTarget = nil
            }
        } message: {
            Text("This will permanently delete \"\(deleteTarget?.title ?? "")\" and all its files.")
        }
    }

    private var toolbar: some View {
        HStack(spacing: 12) {
            Text("Scene Factory")
                .font(.title2.bold())

            Spacer()

            TextField("Search projects…", text: $searchText)
                .textFieldStyle(.roundedBorder)
                .frame(width: 220)

            StatusDot(available: state.backendReachable, label: state.backendReachable ? "Backend running" : "Backend offline")

            Button {
                showNewProject = true
            } label: {
                Label("New Project", systemImage: "plus")
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }

    private var projectGrid: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 280, maximum: 340), spacing: 16)], spacing: 16) {
                ForEach(filteredProjects) { project in
                    ProjectCard(project: project) {
                        Task { await state.openProject(project) }
                    } onDelete: {
                        deleteTarget = project
                    }
                }
            }
            .padding(20)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "film.stack")
                .font(.system(size: 64))
                .foregroundStyle(.secondary)
            Text(searchText.isEmpty ? "No projects yet" : "No matching projects")
                .font(.title3.bold())
            Text(searchText.isEmpty ? "Create your first project to start turning stories into cinematic videos." : "Try a different search term.")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 360)
            if searchText.isEmpty {
                Button("New Project") { showNewProject = true }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
            }
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Project Card

struct ProjectCard: View {
    let project: Project
    let onOpen: () -> Void
    let onDelete: () -> Void
    @State private var hovering = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                statusBadge
                Spacer()
                Menu {
                    Button("Open") { onOpen() }
                    Divider()
                    Button("Delete…", role: .destructive) { onDelete() }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .foregroundStyle(.secondary)
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(project.title)
                    .font(.headline)
                    .lineLimit(2)
                if let desc = project.description {
                    Text(desc)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }

            HStack(spacing: 8) {
                if let genre = project.genre {
                    Tag(label: genre, color: .purple)
                }
                if project.localOnly {
                    Tag(label: "Local", color: .green)
                }
                Tag(label: project.language.capitalized, color: .blue)
            }

            Divider()

            HStack {
                Text(project.updatedAt, style: .relative)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                Spacer()
                Text(project.userMode.capitalized)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(NSColor.controlBackgroundColor))
                .shadow(color: .black.opacity(hovering ? 0.12 : 0.06), radius: hovering ? 8 : 4, y: hovering ? 4 : 2)
        )
        .onHover { hovering = $0 }
        .onTapGesture(count: 2) { onOpen() }
        .animation(.easeInOut(duration: 0.15), value: hovering)
    }

    private var statusBadge: some View {
        let (label, color): (String, Color) = switch project.status {
        case "new": ("New", .gray)
        case "in_progress": ("In Progress", .orange)
        case "complete": ("Complete", .green)
        default: (project.status.capitalized, .gray)
        }
        return Text(label)
            .font(.caption2.bold())
            .padding(.horizontal, 8).padding(.vertical, 3)
            .background(color.opacity(0.15))
            .foregroundStyle(color)
            .clipShape(Capsule())
    }
}

// MARK: - Helpers

struct Tag: View {
    let label: String
    let color: Color
    var body: some View {
        Text(label)
            .font(.caption2)
            .padding(.horizontal, 6).padding(.vertical, 2)
            .background(color.opacity(0.12))
            .foregroundStyle(color)
            .clipShape(RoundedRectangle(cornerRadius: 4))
    }
}

struct StatusDot: View {
    let available: Bool
    let label: String
    var body: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(available ? Color.green : Color.red)
                .frame(width: 7, height: 7)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 8).padding(.vertical, 4)
        .background(Color(NSColor.controlBackgroundColor))
        .clipShape(Capsule())
    }
}
