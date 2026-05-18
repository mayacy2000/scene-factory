import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var state: AppState
    @State private var settings: [AppSetting] = []
    @State private var systemStatus: SystemStatus?

    private func binding(for key: String, default defaultVal: String = "") -> Binding<String> {
        Binding(
            get: { settings.first(where: { $0.key == key })?.value ?? defaultVal },
            set: { newVal in
                Task { _ = try? await APIService.shared.updateSetting(key: key, value: newVal) }
                if let idx = settings.firstIndex(where: { $0.key == key }) {
                    settings[idx] = AppSetting(
                        id: settings[idx].id, key: key, value: newVal,
                        valueType: settings[idx].valueType, updatedAt: Date()
                    )
                }
            }
        )
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                systemStatusSection
                ollamaSection
                comfyuiSection
                privacySection
                interfaceSection
                budgetSection
            }
            .padding(24)
        }
        .onAppear {
            Task {
                settings = (try? await APIService.shared.getSettings()) ?? []
                systemStatus = try? await APIService.shared.systemStatus()
            }
        }
    }

    // MARK: - Sections

    private var systemStatusSection: some View {
        SettingsSection(title: "System Status") {
            VStack(spacing: 10) {
                if let s = systemStatus {
                    ServiceRow(service: s.ollama)
                    ServiceRow(service: s.comfyui)
                } else {
                    HStack {
                        ProgressView().controlSize(.small)
                        Text("Checking services…").font(.callout).foregroundStyle(.secondary)
                    }
                }
                Button("Refresh Status") {
                    Task { systemStatus = try? await APIService.shared.systemStatus() }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
    }

    private var ollamaSection: some View {
        SettingsSection(title: "Ollama (Local LLM)") {
            VStack(spacing: 12) {
                LabeledField("Ollama URL") {
                    TextField("http://localhost:11434", text: binding(for: "ollama_base_url"))
                        .textFieldStyle(.roundedBorder)
                }
                LabeledField("Model") {
                    TextField("llama3.2", text: binding(for: "ollama_model"))
                        .textFieldStyle(.roundedBorder)
                }
                Text("Ollama handles script generation, scene breakdown, story bible, and storyboard prompt generation. Install from ollama.com")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var comfyuiSection: some View {
        SettingsSection(title: "ComfyUI (Image Generation)") {
            VStack(spacing: 12) {
                LabeledField("ComfyUI URL") {
                    TextField("http://localhost:8188", text: binding(for: "comfyui_base_url"))
                        .textFieldStyle(.roundedBorder)
                }
                LabeledField("Default Resolution") {
                    Picker("Resolution", selection: binding(for: "default_resolution", default: "768x512")) {
                        Text("512×512").tag("512x512")
                        Text("768×512 (Recommended)").tag("768x512")
                        Text("1024×576").tag("1024x576")
                        Text("1920×1080").tag("1920x1080")
                    }
                    .labelsHidden()
                }
                Text("ComfyUI generates storyboard images. It must be running with at least one checkpoint model loaded.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var privacySection: some View {
        SettingsSection(title: "Privacy & Cloud") {
            VStack(spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Local-only mode")
                            .font(.callout)
                        Text("Disable all cloud uploads and rendering")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Toggle("", isOn: Binding(
                        get: { binding(for: "local_only_mode", default: "true").wrappedValue == "true" },
                        set: { binding(for: "local_only_mode").wrappedValue = $0 ? "true" : "false" }
                    ))
                    .toggleStyle(.switch)
                    .labelsHidden()
                }

                LabeledField("Cloud Upload Approval") {
                    Picker("Approval", selection: binding(for: "cloud_upload_approval", default: "always_ask")) {
                        Text("Always ask before uploading").tag("always_ask")
                        Text("Ask only for new projects").tag("ask_new")
                        Text("Ask only for sensitive projects").tag("ask_sensitive")
                        Text("Don't ask, but show activity").tag("never_ask")
                    }
                    .labelsHidden()
                }
            }
        }
    }

    private var interfaceSection: some View {
        SettingsSection(title: "Interface") {
            VStack(spacing: 12) {
                LabeledField("Default Mode") {
                    Picker("Mode", selection: binding(for: "user_mode", default: "beginner")) {
                        Text("Beginner — simplified workflow").tag("beginner")
                        Text("Advanced — full controls exposed").tag("advanced")
                    }
                    .labelsHidden()
                }
                LabeledField("Default Language") {
                    Picker("Language", selection: binding(for: "default_language", default: "english")) {
                        Text("English").tag("english")
                        Text("Arabic").tag("arabic")
                        Text("Bilingual").tag("bilingual")
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                }
                LabeledField("Default Storyboard Count") {
                    Picker("Count", selection: Binding(
                        get: { Int(binding(for: "default_storyboard_count", default: "3").wrappedValue) ?? 3 },
                        set: { binding(for: "default_storyboard_count").wrappedValue = "\($0)" }
                    )) {
                        ForEach([1, 2, 3, 4, 5, 6], id: \.self) { Text("\($0)").tag($0) }
                    }
                    .labelsHidden()
                }
            }
        }
    }

    private var budgetSection: some View {
        SettingsSection(title: "Cloud Budget Controls") {
            VStack(spacing: 12) {
                LabeledField("Per-job spending limit ($)") {
                    TextField("10.00", text: binding(for: "per_job_spend_limit", default: "10.00"))
                        .textFieldStyle(.roundedBorder)
                }
                LabeledField("Monthly spending limit ($)") {
                    TextField("50.00", text: binding(for: "monthly_spend_limit", default: "50.00"))
                        .textFieldStyle(.roundedBorder)
                }
                Text("These limits apply to cloud rendering (RunPod). Local rendering is always free.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Settings Section

struct SettingsSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
            content
                .padding(16)
                .background(Color(NSColor.controlBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }
}

struct ServiceRow: View {
    let service: ServiceStatus

    var body: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(service.available ? Color.green : Color.red)
                .frame(width: 9, height: 9)
            Text(service.name)
                .font(.callout.bold())
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(service.available ? "Running" : "Offline")
                    .font(.caption.bold())
                    .foregroundStyle(service.available ? .green : .red)
                if let detail = service.details {
                    Text(detail)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
        .padding(.vertical, 4)
    }
}
