import Foundation

// MARK: - IntentModelContainer

/// Shared helper for accessing session data in App Intents.
/// Uses the JSON-based StorageService — no SwiftData.
enum IntentModelContainer {

    /// Fetches all sessions using the shared StorageService.
    static func fetchAllSessions() async throws -> [CountSession] {
        try await StorageService.shared.fetchAllSessions()
    }

    /// Fetches a single session by ID.
    static func fetchSession(id: UUID) async throws -> CountSession? {
        let all = try await StorageService.shared.fetchAllSessions()
        return all.first { $0.id == id }
    }

    /// Saves a session.
    static func save(_ session: CountSession) async throws {
        try await StorageService.shared.save(session)
    }
}
