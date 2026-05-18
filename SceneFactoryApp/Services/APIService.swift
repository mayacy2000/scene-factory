import Foundation

enum APIError: LocalizedError {
    case invalidURL
    case networkError(Error)
    case httpError(Int, String)
    case decodingError(Error)
    case noData

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid URL"
        case .networkError(let e): return "Network error: \(e.localizedDescription)"
        case .httpError(let code, let msg): return "HTTP \(code): \(msg)"
        case .decodingError(let e): return "Decode error: \(e.localizedDescription)"
        case .noData: return "No data received"
        }
    }
}

final class APIService: ObservableObject {
    static let shared = APIService()

    var baseURL: String = "http://localhost:8000/api"

    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let str = try container.decode(String.self)
            let fmts = [
                "yyyy-MM-dd'T'HH:mm:ss.SSSSSS",
                "yyyy-MM-dd'T'HH:mm:ss",
                "yyyy-MM-dd'T'HH:mm:ssZ",
            ]
            let fmt = DateFormatter()
            fmt.locale = Locale(identifier: "en_US_POSIX")
            for f in fmts {
                fmt.dateFormat = f
                if let date = fmt.date(from: str) { return date }
            }
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Cannot decode date: \(str)")
        }
        return d
    }()

    private let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        return e
    }()

    // MARK: - Generic request

    private func request<T: Decodable>(
        method: String,
        path: String,
        body: (any Encodable)? = nil
    ) async throws -> T {
        guard let url = URL(string: baseURL + path) else { throw APIError.invalidURL }
        var req = URLRequest(url: url)
        req.httpMethod = method
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let body {
            req.httpBody = try encoder.encode(body)
        }
        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse else { throw APIError.noData }
        guard (200..<300).contains(http.statusCode) else {
            let msg = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw APIError.httpError(http.statusCode, msg)
        }
        return try decoder.decode(T.self, from: data)
    }

    private func requestVoid(method: String, path: String, body: (any Encodable)? = nil) async throws {
        guard let url = URL(string: baseURL + path) else { throw APIError.invalidURL }
        var req = URLRequest(url: url)
        req.httpMethod = method
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let body { req.httpBody = try encoder.encode(body) }
        let (_, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse else { throw APIError.noData }
        guard (200..<300).contains(http.statusCode) else {
            throw APIError.httpError(http.statusCode, "Request failed")
        }
    }

    // MARK: - Projects

    func listProjects() async throws -> [Project] {
        try await request(method: "GET", path: "/projects")
    }

    func createProject(_ body: ProjectCreate) async throws -> Project {
        try await request(method: "POST", path: "/projects", body: body)
    }

    func getProject(_ id: String) async throws -> Project {
        try await request(method: "GET", path: "/projects/\(id)")
    }

    func deleteProject(_ id: String) async throws {
        try await requestVoid(method: "DELETE", path: "/projects/\(id)")
    }

    // MARK: - Stories

    func getStory(projectId: String) async throws -> Story? {
        do {
            return try await request(method: "GET", path: "/projects/\(projectId)/story")
        } catch APIError.httpError(404, _) {
            return nil
        }
    }

    func createStory(projectId: String, prompt: String) async throws -> Story {
        struct Body: Encodable { let prompt: String }
        return try await request(method: "POST", path: "/projects/\(projectId)/story", body: Body(prompt: prompt))
    }

    func generateScript(projectId: String, language: String = "english") async throws -> StoryVersion {
        struct Body: Encodable { let language: String }
        return try await request(method: "POST", path: "/projects/\(projectId)/story/generate-script", body: Body(language: language))
    }

    func generateScenes(projectId: String) async throws -> [String: Any] {
        guard let url = URL(string: baseURL + "/projects/\(projectId)/story/generate-scenes") else {
            throw APIError.invalidURL
        }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        let (data, _) = try await URLSession.shared.data(for: req)
        return (try? JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
    }

    func generateBible(projectId: String) async throws -> StoryBible {
        try await request(method: "POST", path: "/projects/\(projectId)/story/generate-bible")
    }

    func listVersions(projectId: String) async throws -> [StoryVersion] {
        try await request(method: "GET", path: "/projects/\(projectId)/story/versions")
    }

    func approveVersion(projectId: String, versionId: String) async throws {
        try await requestVoid(method: "POST", path: "/projects/\(projectId)/story/approve?version_id=\(versionId)")
    }

    // MARK: - Scenes & Shots

    func listScenes(projectId: String) async throws -> [Scene] {
        try await request(method: "GET", path: "/projects/\(projectId)/scenes")
    }

    func listShots(projectId: String, sceneId: String) async throws -> [Shot] {
        try await request(method: "GET", path: "/projects/\(projectId)/scenes/\(sceneId)/shots")
    }

    // MARK: - Assets

    func listAssets(projectId: String, type: String? = nil) async throws -> [Asset] {
        var path = "/projects/\(projectId)/assets"
        if let t = type { path += "?asset_type=\(t)" }
        return try await request(method: "GET", path: path)
    }

    func uploadAsset(
        projectId: String,
        fileURL: URL,
        assetType: String,
        name: String?
    ) async throws -> Asset {
        guard let url = URL(string: baseURL + "/projects/\(projectId)/assets") else {
            throw APIError.invalidURL
        }
        let boundary = UUID().uuidString
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        let fileData = try Data(contentsOf: fileURL)
        let mimeType = mimeType(for: fileURL)
        var body = Data()

        func append(_ string: String) { body.append(string.data(using: .utf8)!) }
        func field(_ name: String, _ value: String) {
            append("--\(boundary)\r\n")
            append("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n")
            append("\(value)\r\n")
        }

        field("asset_type", assetType)
        if let n = name { field("name", n) }

        append("--\(boundary)\r\n")
        append("Content-Disposition: form-data; name=\"file\"; filename=\"\(fileURL.lastPathComponent)\"\r\n")
        append("Content-Type: \(mimeType)\r\n\r\n")
        body.append(fileData)
        append("\r\n--\(boundary)--\r\n")

        req.httpBody = body
        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw APIError.httpError(0, "Upload failed")
        }
        return try decoder.decode(Asset.self, from: data)
    }

    func deleteAsset(projectId: String, assetId: String) async throws {
        try await requestVoid(method: "DELETE", path: "/projects/\(projectId)/assets/\(assetId)")
    }

    func assetFileURL(projectId: String, assetId: String) -> URL? {
        URL(string: baseURL + "/projects/\(projectId)/assets/\(assetId)/file")
    }

    // MARK: - Storyboards

    func listStoryboards(shotId: String) async throws -> [StoryboardVersion] {
        try await request(method: "GET", path: "/shots/\(shotId)/storyboards")
    }

    func generateStoryboards(shotId: String, request body: StoryboardGenerateRequest) async throws -> [StoryboardVersion] {
        try await request(method: "POST", path: "/shots/\(shotId)/storyboards/generate", body: body)
    }

    func approveStoryboard(shotId: String, storyboardId: String) async throws {
        try await requestVoid(method: "POST", path: "/shots/\(shotId)/storyboards/\(storyboardId)/approve")
    }

    func rejectStoryboard(shotId: String, storyboardId: String) async throws {
        try await requestVoid(method: "POST", path: "/shots/\(shotId)/storyboards/\(storyboardId)/reject")
    }

    func storyboardImageURL(shotId: String, storyboardId: String) -> URL? {
        URL(string: baseURL + "/shots/\(shotId)/storyboards/\(storyboardId)/image")
    }

    // MARK: - Settings & System

    func getSettings() async throws -> [AppSetting] {
        try await request(method: "GET", path: "/settings")
    }

    func updateSetting(key: String, value: String, valueType: String = "string") async throws -> AppSetting {
        struct Body: Encodable { let key, value, value_type: String }
        return try await request(method: "PUT", path: "/settings", body: Body(key: key, value: value, value_type: valueType))
    }

    func systemStatus() async throws -> SystemStatus {
        try await request(method: "GET", path: "/system/status")
    }

    // MARK: - Helpers

    private func mimeType(for url: URL) -> String {
        let ext = url.pathExtension.lowercased()
        let map = [
            "jpg": "image/jpeg", "jpeg": "image/jpeg",
            "png": "image/png", "webp": "image/webp",
            "mp3": "audio/mpeg", "wav": "audio/wav",
            "mp4": "video/mp4", "mov": "video/quicktime",
        ]
        return map[ext] ?? "application/octet-stream"
    }
}
