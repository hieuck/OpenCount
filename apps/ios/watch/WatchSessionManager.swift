import Foundation
import WatchConnectivity
import WatchKit

// MARK: - WatchObjectType
// A lightweight, Codable representation of an ObjectType for use on watchOS.
// Uses plain structs (not SwiftData) since watchOS companion does not run SwiftData.
// Requirements: 22.1, 22.2

struct WatchObjectType: Codable, Identifiable {
    let id: UUID
    let name: String
    let colorHex: String
    let iconName: String
    let sortOrder: Int
}

// MARK: - PendingIncrement
// Represents a count increment queued while the iPhone is unreachable.
// Requirement 22.5

private struct PendingIncrement: Codable {
    let objectTypeID: String
    let sessionID: String
}

// MARK: - WatchSessionManager
// Watch-side session manager. Receives session data from iOS and sends
// count increments back. Queues increments in UserDefaults when offline.
// Requirements: 22.2, 22.3, 22.5

final class WatchSessionManager: NSObject, ObservableObject {

    // MARK: - Published State

    /// The object types for the active session, sorted by sortOrder.
    @Published var objectTypes: [WatchObjectType] = []

    /// Current tally per object type ID.
    @Published var tallies: [UUID: Int] = [:]

    /// The active session ID received from iOS.
    @Published var sessionID: UUID?

    /// The active session name received from iOS.
    @Published var sessionName: String = "OpenCount"

    /// Whether the iPhone is currently reachable.
    @Published var isPhoneReachable: Bool = false

    // MARK: - Private

    private let pendingIncrementsKey = "pendingIncrements"
    private var wcSession: WCSession?

    // MARK: - Init

    override init() {
        super.init()
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        session.delegate = self
        session.activate()
        wcSession = session
        loadPersistedState()
    }

    // MARK: - Public API

    /// Increments the tally for the given object type and sends the increment to iOS.
    /// Provides haptic feedback on each tap.
    /// Requirements: 22.2, 22.3
    func incrementTally(for objectTypeID: UUID) {
        // Update local tally immediately for responsive UI
        tallies[objectTypeID, default: 0] += 1

        // Haptic feedback
        WKInterfaceDevice.current().play(.click)

        // Persist updated tallies
        persistTallies()

        // Attempt to send to iPhone
        guard let sessionID = sessionID else { return }
        let message: [String: Any] = [
            "objectTypeID": objectTypeID.uuidString,
            "sessionID": sessionID.uuidString
        ]

        if let wcSession = wcSession, wcSession.isReachable {
            wcSession.sendMessage(message, replyHandler: nil) { [weak self] _ in
                // If send fails, queue the increment
                self?.queueIncrement(objectTypeID: objectTypeID, sessionID: sessionID)
            }
        } else {
            // iPhone not reachable — queue for later
            queueIncrement(objectTypeID: objectTypeID, sessionID: sessionID)
        }
    }

    // MARK: - Offline Queue (UserDefaults)
    // Requirement 22.5

    /// Queues a count increment in UserDefaults for later delivery.
    private func queueIncrement(objectTypeID: UUID, sessionID: UUID) {
        var pending = loadPendingIncrements()
        pending.append(PendingIncrement(
            objectTypeID: objectTypeID.uuidString,
            sessionID: sessionID.uuidString
        ))
        savePendingIncrements(pending)
    }

    /// Flushes all queued increments to the iPhone when it becomes reachable.
    private func flushPendingIncrements() {
        let pending = loadPendingIncrements()
        guard !pending.isEmpty, let wcSession = wcSession, wcSession.isReachable else { return }

        // Send all pending increments as a batch via application context
        let payload: [[String: String]] = pending.map {
            ["objectTypeID": $0.objectTypeID, "sessionID": $0.sessionID]
        }
        let context: [String: Any] = ["pendingIncrements": payload]

        do {
            try wcSession.updateApplicationContext(context)
            // Clear queue after successful delivery
            savePendingIncrements([])
        } catch {
            // Keep queue intact if delivery fails
        }
    }

    private func loadPendingIncrements() -> [PendingIncrement] {
        guard let data = UserDefaults.standard.data(forKey: pendingIncrementsKey),
              let decoded = try? JSONDecoder().decode([PendingIncrement].self, from: data)
        else { return [] }
        return decoded
    }

    private func savePendingIncrements(_ increments: [PendingIncrement]) {
        guard let data = try? JSONEncoder().encode(increments) else { return }
        UserDefaults.standard.set(data, forKey: pendingIncrementsKey)
    }

    // MARK: - State Persistence

    private func persistTallies() {
        let stringKeyed = Dictionary(uniqueKeysWithValues: tallies.map {
            ($0.key.uuidString, $0.value)
        })
        UserDefaults.standard.set(stringKeyed, forKey: "watchTallies")
        if let sid = sessionID {
            UserDefaults.standard.set(sid.uuidString, forKey: "watchSessionID")
        }
        // Persist object types so the Watch can display them after a restart
        // without needing to reconnect to the iPhone. Requirement 22.1.
        if let data = try? JSONEncoder().encode(objectTypes) {
            UserDefaults.standard.set(data, forKey: "watchObjectTypes")
        }
        UserDefaults.standard.set(sessionName, forKey: "watchSessionName")
    }

    private func loadPersistedState() {
        if let stringKeyed = UserDefaults.standard.dictionary(forKey: "watchTallies") as? [String: Int] {
            tallies = Dictionary(uniqueKeysWithValues: stringKeyed.compactMap { key, value in
                guard let uuid = UUID(uuidString: key) else { return nil }
                return (uuid, value)
            })
        }
        if let sidString = UserDefaults.standard.string(forKey: "watchSessionID"),
           let sid = UUID(uuidString: sidString) {
            sessionID = sid
        }
        // Restore object types from UserDefaults for offline display.
        if let data = UserDefaults.standard.data(forKey: "watchObjectTypes"),
           let decoded = try? JSONDecoder().decode([WatchObjectType].self, from: data) {
            objectTypes = decoded
        }
        sessionName = UserDefaults.standard.string(forKey: "watchSessionName") ?? "OpenCount"
    }

    // MARK: - Session Update Handling

    private func applySessionUpdate(_ payload: [String: Any]) {
        guard let sessionIDString = payload["sessionID"] as? String,
              let sid = UUID(uuidString: sessionIDString)
        else { return }

        sessionID = sid
        sessionName = payload["sessionName"] as? String ?? "OpenCount"

        if let rawTypes = payload["objectTypes"] as? [[String: Any]] {
            let decoded: [WatchObjectType] = rawTypes.compactMap { dict in
                guard
                    let idString = dict["id"] as? String,
                    let id = UUID(uuidString: idString),
                    let name = dict["name"] as? String,
                    let colorHex = dict["colorHex"] as? String,
                    let iconName = dict["iconName"] as? String,
                    let sortOrder = dict["sortOrder"] as? Int
                else { return nil }
                return WatchObjectType(
                    id: id,
                    name: name,
                    colorHex: colorHex,
                    iconName: iconName,
                    sortOrder: sortOrder
                )
            }
            .sorted { $0.sortOrder < $1.sortOrder }

            DispatchQueue.main.async {
                self.objectTypes = decoded
                // Seed tallies from iOS-provided values
                for dict in rawTypes {
                    if let idString = dict["id"] as? String,
                       let id = UUID(uuidString: idString),
                       let tally = dict["tally"] as? Int {
                        self.tallies[id] = tally
                    }
                }
                // Persist updated state so Watch can display it after restart
                self.persistTallies()
            }
        }
    }

    /// Total count across all object types (used by complication).
    var totalCount: Int {
        tallies.values.reduce(0, +)
    }
}

// MARK: - WCSessionDelegate

extension WatchSessionManager: WCSessionDelegate {

    func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        DispatchQueue.main.async {
            self.isPhoneReachable = (activationState == .activated) && session.isReachable
        }
        if activationState == .activated {
            flushPendingIncrements()
        }
    }

    func sessionReachabilityDidChange(_ session: WCSession) {
        DispatchQueue.main.async {
            self.isPhoneReachable = session.isReachable
        }
        if session.isReachable {
            flushPendingIncrements()
        }
    }

    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        DispatchQueue.main.async {
            self.applySessionUpdate(message)
        }
    }

    func session(
        _ session: WCSession,
        didReceiveMessage message: [String: Any],
        replyHandler: @escaping ([String: Any]) -> Void
    ) {
        DispatchQueue.main.async {
            self.applySessionUpdate(message)
        }
        replyHandler(["status": "ok"])
    }

    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        DispatchQueue.main.async {
            self.applySessionUpdate(applicationContext)
        }
    }
}
