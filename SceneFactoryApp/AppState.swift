import Foundation
import SwiftUI

@MainActor
final class AppState: ObservableObject {

    // MARK: - Navigation

    enum Screen {
        case dashboard
        case newProject
        case project(Project)
        case scriptStudio(Project, Story?)
        case sceneBuilder(Project)
        case assetLibrary(Project)
        case storyboard(Project, Shot)
        case settings
    }

    @Published var currentScreen: Screen = .dashboard
    @Published var selectedProject: Project?
    @Published var sidebarItem: String = "script"

    // MARK: - Projects

    @Published var projects: [Project] = []
    @Published var isLoadingProjects = false

    // MARK: - Story

    @Published var currentStory: Story?
    @Published var currentVersions: [StoryVersion] = []
    @Published var selectedVersion: StoryVersion?

    // MARK: - Scenes

    @Published var scenes: [Scene] = []
    @Published var selectedScene: Scene?
    @Published var shots: [Shot] = []
    @Published var selectedShot: Shot?

    // MARK: - Assets

    @Published var assets: [Asset] = []

    // MARK: - Storyboards

    @Published var storyboards: [StoryboardVersion] = []

    // MARK: - Generation state

    @Published var isGenerating = false
    @Published var generationStatus = ""

    // MARK: - System

    @Published var systemStatus: SystemStatus?
    @Published var backendReachable = false

    // MARK: - User preferences

    @Published var userMode: String = "beginner"
    @Published var localOnlyMode: Bool = true

    // MARK: - Error

    @Published var errorMessage: String?
    @Published var showError = false

    private let api = APIService.shared

    // MARK: - Lifecycle

    func onLaunch() async {
        await checkBackend()
        await loadProjects()
    }

    func checkBackend() async {
        do {
            let status = try await api.systemStatus()
            systemStatus = status
            backendReachable = true
            localOnlyMode = status.localOnlyMode
        } catch {
            backendReachable = false
        }
    }

    // MARK: - Projects

    func loadProjects() async {
        isLoadingProjects = true
        defer { isLoadingProjects = false }
        do {
            projects = try await api.listProjects()
        } catch {
            showError(error.localizedDescription)
        }
    }

    func createProject(_ body: ProjectCreate) async -> Project? {
        do {
            let project = try await api.createProject(body)
            projects.insert(project, at: 0)
            return project
        } catch {
            showError(error.localizedDescription)
            return nil
        }
    }

    func deleteProject(_ project: Project) async {
        do {
            try await api.deleteProject(project.id)
            projects.removeAll { $0.id == project.id }
            if selectedProject?.id == project.id {
                selectedProject = nil
                currentScreen = .dashboard
            }
        } catch {
            showError(error.localizedDescription)
        }
    }

    func openProject(_ project: Project) async {
        selectedProject = project
        await loadStory(for: project)
        await loadScenes(for: project)
        await loadAssets(for: project)
        currentScreen = .project(project)
        sidebarItem = "script"
    }

    // MARK: - Story

    func loadStory(for project: Project) async {
        do {
            currentStory = try await api.getStory(projectId: project.id)
            currentVersions = currentStory?.versions ?? []
            selectedVersion = currentVersions.last
        } catch {
            showError(error.localizedDescription)
        }
    }

    func savePrompt(_ prompt: String, for project: Project) async {
        do {
            let story = try await api.createStory(projectId: project.id, prompt: prompt)
            currentStory = story
            currentVersions = story.versions
        } catch {
            showError(error.localizedDescription)
        }
    }

    func generateScript(for project: Project, language: String = "english") async {
        isGenerating = true
        generationStatus = "Generating cinematic script…"
        defer {
            isGenerating = false
            generationStatus = ""
        }
        do {
            let version = try await api.generateScript(projectId: project.id, language: language)
            currentVersions.append(version)
            selectedVersion = version
        } catch {
            showError(error.localizedDescription)
        }
    }

    func generateScenes(for project: Project) async {
        isGenerating = true
        generationStatus = "Breaking story into scenes and shots…"
        defer {
            isGenerating = false
            generationStatus = ""
        }
        do {
            _ = try await api.generateScenes(projectId: project.id)
            await loadScenes(for: project)
        } catch {
            showError(error.localizedDescription)
        }
    }

    func generateBible(for project: Project) async {
        isGenerating = true
        generationStatus = "Creating story bible…"
        defer {
            isGenerating = false
            generationStatus = ""
        }
        do {
            _ = try await api.generateBible(projectId: project.id)
        } catch {
            showError(error.localizedDescription)
        }
    }

    // MARK: - Scenes

    func loadScenes(for project: Project) async {
        do {
            scenes = try await api.listScenes(projectId: project.id)
        } catch {
            showError(error.localizedDescription)
        }
    }

    func loadShots(for scene: Scene, in project: Project) async {
        do {
            selectedScene = scene
            shots = try await api.listShots(projectId: project.id, sceneId: scene.id)
        } catch {
            showError(error.localizedDescription)
        }
    }

    // MARK: - Assets

    func loadAssets(for project: Project, type: String? = nil) async {
        do {
            assets = try await api.listAssets(projectId: project.id, type: type)
        } catch {
            showError(error.localizedDescription)
        }
    }

    func uploadAsset(projectId: String, fileURL: URL, assetType: String, name: String?) async {
        do {
            let asset = try await api.uploadAsset(projectId: projectId, fileURL: fileURL, assetType: assetType, name: name)
            assets.insert(asset, at: 0)
        } catch {
            showError(error.localizedDescription)
        }
    }

    func deleteAsset(_ asset: Asset, projectId: String) async {
        do {
            try await api.deleteAsset(projectId: projectId, assetId: asset.id)
            assets.removeAll { $0.id == asset.id }
        } catch {
            showError(error.localizedDescription)
        }
    }

    // MARK: - Storyboards

    func loadStoryboards(for shot: Shot) async {
        do {
            storyboards = try await api.listStoryboards(shotId: shot.id)
        } catch {
            showError(error.localizedDescription)
        }
    }

    func generateStoryboards(for shot: Shot, count: Int = 3) async {
        isGenerating = true
        generationStatus = "Generating storyboard options…"
        defer {
            isGenerating = false
            generationStatus = ""
        }
        do {
            let req = StoryboardGenerateRequest(count: count)
            let new = try await api.generateStoryboards(shotId: shot.id, request: req)
            storyboards.append(contentsOf: new)
        } catch {
            showError(error.localizedDescription)
        }
    }

    func approveStoryboard(_ sb: StoryboardVersion, shot: Shot) async {
        do {
            try await api.approveStoryboard(shotId: shot.id, storyboardId: sb.id)
            storyboards = storyboards.map { s in
                var copy = s
                copy = StoryboardVersion(
                    id: s.id, shotId: s.shotId, versionNumber: s.versionNumber,
                    imagePath: s.imagePath, promptUsed: s.promptUsed, seed: s.seed,
                    style: s.style, cameraAngle: s.cameraAngle, lighting: s.lighting,
                    modelUsed: s.modelUsed, resolution: s.resolution,
                    approvalStatus: s.id == sb.id ? "approved" : "rejected",
                    createdAt: s.createdAt
                )
                return copy
            }
        } catch {
            showError(error.localizedDescription)
        }
    }

    // MARK: - Error

    func showError(_ message: String) {
        errorMessage = message
        showError = true
    }
}
