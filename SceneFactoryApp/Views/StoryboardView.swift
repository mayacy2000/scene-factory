import SwiftUI

struct StoryboardView: View {
    @EnvironmentObject var state: AppState
    let project: Project
    let shot: Shot

    @State private var generateCount = 3
    @State private var selectedStyle = ""
    @State private var selectedCamera = ""
    @State private var selectedLighting = ""
    @State private var feedbackText = ""
    @State private var showFeedback = false

    private let styles = ["Cinematic", "Documentary", "Oil Painting", "Anime", "Photorealistic", "Dark Moody", "Bright Airy"]
    private let cameraAngles = ["Eye level", "Low angle", "High angle", "Bird's eye", "Dutch angle", "Close-up", "Wide shot", "Two-shot"]
    private let lightings = ["Natural daylight", "Golden hour", "Night", "Dramatic shadows", "Studio", "Neon", "Candlelight"]

    var body: some View {
        HSplitView {
            controlPanel
                .frame(minWidth: 240, maxWidth: 300)
            storyboardGrid
        }
        .onAppear {
            Task { await state.loadStoryboards(for: shot) }
        }
        .navigationTitle("Shot \(shot.shotNumber) — Storyboard")
    }

    // MARK: - Control panel

    private var controlPanel: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                sectionHeader("Shot Info")
                VStack(alignment: .leading, spacing: 8) {
                    if let desc = shot.description {
                        Text(desc).font(.callout).foregroundStyle(.secondary)
                    }
                    HStack {
                        Image(systemName: "timer")
                        Text(DurationPreset(rawValue: shot.durationPreset)?.displayName ?? "\(shot.durationSeconds)s")
                    }
                    .font(.caption).foregroundStyle(.secondary)
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 14)

                Divider()
                sectionHeader("Generate Options")

                VStack(alignment: .leading, spacing: 10) {
                    Stepper("Count: \(generateCount)", value: $generateCount, in: 1...6)
                        .font(.callout)

                    LabeledField("Style") {
                        Picker("Style", selection: $selectedStyle) {
                            Text("Auto").tag("")
                            ForEach(styles, id: \.self) { Text($0).tag($0.lowercased()) }
                        }
                        .labelsHidden()
                    }
                    LabeledField("Camera Angle") {
                        Picker("Camera", selection: $selectedCamera) {
                            Text("Auto").tag("")
                            ForEach(cameraAngles, id: \.self) { Text($0).tag($0.lowercased()) }
                        }
                        .labelsHidden()
                    }
                    LabeledField("Lighting") {
                        Picker("Lighting", selection: $selectedLighting) {
                            Text("Auto").tag("")
                            ForEach(lightings, id: \.self) { Text($0).tag($0.lowercased()) }
                        }
                        .labelsHidden()
                    }
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 14)

                Button {
                    Task {
                        let req = StoryboardGenerateRequest(
                            count: generateCount,
                            style: selectedStyle.isEmpty ? nil : selectedStyle,
                            cameraAngle: selectedCamera.isEmpty ? nil : selectedCamera,
                            lighting: selectedLighting.isEmpty ? nil : selectedLighting
                        )
                        _ = try? await APIService.shared.generateStoryboards(shotId: shot.id, request: req)
                        await state.loadStoryboards(for: shot)
                    }
                } label: {
                    Label("Generate Storyboards", systemImage: "photo.stack")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(state.isGenerating)
                .padding(.horizontal, 14)

                if state.isGenerating {
                    HStack(spacing: 6) {
                        ProgressView().controlSize(.small)
                        Text(state.generationStatus.isEmpty ? "Generating…" : state.generationStatus)
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 14)
                    .padding(.top, 8)
                }

                Divider().padding(.top, 14)
                sectionHeader("Prompt")

                if let prompt = shot.prompt, !prompt.isEmpty {
                    Text(prompt)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                        .padding(.horizontal, 14)
                        .padding(.bottom, 14)
                } else {
                    Text("No prompt — will be auto-generated via Ollama")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .padding(.horizontal, 14)
                        .padding(.bottom, 14)
                }
            }
        }
        .background(Color(NSColor.windowBackgroundColor))
    }

    // MARK: - Storyboard grid

    private var storyboardGrid: some View {
        VStack(spacing: 0) {
            HStack {
                Text("\(state.storyboards.count) storyboard\(state.storyboards.count == 1 ? "" : "s")")
                    .font(.headline)
                Spacer()
                if state.storyboards.contains(where: { $0.approvalStatus == "approved" }) {
                    Label("Storyboard approved", systemImage: "checkmark.seal.fill")
                        .font(.caption)
                        .foregroundStyle(.green)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)

            Divider()

            if state.storyboards.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVGrid(
                        columns: [GridItem(.adaptive(minimum: 260, maximum: 340), spacing: 16)],
                        spacing: 16
                    ) {
                        ForEach(state.storyboards) { sb in
                            StoryboardCard(
                                storyboard: sb,
                                shot: shot,
                                onApprove: {
                                    Task { await state.approveStoryboard(sb, shot: shot) }
                                },
                                onReject: {
                                    Task { try? await APIService.shared.rejectStoryboard(shotId: shot.id, storyboardId: sb.id)
                                        await state.loadStoryboards(for: shot) }
                                }
                            )
                        }
                    }
                    .padding(16)
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "photo.stack")
                .font(.system(size: 56))
                .foregroundStyle(.secondary)
            Text("No storyboards yet")
                .font(.title3.bold())
            Text("Configure options and tap \"Generate Storyboards\" to create visual options for this shot.")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 360)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.caption.bold())
            .foregroundStyle(.secondary)
            .padding(.horizontal, 14)
            .padding(.top, 14)
            .padding(.bottom, 6)
    }
}

// MARK: - Storyboard Card

struct StoryboardCard: View {
    let storyboard: StoryboardVersion
    let shot: Shot
    let onApprove: () -> Void
    let onReject: () -> Void

    @State private var image: NSImage?
    @State private var loadingImage = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            imageArea
                .frame(height: 180)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous).path(in: CGRect(x: 0, y: 0, width: 300, height: 180)))

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("v\(storyboard.versionNumber)")
                        .font(.caption.bold())
                    Spacer()
                    approvalBadge
                }

                if let prompt = storyboard.promptUsed {
                    Text(prompt)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                }

                HStack(spacing: 6) {
                    if let seed = storyboard.seed {
                        Label("Seed: \(seed)", systemImage: "number")
                            .font(.caption2).foregroundStyle(.tertiary)
                    }
                    if let res = storyboard.resolution {
                        Label(res, systemImage: "aspectratio")
                            .font(.caption2).foregroundStyle(.tertiary)
                    }
                }

                if storyboard.approvalStatus == "pending" {
                    HStack(spacing: 8) {
                        Button(action: onApprove) {
                            Label("Approve", systemImage: "checkmark")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)

                        Button(action: onReject) {
                            Label("Reject", systemImage: "xmark")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }
            }
            .padding(10)
        }
        .background(Color(NSColor.controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(approvalColor.opacity(0.5), lineWidth: storyboard.approvalStatus != "pending" ? 2 : 0)
        )
        .onAppear { loadImageIfNeeded() }
    }

    @ViewBuilder
    private var imageArea: some View {
        if let img = image {
            Image(nsImage: img)
                .resizable()
                .scaledToFill()
        } else if loadingImage {
            ZStack {
                Color(NSColor.controlBackgroundColor)
                ProgressView()
            }
        } else if storyboard.imagePath?.hasPrefix("pending:") == true {
            ZStack {
                Color(NSColor.controlBackgroundColor)
                VStack(spacing: 8) {
                    ProgressView()
                    Text("Generating…").font(.caption).foregroundStyle(.secondary)
                }
            }
        } else {
            ZStack {
                Color(NSColor.controlBackgroundColor)
                Image(systemName: "photo")
                    .font(.system(size: 40))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var approvalBadge: some View {
        let (label, color): (String, Color) = switch storyboard.approvalStatus {
        case "approved": ("Approved", .green)
        case "rejected": ("Rejected", .red)
        default: ("Pending review", .orange)
        }
        return Text(label)
            .font(.caption2.bold())
            .padding(.horizontal, 6).padding(.vertical, 2)
            .background(color.opacity(0.15))
            .foregroundStyle(color)
            .clipShape(Capsule())
    }

    private var approvalColor: Color {
        switch storyboard.approvalStatus {
        case "approved": return .green
        case "rejected": return .red
        default: return .clear
        }
    }

    private func loadImageIfNeeded() {
        guard image == nil,
              let imgPath = storyboard.imagePath,
              !imgPath.hasPrefix("pending:")
        else { return }

        let urlStr = APIService.shared.baseURL + "/shots/\(shot.id)/storyboards/\(storyboard.id)/image"
        guard let url = URL(string: urlStr) else { return }

        loadingImage = true
        Task {
            if let (data, _) = try? await URLSession.shared.data(from: url),
               let img = NSImage(data: data) {
                await MainActor.run {
                    self.image = img
                    self.loadingImage = false
                }
            } else {
                await MainActor.run { self.loadingImage = false }
            }
        }
    }
}
