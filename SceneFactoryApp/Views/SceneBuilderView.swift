import SwiftUI

struct SceneBuilderView: View {
    @EnvironmentObject var state: AppState
    let project: Project

    var body: some View {
        HSplitView {
            sceneList
                .frame(minWidth: 240, maxWidth: 300)
            shotDetail
        }
        .onAppear {
            Task { await state.loadScenes(for: project) }
        }
    }

    // MARK: - Scene list

    private var sceneList: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Scenes")
                    .font(.headline)
                Spacer()
                if state.isGenerating {
                    ProgressView().controlSize(.small)
                } else {
                    Button {
                        Task { await state.generateScenes(for: project) }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .buttonStyle(.plain)
                    .help("Regenerate scenes from script")
                    .disabled(state.currentVersions.isEmpty)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)

            Divider()

            if state.scenes.isEmpty {
                emptyScenes
            } else {
                List(state.scenes, id: \.id, selection: Binding(
                    get: { state.selectedScene?.id },
                    set: { id in
                        if let scene = state.scenes.first(where: { $0.id == id }) {
                            Task { await state.loadShots(for: scene, in: project) }
                        }
                    }
                )) { scene in
                    SceneRow(scene: scene, isSelected: state.selectedScene?.id == scene.id)
                }
                .listStyle(.sidebar)
            }
        }
        .background(Color(NSColor.windowBackgroundColor))
    }

    // MARK: - Shot detail

    private var shotDetail: some View {
        VStack(spacing: 0) {
            if let scene = state.selectedScene {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Scene \(scene.sceneNumber): \(scene.title ?? "")")
                            .font(.headline)
                        if let loc = scene.location {
                            Text(loc).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                    Text("\(state.shots.count) shots")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)

                Divider()

                if state.shots.isEmpty {
                    emptyShots
                } else {
                    ScrollView {
                        LazyVStack(spacing: 8) {
                            ForEach(state.shots) { shot in
                                ShotCard(shot: shot) {
                                    state.selectedShot = shot
                                    state.currentScreen = .storyboard(project, shot)
                                }
                            }
                        }
                        .padding(14)
                    }
                }
            } else {
                VStack {
                    Spacer()
                    Text("Select a scene to view its shots")
                        .foregroundStyle(.secondary)
                    Spacer()
                }
            }
        }
    }

    private var emptyScenes: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "film.stack")
                .font(.system(size: 36))
                .foregroundStyle(.secondary)
            Text("No scenes yet")
                .font(.callout.bold())
            Text("Generate a script first, then use \"Generate Scenes\" to break it into scenes and shots.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            Spacer()
        }
    }

    private var emptyShots: some View {
        VStack(spacing: 12) {
            Spacer()
            Text("No shots in this scene")
                .foregroundStyle(.secondary)
            Spacer()
        }
    }
}

// MARK: - Scene Row

struct SceneRow: View {
    let scene: Scene
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 10) {
            Text("\(scene.sceneNumber)")
                .font(.caption2.bold())
                .frame(width: 22, height: 22)
                .background(isSelected ? Color.accentColor : Color.secondary.opacity(0.2))
                .foregroundStyle(isSelected ? .white : .primary)
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(scene.title ?? "Scene \(scene.sceneNumber)")
                    .font(.callout)
                    .lineLimit(1)
                if let loc = scene.location {
                    Text(loc).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                }
            }
            Spacer()
            statusDot(scene.status)
        }
        .padding(.vertical, 2)
    }

    private func statusDot(_ status: String) -> some View {
        Circle()
            .fill(status == "approved" ? Color.green : Color.orange)
            .frame(width: 7, height: 7)
    }
}

// MARK: - Shot Card

struct ShotCard: View {
    let shot: Shot
    let onGenerateStoryboard: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Shot \(shot.shotNumber)")
                    .font(.subheadline.bold())
                Spacer()
                Text(DurationPreset(rawValue: shot.durationPreset)?.displayName ?? "\(shot.durationSeconds)s")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                approvalBadge(shot.approvalStatus)
            }

            if let desc = shot.description {
                Text(desc)
                    .font(.callout)
                    .foregroundStyle(.primary)
                    .lineLimit(3)
            }

            HStack(spacing: 12) {
                if let cam = shot.cameraMovement {
                    iconLabel("camera", cam)
                }
                if let light = shot.lighting {
                    iconLabel("light.overhead.left", light)
                }
                if let mood = shot.mood {
                    iconLabel("heart.text.square", mood)
                }
            }

            if let chars = shot.characters, !chars.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "person.2").font(.caption).foregroundStyle(.secondary)
                    Text(chars.joined(separator: ", ")).font(.caption).foregroundStyle(.secondary)
                }
            }

            Divider()

            Button {
                onGenerateStoryboard()
            } label: {
                Label("Generate Storyboard", systemImage: "photo.stack")
                    .font(.caption.bold())
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding(12)
        .background(Color(NSColor.controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func iconLabel(_ icon: String, _ text: String) -> some View {
        HStack(spacing: 3) {
            Image(systemName: icon).font(.caption2).foregroundStyle(.secondary)
            Text(text).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
        }
    }

    private func approvalBadge(_ status: String) -> some View {
        let (label, color): (String, Color) = switch status {
        case "approved": ("Approved", .green)
        case "rejected": ("Rejected", .red)
        default: ("Pending", .orange)
        }
        return Text(label)
            .font(.caption2.bold())
            .padding(.horizontal, 5).padding(.vertical, 2)
            .background(color.opacity(0.15))
            .foregroundStyle(color)
            .clipShape(Capsule())
    }
}
