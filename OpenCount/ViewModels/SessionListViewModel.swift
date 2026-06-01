import Foundation
import Combine
import SwiftData
import AppIntents

// MARK: - SessionListViewModel

/// Manages the list of counting sessions, search filtering, and session CRUD operations.
///
/// - `sessions` always reflects the full list sorted by `modifiedAt` descending.
/// - `filteredSessions` is updated within 300 ms of any change to `searchQuery`
///   via a Combine debounce pipeline (Requirement 1.6).
@MainActor
final class SessionListViewModel: ObservableObject {

    // MARK: Published state

    /// Full list of sessions, sorted by `modifiedAt` descending.
    @Published var sessions: [CountSession] = []

    /// The current search query entered by the user.
    @Published var searchQuery: String = ""

    /// The filtered subset of `sessions` matching `searchQuery`.
    /// When `searchQuery` is empty this equals `sessions`.
    @Published var filteredSessions: [CountSession] = []

    // MARK: Private

    let storage: StorageServiceProtocol
    private var cancellables = Set<AnyCancellable>()

    // MARK: Init

    /// - Parameter storage: The persistence service to use. Defaults to a `StorageService`
    ///   backed by the shared SwiftData `ModelContext` injected via the environment.
    init(storage: StorageServiceProtocol) {
        self.storage = storage
        setupSearchDebounce()
    }

    // MARK: - Combine debounce pipeline

    /// Wires `searchQuery` → debounce(300 ms) → `filteredSessions`.
    /// Requirement 1.6: filter and display matching sessions within 300 milliseconds.
    private func setupSearchDebounce() {
        $searchQuery
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .removeDuplicates()
            .sink { [weak self] query in
                self?.applyFilter(query: query)
            }
            .store(in: &cancellables)
    }

    /// Filters `sessions` by `query` and writes the result to `filteredSessions`.
    /// Filtering is performed in-memory against the already-loaded `sessions` array
    /// so it is O(n) and well within the 300 ms budget for 1,000+ sessions (Requirement 1.7).
    ///
    /// - Note: Also exposed as `applyFilterForTesting` so unit/property tests can
    ///   trigger filtering synchronously without waiting for the 300 ms debounce.
    func applyFilterForTesting(query: String) {
        applyFilter(query: query)
    }

    private func applyFilter(query: String) {
        if query.isEmpty {
            filteredSessions = sessions
        } else {
            // Use `localizedStandardContains` for Unicode-aware matching.
            // This correctly handles Vietnamese diacritics, CJK characters, and
            // other locale-specific collation rules (Requirement 30.7).
            filteredSessions = sessions.filter {
                $0.name.localizedStandardContains(query)
            }
        }
    }

    // MARK: - Public search entry point

    /// Manually triggers a search with the given query.
    /// Normally the debounce pipeline handles this automatically via `searchQuery`;
    /// this method is provided for programmatic use (e.g., from tests).
    func search(query: String) {
        searchQuery = query
    }

    // MARK: - Load

    /// Loads all sessions from storage and refreshes `sessions` and `filteredSessions`.
    func loadSessions() async {
        do {
            sessions = try await storage.fetchAllSessions()
            applyFilter(query: searchQuery)
        } catch {
            // Non-fatal: leave existing sessions in place.
        }
    }

    // MARK: - CRUD

    /// Creates a new session with the given name, optional description, and object types.
    @discardableResult
    func createSession(
        name: String,
        description: String?,
        objectTypeNames: [String] = []
    ) async throws -> CountSession {
        let session = CountSession(
            name: name,
            sessionDescription: description
        )

        // Create default object types from provided names
        let colors = ["#FF5733", "#3498DB", "#2ECC71", "#F39C12", "#9B59B6",
                      "#1ABC9C", "#E74C3C", "#34495E", "#F1C40F", "#E67E22"]
        let icons = ["circle.fill", "star.fill", "heart.fill", "leaf.fill",
                     "bolt.fill", "flame.fill", "drop.fill", "moon.fill",
                     "sun.max.fill", "cloud.fill"]

        for (index, typeName) in objectTypeNames.enumerated() {
            let objectType = ObjectType(
                name: typeName,
                colorHex: colors[index % colors.count],
                iconName: icons[index % icons.count],
                sortOrder: index,
                session: session
            )
            session.objectTypes.append(objectType)
        }

        // If no object types provided, add a default one
        if objectTypeNames.isEmpty {
            let defaultType = ObjectType(
                name: "Object",
                colorHex: "#FF5733",
                iconName: "circle.fill",
                sortOrder: 0,
                session: session
            )
            session.objectTypes.append(defaultType)
        }

        try await storage.save(session)
        await loadSessions()

        // Donate Siri shortcut for session creation — Requirement 23.1
        IntentDonationService.donateSessionCreated(
            sessionID: session.id.uuidString,
            sessionName: session.name
        )

        return session
    }

    /// Deletes the given session from storage and refreshes the session list.
    /// The confirmation dialog is handled by the View layer (Requirement 1.4).
    func deleteSession(_ session: CountSession) async throws {
        try await storage.delete(session)
        await loadSessions()
    }

    /// Duplicates the given session: creates a new session with the same `ObjectType`s
    /// (new instances with the same name/color/icon) and settings, but with no markers,
    /// and appends "(Copy)" to the name (Requirement 1.8).
    @discardableResult
    func duplicateSession(_ session: CountSession) async throws -> CountSession {
        let copyName = "\(session.name) (Copy)"

        // Build new ObjectType instances mirroring the originals (no markers copied).
        let copiedObjectTypes: [ObjectType] = session.objectTypes
            .sorted { $0.sortOrder < $1.sortOrder }
            .map { original in
                ObjectType(
                    name: original.name,
                    colorHex: original.colorHex,
                    iconName: original.iconName,
                    sortOrder: original.sortOrder
                )
            }

        let duplicate = CountSession(
            name: copyName,
            sessionDescription: session.sessionDescription,
            objectTypes: copiedObjectTypes
            // images, regions, markers, videoTimestamps intentionally omitted (Requirement 1.8)
        )

        // Link each copied ObjectType back to the new session.
        for objectType in copiedObjectTypes {
            objectType.session = duplicate
        }

        try await storage.save(duplicate)
        await loadSessions()
        return duplicate
    }
}
