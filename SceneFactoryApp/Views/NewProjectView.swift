import SwiftUI

struct NewProjectView: View {
    @EnvironmentObject var state: AppState
    @Environment(\.dismiss) var dismiss

    var onCreate: (Project) -> Void

    @State private var title = ""
    @State private var description = ""
    @State private var genre = ""
    @State private var tone = ""
    @State private var language = "english"
    @State private var userMode = "beginner"
    @State private var localOnly = true
    @State private var isCreating = false

    private let languages = ["english", "arabic", "bilingual"]
    private let genres = ["Drama", "Thriller", "Romance", "Adventure", "Mystery", "Sci-Fi", "Historical", "Documentary", "Other"]
    private let tones = ["Cinematic", "Dark", "Hopeful", "Tense", "Poetic", "Epic", "Intimate", "Mysterious"]

    var canCreate: Bool { !title.trimmingCharacters(in: .whitespaces).isEmpty && !isCreating }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            ScrollView {
                form
                    .padding(28)
            }
            Divider()
            footer
        }
        .frame(width: 560, height: 620)
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("New Project")
                    .font(.title2.bold())
                Text("Set up your video production project")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button { dismiss() } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(20)
    }

    private var form: some View {
        VStack(alignment: .leading, spacing: 20) {

            FormSection(title: "Project Details") {
                VStack(spacing: 12) {
                    LabeledField("Title *") {
                        TextField("e.g. The Ancient Manuscript", text: $title)
                            .textFieldStyle(.roundedBorder)
                    }
                    LabeledField("Description") {
                        TextEditor(text: $description)
                            .frame(height: 72)
                            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color(NSColor.separatorColor)))
                            .font(.body)
                    }
                }
            }

            FormSection(title: "Story Style") {
                VStack(spacing: 12) {
                    LabeledField("Genre") {
                        Picker("Genre", selection: $genre) {
                            Text("Select genre…").tag("")
                            ForEach(genres, id: \.self) { Text($0).tag($0.lowercased()) }
                        }
                        .labelsHidden()
                    }
                    LabeledField("Tone") {
                        Picker("Tone", selection: $tone) {
                            Text("Select tone…").tag("")
                            ForEach(tones, id: \.self) { Text($0).tag($0.lowercased()) }
                        }
                        .labelsHidden()
                    }
                    LabeledField("Language") {
                        Picker("Language", selection: $language) {
                            Text("English").tag("english")
                            Text("Arabic").tag("arabic")
                            Text("Bilingual").tag("bilingual")
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()
                    }
                }
            }

            FormSection(title: "Interface & Privacy") {
                VStack(spacing: 12) {
                    LabeledField("Interface Mode") {
                        Picker("Mode", selection: $userMode) {
                            Text("Beginner — clean, simplified interface").tag("beginner")
                            Text("Advanced — full model, prompt, and seed controls").tag("advanced")
                        }
                        .labelsHidden()
                    }
                    Toggle(isOn: $localOnly) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Local-only mode")
                                .font(.callout)
                            Text("No cloud uploads. All AI runs on this Mac.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .toggleStyle(.switch)
                }
            }
        }
    }

    private var footer: some View {
        HStack {
            Button("Cancel") { dismiss() }
                .keyboardShortcut(.escape)
            Spacer()
            Button {
                Task { await create() }
            } label: {
                if isCreating {
                    HStack(spacing: 6) {
                        ProgressView().controlSize(.small)
                        Text("Creating…")
                    }
                } else {
                    Text("Create Project")
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(!canCreate)
            .keyboardShortcut(.return, modifiers: .command)
        }
        .padding(20)
    }

    private func create() async {
        guard canCreate else { return }
        isCreating = true
        defer { isCreating = false }

        let body = ProjectCreate(
            title: title.trimmingCharacters(in: .whitespaces),
            description: description.isEmpty ? nil : description,
            genre: genre.isEmpty ? nil : genre,
            tone: tone.isEmpty ? nil : tone,
            userMode: userMode,
            localOnly: localOnly,
            language: language
        )

        if let project = await state.createProject(body) {
            onCreate(project)
            dismiss()
        }
    }
}

// MARK: - Form helpers

struct FormSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.subheadline.bold())
                .foregroundStyle(.secondary)
            content
        }
    }
}

struct LabeledField<Content: View>: View {
    let label: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            content
        }
    }
}
