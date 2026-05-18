import SwiftUI

struct ScriptStudioView: View {
    @EnvironmentObject var state: AppState
    let project: Project

    @State private var promptText = ""
    @State private var selectedLanguage = "english"
    @State private var showVersionHistory = false
    @State private var editingPrompt = false

    var currentScript: String {
        state.selectedVersion?.scriptContent ?? ""
    }

    var body: some View {
        HSplitView {
            leftPanel
                .frame(minWidth: 280, maxWidth: 360)
            rightPanel
        }
        .onAppear {
            promptText = state.currentStory?.prompt ?? ""
            selectedLanguage = project.language
        }
    }

    // MARK: - Left panel: prompt + controls

    private var leftPanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionHeader("Story Prompt")

            VStack(alignment: .leading, spacing: 12) {
                TextEditor(text: $promptText)
                    .font(.body)
                    .frame(minHeight: 120, maxHeight: 200)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color(NSColor.separatorColor))
                    )
                    .disabled(!editingPrompt && state.currentStory != nil)

                if state.currentStory == nil || editingPrompt {
                    Button("Save Prompt") {
                        Task {
                            await state.savePrompt(promptText, for: project)
                            editingPrompt = false
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(promptText.trimmingCharacters(in: .whitespaces).isEmpty)
                } else {
                    Button("Edit Prompt") { editingPrompt = true }
                        .buttonStyle(.bordered)
                }
            }
            .padding(14)

            Divider()
            sectionHeader("Language")

            Picker("Language", selection: $selectedLanguage) {
                Text("English").tag("english")
                Text("Arabic").tag("arabic")
                Text("Bilingual").tag("bilingual")
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .padding(.horizontal, 14)
            .padding(.vertical, 10)

            Divider()
            sectionHeader("Generate")

            VStack(spacing: 8) {
                GenerateButton(
                    label: "Generate Script",
                    icon: "doc.text",
                    description: "Create full cinematic script using Ollama",
                    isLoading: state.isGenerating,
                    disabled: state.currentStory == nil || state.isGenerating
                ) {
                    Task { await state.generateScript(for: project, language: selectedLanguage) }
                }

                GenerateButton(
                    label: "Generate Scenes & Shots",
                    icon: "film.stack",
                    description: "Break script into scenes and shot list",
                    isLoading: state.isGenerating,
                    disabled: state.selectedVersion?.scriptContent == nil || state.isGenerating
                ) {
                    Task { await state.generateScenes(for: project) }
                }

                GenerateButton(
                    label: "Generate Story Bible",
                    icon: "book.closed",
                    description: "Create continuity reference document",
                    isLoading: state.isGenerating,
                    disabled: state.selectedVersion?.scriptContent == nil || state.isGenerating
                ) {
                    Task { await state.generateBible(for: project) }
                }
            }
            .padding(14)

            if state.isGenerating {
                Divider()
                HStack(spacing: 8) {
                    ProgressView().controlSize(.small)
                    Text(state.generationStatus)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(14)
            }

            Spacer()

            if !state.currentVersions.isEmpty {
                Divider()
                versionPicker
            }
        }
        .background(Color(NSColor.windowBackgroundColor))
    }

    // MARK: - Right panel: script display

    private var rightPanel: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Script")
                    .font(.headline)
                Spacer()
                if let version = state.selectedVersion {
                    Text("Version \(version.versionNumber)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    approvalBadge(version.approvalStatus)
                    if version.approvalStatus == "draft" {
                        Button("Approve") {
                            Task { await state.approveVersion(projectId: project.id, versionId: version.id) }
                        }
                        .controlSize(.small)
                        .buttonStyle(.borderedProminent)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)

            Divider()

            if currentScript.isEmpty {
                scriptPlaceholder
            } else {
                ScrollView {
                    Text(currentScript)
                        .font(.system(.body, design: .monospaced))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(20)
                }
            }
        }
    }

    private var scriptPlaceholder: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "doc.text.below.ecg")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("No script yet")
                .font(.title3.bold())
            Text("Enter a story prompt and tap \"Generate Script\" to create your cinematic script.")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 340)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private var versionPicker: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Versions")
                .font(.caption.bold())
                .foregroundStyle(.secondary)
                .padding(.horizontal, 14)
                .padding(.top, 10)

            ForEach(state.currentVersions.reversed()) { version in
                HStack {
                    Image(systemName: "doc.text")
                        .foregroundStyle(.secondary)
                        .font(.caption)
                    Text("v\(version.versionNumber)")
                        .font(.caption)
                    Spacer()
                    approvalBadge(version.approvalStatus)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 5)
                .background(state.selectedVersion?.id == version.id ? Color.accentColor.opacity(0.1) : .clear)
                .contentShape(Rectangle())
                .onTapGesture { state.selectedVersion = version }
            }
            .padding(.bottom, 10)
        }
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.caption.bold())
            .foregroundStyle(.secondary)
            .padding(.horizontal, 14)
            .padding(.top, 14)
            .padding(.bottom, 6)
    }

    private func approvalBadge(_ status: String) -> some View {
        let (label, color): (String, Color) = switch status {
        case "approved": ("Approved", .green)
        case "rejected": ("Rejected", .red)
        default: ("Draft", .orange)
        }
        return Text(label)
            .font(.caption2.bold())
            .padding(.horizontal, 6).padding(.vertical, 2)
            .background(color.opacity(0.15))
            .foregroundStyle(color)
            .clipShape(Capsule())
    }
}

// MARK: - AppState helpers called from view

extension AppState {
    func approveVersion(projectId: String, versionId: String) async {
        do {
            try await APIService.shared.approveVersion(projectId: projectId, versionId: versionId)
            if let idx = currentVersions.firstIndex(where: { $0.id == versionId }) {
                currentVersions[idx] = StoryVersion(
                    id: currentVersions[idx].id,
                    storyId: currentVersions[idx].storyId,
                    versionNumber: currentVersions[idx].versionNumber,
                    scriptContent: currentVersions[idx].scriptContent,
                    sceneOutline: currentVersions[idx].sceneOutline,
                    visualStyleRecommendation: currentVersions[idx].visualStyleRecommendation,
                    approvalStatus: "approved",
                    createdAt: currentVersions[idx].createdAt
                )
                if selectedVersion?.id == versionId {
                    selectedVersion = currentVersions[idx]
                }
            }
        } catch {
            showError(error.localizedDescription)
        }
    }
}

// MARK: - Generate Button

struct GenerateButton: View {
    let label: String
    let icon: String
    let description: String
    let isLoading: Bool
    let disabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .frame(width: 18)
                VStack(alignment: .leading, spacing: 1) {
                    Text(label).font(.callout.bold())
                    Text(description).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                if isLoading {
                    ProgressView().controlSize(.mini)
                } else {
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(10)
            .background(Color(NSColor.controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .opacity(disabled ? 0.5 : 1)
    }
}
