import Foundation

// MARK: - StorageServiceProtocol

protocol StorageServiceProtocol {
    func save(_ session: CountSession) async throws
    func delete(_ session: CountSession) async throws
    func fetchAllSessions() async throws -> [CountSession]
    func fetchSessions(matching query: String) async throws -> [CountSession]
}

// MARK: - StorageService (JSON file-based, iOS 16+)

/// Persists sessions as individual JSON files in Documents/sessions/.
/// Each session is stored as <uuid>.json — no SwiftData, no CoreData.
final class StorageService: StorageServiceProtocol {

    // MARK: - Singleton for convenience
    static let shared = StorageService()

    // MARK: - Directory
    private var sessionsDir: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dir = docs.appendingPathComponent("sessions", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private func fileURL(for session: CountSession) -> URL {
        sessionsDir.appendingPathComponent("\(session.id.uuidString).json")
    }

    private var encoder: JSONEncoder {
        let e = JSONEncoder()
        e.outputFormatting = [.sortedKeys]
        e.dateEncodingStrategy = .iso8601
        return e
    }

    private var decoder: JSONDecoder {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }

    // MARK: - StorageServiceProtocol

    func save(_ session: CountSession) async throws {
        let data = try encoder.encode(session)
        try data.write(to: fileURL(for: session), options: .atomic)
    }

    func delete(_ session: CountSession) async throws {
        let url = fileURL(for: session)
        if FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }
        // Also remove session images directory
        let imagesDir = FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("images/\(session.id.uuidString)")
        try? FileManager.default.removeItem(at: imagesDir)
    }

    func fetchAllSessions() async throws -> [CountSession] {
        let files = (try? FileManager.default.contentsOfDirectory(
            at: sessionsDir, includingPropertiesForKeys: nil)) ?? []
        var sessions: [CountSession] = []
        for file in files where file.pathExtension == "json" {
            if let data = try? Data(contentsOf: file),
               let session = try? decoder.decode(CountSession.self, from: data) {
                sessions.append(session)
            }
        }
        return sessions.sorted { $0.modifiedAt > $1.modifiedAt }
    }

    func fetchSessions(matching query: String) async throws -> [CountSession] {
        let all = try await fetchAllSessions()
        guard !query.isEmpty else { return all }
        return all.filter { $0.name.localizedStandardContains(query) }
    }
}

// MARK: - TagStorageService

/// Persists SessionTags as a single JSON file in Documents/tags.json
final class TagStorageService {
    static let shared = TagStorageService()

    private var tagsURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("tags.json")
    }

    private var encoder: JSONEncoder {
        let e = JSONEncoder(); e.dateEncodingStrategy = .iso8601; return e
    }
    private var decoder: JSONDecoder {
        let d = JSONDecoder(); d.dateDecodingStrategy = .iso8601; return d
    }

    func loadAll() -> [SessionTag] {
        guard let data = try? Data(contentsOf: tagsURL),
              let tags = try? decoder.decode([SessionTag].self, from: data) else { return [] }
        return tags
    }

    func saveAll(_ tags: [SessionTag]) {
        if let data = try? encoder.encode(tags) {
            try? data.write(to: tagsURL, options: .atomic)
        }
    }

    /// Returns tag IDs assigned to a session (stored in UserDefaults)
    func assignedTagIDs(for sessionID: UUID) -> [UUID] {
        let key = "session_tags_\(sessionID.uuidString)"
        guard let data = UserDefaults.standard.data(forKey: key),
              let ids = try? JSONDecoder().decode([UUID].self, from: data) else { return [] }
        return ids
    }

    func setAssignedTagIDs(_ ids: [UUID], for sessionID: UUID) {
        let key = "session_tags_\(sessionID.uuidString)"
        if let data = try? JSONEncoder().encode(ids) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    func assignedTags(for sessionID: UUID) -> [SessionTag] {
        let ids = Set(assignedTagIDs(for: sessionID))
        return loadAll().filter { ids.contains($0.id) }
    }
}
