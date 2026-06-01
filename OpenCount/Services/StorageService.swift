import Foundation
import SwiftData

// MARK: - Protocol

/// Defines the persistence interface for counting sessions.
protocol StorageServiceProtocol {
    func save(_ session: CountSession) async throws
    func delete(_ session: CountSession) async throws
    func fetchAllSessions() async throws -> [CountSession]
    func fetchSessions(matching query: String) async throws -> [CountSession]
}

// MARK: - Implementation

/// Thin wrapper around SwiftData's `ModelContext` that implements `StorageServiceProtocol`.
/// All operations are performed on the `ModelContext` provided at initialisation time.
/// The caller is responsible for ensuring the context is used on the correct actor.
final class StorageService: StorageServiceProtocol {

    private let context: ModelContext

    /// - Parameter context: The `ModelContext` to use for all persistence operations.
    init(context: ModelContext) {
        self.context = context
    }

    // MARK: - StorageServiceProtocol

    /// Inserts the session into the context (if not already tracked) and saves.
    func save(_ session: CountSession) async throws {
        // SwiftData tracks objects automatically once inserted; calling insert on an
        // already-tracked object is a no-op, so this is safe to call unconditionally.
        context.insert(session)
        do {
            try context.save()
        } catch {
            throw AppError.swiftDataSaveFailure
        }
    }

    /// Deletes the session from the context and saves.
    /// The cascade delete rules on `CountSession` ensure all related objects are removed.
    func delete(_ session: CountSession) async throws {
        context.delete(session)
        do {
            try context.save()
        } catch {
            throw AppError.swiftDataSaveFailure
        }
    }

    /// Returns all sessions sorted by `modifiedAt` descending (most recently modified first).
    /// Requirement 1.5: Sessions sorted by most-recently-modified date descending.
    func fetchAllSessions() async throws -> [CountSession] {
        let descriptor = FetchDescriptor<CountSession>(
            sortBy: [SortDescriptor(\.modifiedAt, order: .reverse)]
        )
        do {
            return try context.fetch(descriptor)
        } catch {
            throw AppError.swiftDataSaveFailure
        }
    }

    /// Returns sessions whose name contains `query` (case-insensitive), sorted by `modifiedAt` descending.
    /// Requirement 1.6: Filter and display matching sessions within 300 ms.
    func fetchSessions(matching query: String) async throws -> [CountSession] {
        guard !query.isEmpty else {
            return try await fetchAllSessions()
        }
        // SwiftData #Predicate supports localizedStandardContains for case-insensitive search.
        let descriptor = FetchDescriptor<CountSession>(
            predicate: #Predicate { session in
                session.name.localizedStandardContains(query)
            },
            sortBy: [SortDescriptor(\.modifiedAt, order: .reverse)]
        )
        do {
            return try context.fetch(descriptor)
        } catch {
            throw AppError.swiftDataSaveFailure
        }
    }
}
