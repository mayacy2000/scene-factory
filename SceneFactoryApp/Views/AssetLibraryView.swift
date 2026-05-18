import SwiftUI
import UniformTypeIdentifiers

struct AssetLibraryView: View {
    @EnvironmentObject var state: AppState
    let project: Project

    @State private var selectedType: String = "all"
    @State private var isDropTargeted = false
    @State private var showFilePicker = false

    private let assetTypes = [
        ("all", "All", "square.grid.2x2"),
        ("character", "Characters", "person.fill"),
        ("location", "Locations", "map.fill"),
        ("object", "Objects", "cube.fill"),
        ("style", "Style Refs", "paintbrush.fill"),
        ("audio", "Audio", "waveform"),
        ("voice", "Voice", "mic.fill"),
    ]

    var filteredAssets: [Asset] {
        if selectedType == "all" { return state.assets }
        return state.assets.filter { $0.assetType == selectedType }
    }

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            Divider()
            HStack(spacing: 0) {
                typeSidebar
                Divider()
                assetGrid
            }
        }
        .onAppear {
            Task { await state.loadAssets(for: project) }
        }
        .fileImporter(
            isPresented: $showFilePicker,
            allowedContentTypes: [.image, .audio, .movie, .pdf],
            allowsMultipleSelection: true
        ) { result in
            if case .success(let urls) = result {
                Task {
                    for url in urls {
                        await state.uploadAsset(
                            projectId: project.id,
                            fileURL: url,
                            assetType: selectedType == "all" ? "character" : selectedType,
                            name: url.deletingPathExtension().lastPathComponent
                        )
                    }
                }
            }
        }
    }

    private var toolbar: some View {
        HStack {
            Text("Asset Library")
                .font(.headline)
            Text("·")
                .foregroundStyle(.secondary)
            Text("\(state.assets.count) assets")
                .font(.callout)
                .foregroundStyle(.secondary)
            Spacer()
            Button {
                showFilePicker = true
            } label: {
                Label("Upload Assets", systemImage: "plus.circle")
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private var typeSidebar: some View {
        List(assetTypes, id: \.0, selection: Binding(
            get: { selectedType },
            set: { selectedType = $0 ?? "all" }
        )) { type in
            HStack {
                Image(systemName: type.2)
                    .frame(width: 16)
                    .foregroundStyle(selectedType == type.0 ? .accentColor : .secondary)
                Text(type.1)
                Spacer()
                let count = type.0 == "all" ? state.assets.count : state.assets.filter { $0.assetType == type.0 }.count
                if count > 0 {
                    Text("\(count)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .listStyle(.sidebar)
        .frame(width: 160)
    }

    private var assetGrid: some View {
        Group {
            if filteredAssets.isEmpty {
                dropZone
            } else {
                ScrollView {
                    LazyVGrid(
                        columns: [GridItem(.adaptive(minimum: 140, maximum: 180), spacing: 12)],
                        spacing: 12
                    ) {
                        ForEach(filteredAssets) { asset in
                            AssetThumbnail(asset: asset, project: project) {
                                Task { await state.deleteAsset(asset, projectId: project.id) }
                            }
                        }
                    }
                    .padding(16)
                }
            }
        }
        .onDrop(of: [.fileURL, .image], isTargeted: $isDropTargeted) { providers in
            handleDrop(providers)
        }
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.accentColor, lineWidth: isDropTargeted ? 2 : 0)
                .padding(8)
                .animation(.easeInOut(duration: 0.15), value: isDropTargeted)
        )
    }

    private var dropZone: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "arrow.down.doc")
                .font(.system(size: 48))
                .foregroundStyle(isDropTargeted ? .accentColor : .secondary)
            Text(isDropTargeted ? "Drop to upload" : "No assets yet")
                .font(.title3.bold())
                .foregroundStyle(isDropTargeted ? .accentColor : .primary)
            Text("Drag & drop images, audio files, or click \"Upload Assets\"")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 320)
            Button("Upload Assets") { showFilePicker = true }
                .buttonStyle(.bordered)
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .animation(.easeInOut(duration: 0.15), value: isDropTargeted)
    }

    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        for provider in providers {
            _ = provider.loadFileRepresentation(forTypeIdentifier: UTType.fileURL.identifier) { url, _ in
                guard let url else { return }
                let fileURL = url.standardizedFileURL
                Task {
                    await state.uploadAsset(
                        projectId: project.id,
                        fileURL: fileURL,
                        assetType: selectedType == "all" ? "character" : selectedType,
                        name: nil
                    )
                }
            }
        }
        return !providers.isEmpty
    }
}

// MARK: - Asset Thumbnail

struct AssetThumbnail: View {
    let asset: Asset
    let project: Project
    let onDelete: () -> Void

    @State private var image: NSImage?
    @State private var hovering = false

    var body: some View {
        VStack(spacing: 6) {
            ZStack(alignment: .topTrailing) {
                thumbnail
                    .frame(width: 140, height: 100)
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                if hovering {
                    Button(action: onDelete) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.red)
                            .background(Circle().fill(.white))
                    }
                    .buttonStyle(.plain)
                    .padding(4)
                }
            }

            VStack(spacing: 2) {
                Text(asset.name ?? asset.fileName ?? "Untitled")
                    .font(.caption.bold())
                    .lineLimit(1)
                Text(asset.assetType?.capitalized ?? "Asset")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .onHover { hovering = $0 }
        .onAppear { loadImage() }
    }

    private var thumbnail: some View {
        Group {
            if let img = image {
                Image(nsImage: img)
                    .resizable()
                    .scaledToFill()
            } else {
                ZStack {
                    Color(NSColor.controlBackgroundColor)
                    Image(systemName: typeIcon)
                        .font(.system(size: 28))
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var typeIcon: String {
        switch asset.assetType {
        case "character": return "person.fill"
        case "location": return "map.fill"
        case "object": return "cube.fill"
        case "style": return "paintbrush.fill"
        case "audio", "music", "narration": return "waveform"
        case "voice": return "mic.fill"
        default: return "doc"
        }
    }

    private func loadImage() {
        guard let urlStr = APIService.shared.baseURL
            .replacingOccurrences(of: "/api", with: "")
            .appending("/api/projects/\(project.id)/assets/\(asset.id)/file"),
              let url = URL(string: urlStr),
              let mime = asset.mimeType, mime.hasPrefix("image/")
        else { return }

        Task {
            if let (data, _) = try? await URLSession.shared.data(from: url),
               let img = NSImage(data: data) {
                await MainActor.run { self.image = img }
            }
        }
    }
}
