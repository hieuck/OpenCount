import Foundation
import Combine
import AppIntents

@MainActor
final class SessionListViewModel: ObservableObject {

    @Published var sessions: [CountSession] = []
    @Published var searchQuery: String = ""
    @Published var filteredSessions: [CountSession] = []

    let storage: StorageServiceProtocol
    private var cancellables = Set<AnyCancellable>()

    init(storage: StorageServiceProtocol) {
        self.storage = storage
        setupSearchDebounce()
    }

    private func setupSearchDebounce() {
        $searchQuery
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .removeDuplicates()
            .sink { [weak self] query in self?.applyFilter(query: query) }
            .store(in: &cancellables)
    }

    func applyFilterForTesting(query: String) { applyFilter(query: query) }

    private func applyFilter(query: String) {
        filteredSessions = query.isEmpty ? sessions
            : sessions.filter { $0.name.localizedStandardContains(query) }
    }

    func search(query: String) { searchQuery = query }

    func loadSessions() async {
        sessions = (try? await storage.fetchAllSessions()) ?? []
        applyFilter(query: searchQuery)
    }

    @discardableResult
    func createSession(name: String, description: String?,
                       objectTypeNames: [String] = []) async throws -> CountSession {
        let session = CountSession(name: name, sessionDescription: description)
        let colors = ["#FF5733","#3498DB","#2ECC71","#F39C12","#9B59B6",
                      "#1ABC9C","#E74C3C","#34495E","#F1C40F","#E67E22"]
        let icons  = ["circle.fill","star.fill","heart.fill","leaf.fill",
                      "bolt.fill","flame.fill","drop.fill","moon.fill",
                      "sun.max.fill","cloud.fill"]
        for (i, typeName) in objectTypeNames.enumerated() {
            let ot = ObjectType(name: typeName, colorHex: colors[i % colors.count],
                                iconName: icons[i % icons.count], sortOrder: i, session: session)
            session.objectTypes.append(ot)
        }
        if objectTypeNames.isEmpty {
            session.objectTypes.append(
                ObjectType(name: "Object", colorHex: "#FF5733",
                           iconName: "circle.fill", sortOrder: 0, session: session))
        }
        try await storage.save(session)
        await loadSessions()
        IntentDonationService.donateSessionCreated(sessionID: session.id.uuidString,
                                                   sessionName: session.name)
        return session
    }

    func deleteSession(_ session: CountSession) async throws {
        try await storage.delete(session)
        await loadSessions()
    }

    @discardableResult
    func duplicateSession(_ session: CountSession) async throws -> CountSession {
        let copy = CountSession(name: "\(session.name) (Copy)",
                                sessionDescription: session.sessionDescription)
        for ot in session.objectTypes.sorted(by: { $0.sortOrder < $1.sortOrder }) {
            let newOT = ObjectType(name: ot.name, colorHex: ot.colorHex,
                                   iconName: ot.iconName, sortOrder: ot.sortOrder,
                                   session: copy, targetCount: ot.targetCount)
            copy.objectTypes.append(newOT)
        }
        try await storage.save(copy)
        await loadSessions()
        return copy
    }
}
