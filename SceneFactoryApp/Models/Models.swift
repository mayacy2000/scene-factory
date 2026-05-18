import Foundation

// MARK: - Project

struct Project: Codable, Identifiable {
    let id: String
    var title: String
    var description: String?
    var genre: String?
    var tone: String?
    var visualStyle: String?
    var status: String
    var userMode: String
    var localOnly: Bool
    var folderPath: String?
    var language: String
    var createdAt: Date
    var updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id, title, description, genre, tone, status, language
        case visualStyle = "visual_style"
        case userMode = "user_mode"
        case localOnly = "local_only"
        case folderPath = "folder_path"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct ProjectCreate: Codable {
    var title: String
    var description: String?
    var genre: String?
    var tone: String?
    var visualStyle: String?
    var userMode: String = "beginner"
    var localOnly: Bool = true
    var language: String = "english"

    enum CodingKeys: String, CodingKey {
        case title, description, genre, tone, language
        case visualStyle = "visual_style"
        case userMode = "user_mode"
        case localOnly = "local_only"
    }
}

// MARK: - Story

struct Story: Codable, Identifiable {
    let id: String
    let projectId: String
    var prompt: String
    var createdAt: Date
    var versions: [StoryVersion]

    enum CodingKeys: String, CodingKey {
        case id, prompt, versions
        case projectId = "project_id"
        case createdAt = "created_at"
    }
}

struct StoryVersion: Codable, Identifiable {
    let id: String
    let storyId: String
    var versionNumber: Int
    var scriptContent: String?
    var sceneOutline: [SceneOutlineItem]?
    var visualStyleRecommendation: String?
    var approvalStatus: String
    var createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case storyId = "story_id"
        case versionNumber = "version_number"
        case scriptContent = "script_content"
        case sceneOutline = "scene_outline"
        case visualStyleRecommendation = "visual_style_recommendation"
        case approvalStatus = "approval_status"
        case createdAt = "created_at"
    }
}

struct SceneOutlineItem: Codable {
    var sceneNumber: Int
    var title: String
    var description: String

    enum CodingKeys: String, CodingKey {
        case title, description
        case sceneNumber = "scene_number"
    }
}

struct StoryBible: Codable, Identifiable {
    let id: String
    let projectId: String
    var title: String?
    var genre: String?
    var tone: String?
    var visualStyle: String?
    var narrativeSummary: String?
    var mainThemes: [String]?
    var voiceNarrationStyle: String?
    var continuityRules: [String]?
    var createdAt: Date
    var updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id, title, genre, tone
        case projectId = "project_id"
        case visualStyle = "visual_style"
        case narrativeSummary = "narrative_summary"
        case mainThemes = "main_themes"
        case voiceNarrationStyle = "voice_narration_style"
        case continuityRules = "continuity_rules"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

// MARK: - Scenes & Shots

struct Scene: Codable, Identifiable {
    let id: String
    let projectId: String
    var sceneNumber: Int
    var title: String?
    var description: String?
    var location: String?
    var mood: String?
    var timeOfDay: String?
    var status: String
    var createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id, title, description, location, mood, status
        case projectId = "project_id"
        case sceneNumber = "scene_number"
        case timeOfDay = "time_of_day"
        case createdAt = "created_at"
    }
}

struct Shot: Codable, Identifiable {
    let id: String
    let sceneId: String
    var shotNumber: Int
    var description: String?
    var durationPreset: String
    var durationSeconds: Double
    var cameraMovement: String?
    var lighting: String?
    var mood: String?
    var style: String?
    var characters: [String]?
    var objects: [String]?
    var audioCues: String?
    var location: String?
    var prompt: String?
    var negativePrompt: String?
    var approvalStatus: String
    var createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id, description, location, mood, style, characters, objects, prompt
        case sceneId = "scene_id"
        case shotNumber = "shot_number"
        case durationPreset = "duration_preset"
        case durationSeconds = "duration_seconds"
        case cameraMovement = "camera_movement"
        case lighting, audioCues
        case negativePrompt = "negative_prompt"
        case approvalStatus = "approval_status"
        case createdAt = "created_at"
    }
}

// MARK: - Assets

struct Asset: Codable, Identifiable {
    let id: String
    let projectId: String
    var assetType: String?
    var name: String?
    var description: String?
    var filePath: String?
    var fileName: String?
    var fileSize: Int?
    var mimeType: String?
    var qualityScore: Double?
    var lightingQuality: String?
    var imageClarify: String?
    var suitability: String?
    var suggestedFixes: String?
    var linkedEntityId: String?
    var linkedEntityType: String?
    var createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id, description, name, suitability
        case projectId = "project_id"
        case assetType = "asset_type"
        case filePath = "file_path"
        case fileName = "file_name"
        case fileSize = "file_size"
        case mimeType = "mime_type"
        case qualityScore = "quality_score"
        case lightingQuality = "lighting_quality"
        case imageClarify = "image_clarity"
        case suggestedFixes = "suggested_fixes"
        case linkedEntityId = "linked_entity_id"
        case linkedEntityType = "linked_entity_type"
        case createdAt = "created_at"
    }
}

// MARK: - Storyboards

struct StoryboardVersion: Codable, Identifiable {
    let id: String
    let shotId: String
    var versionNumber: Int
    var imagePath: String?
    var promptUsed: String?
    var seed: Int?
    var style: String?
    var cameraAngle: String?
    var lighting: String?
    var modelUsed: String?
    var resolution: String?
    var approvalStatus: String
    var createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id, seed, style, lighting, resolution
        case shotId = "shot_id"
        case versionNumber = "version_number"
        case imagePath = "image_path"
        case promptUsed = "prompt_used"
        case cameraAngle = "camera_angle"
        case modelUsed = "model_used"
        case approvalStatus = "approval_status"
        case createdAt = "created_at"
    }
}

struct StoryboardGenerateRequest: Codable {
    var count: Int = 3
    var style: String?
    var cameraAngle: String?
    var lighting: String?
    var seed: Int?
    var steps: Int = 20
    var cfgScale: Double = 7.0
    var resolution: String = "768x512"
    var model: String?

    enum CodingKeys: String, CodingKey {
        case count, style, seed, steps, model, resolution
        case cameraAngle = "camera_angle"
        case lighting
        case cfgScale = "cfg_scale"
    }
}

// MARK: - System Status

struct ServiceStatus: Codable {
    var name: String
    var available: Bool
    var url: String
    var details: String?
}

struct SystemStatus: Codable {
    var ollama: ServiceStatus
    var comfyui: ServiceStatus
    var localOnlyMode: Bool

    enum CodingKeys: String, CodingKey {
        case ollama, comfyui
        case localOnlyMode = "local_only_mode"
    }
}

// MARK: - Settings

struct AppSetting: Codable, Identifiable {
    let id: String
    var key: String
    var value: String?
    var valueType: String
    var updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id, key, value
        case valueType = "value_type"
        case updatedAt = "updated_at"
    }
}

// MARK: - Duration presets

enum DurationPreset: String, CaseIterable {
    case fastTrailer = "fast_trailer"
    case standardCinematic = "standard_cinematic"
    case slowDramatic = "slow_dramatic"
    case longAtmospheric = "long_atmospheric"

    var displayName: String {
        switch self {
        case .fastTrailer: return "Fast Trailer (2-3s)"
        case .standardCinematic: return "Standard Cinematic (3-5s)"
        case .slowDramatic: return "Slow Dramatic (5-8s)"
        case .longAtmospheric: return "Long Atmospheric (8-12s)"
        }
    }

    var seconds: Double {
        switch self {
        case .fastTrailer: return 2.5
        case .standardCinematic: return 4.0
        case .slowDramatic: return 6.5
        case .longAtmospheric: return 10.0
        }
    }
}
