import Foundation
import WatchConnectivity
import Combine

// MARK: - WatchConnectivityService (iOS side)
// Requirements: 22.1, 22.2, 22.5

/// Bridges the iOS app and watchOS companion via WatchConnectivity.
/// Sends session updates to the Watch and receives count increments from the Watch.
final class WatchConnectivityService: NSObject, ObservableObject {

    // MARK: - Published State

    /// Whether the paired Watch is currently reachable.
    @Published var isWatchReachable: Bool = false

    /// Number of count increments received from Watch that are pending persistence.
    @Published var pendingSyncCount: Int = 0

    // MARK: - Private

    private var session: WCSession?

    /// Closure called when the Watch sends a count increment.
    /// Parameters: objectTypeID, sessionID
    /// The closure is called on the main actor so callers can safely mutate UI state.
    @MainActor var onCountIncrement: ((UUID, UUID) -> Void)?

    // MARK: - Singleton

    static let shared = WatchConnectivityService()

    // MARK: - Init

    override init() {
        super.init()
        guard WCSession.isSupported() else { return }
        let wcSession = WCSession.default
        wcSession.delegate = self
        wcSession.activate()
        self.session = wcSession
    }

    // MARK: - Public API

    /// Sends the active session's object types and tallies to the Watch.
    /// Requirement 22.1
    func sendSessionUpdate(_ countSession: CountSession) {
        guard let wcSession = session,
              wcSession.activationState == .activated else { return }

        let objectTypes = countSession.objectTypes.sorted { $0.sortOrder < $1.sortOrder }
        let watchTypes = objectTypes.map { ot -> [String: Any] in
            let tally = countSession.markers.filter { $0.objectType.id == ot.id }.count
            return [
                "id": ot.id.uuidString,
                "name": ot.name,
                "colorHex": ot.colorHex,
                "iconName": ot.iconName,
                "sortOrder": ot.sortOrder,
                "tally": tally
            ]
        }

        let payload: [String: Any] = [
            "sessionID": countSession.id.uuidString,
            "sessionName": countSession.name,
            "objectTypes": watchTypes
        ]

        if wcSession.isReachable {
            // Send immediately when Watch is reachable
            wcSession.sendMessage(payload, replyHandler: nil) { error in
                // Fall back to application context on failure
                try? wcSession.updateApplicationContext(payload)
            }
        } else {
            // Queue via application context for delivery when Watch reconnects
            try? wcSession.updateApplicationContext(payload)
        }
    }

    /// Handles a count increment message received from the Watch.
    /// Requirement 22.2, 22.5
    func receiveCountIncrement(objectTypeID: UUID, sessionID: UUID) {
        Task { @MainActor in
            pendingSyncCount += 1
            onCountIncrement?(objectTypeID, sessionID)
            pendingSyncCount = max(0, pendingSyncCount - 1)
        }
    }

    /// Flushes any pending increments that were queued while Watch was unreachable.
    /// Requirement 22.5
    func flushPendingIncrements() {
        // Pending increments are stored on the Watch side in UserDefaults.
        // When the Watch reconnects, it sends them via sendMessage; this method
        // is a hook for any iOS-side queuing if needed in the future.
        Task { @MainActor in
            pendingSyncCount = 0
        }
    }
}

// MARK: - WCSessionDelegate

extension WatchConnectivityService: WCSessionDelegate {

    func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        DispatchQueue.main.async {
            self.isWatchReachable = (activationState == .activated) && session.isReachable
        }
    }

    func sessionReachabilityDidChange(_ session: WCSession) {
        DispatchQueue.main.async {
            self.isWatchReachable = session.isReachable
        }
        if session.isReachable {
            flushPendingIncrements()
        }
    }

    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        handleIncomingMessage(message)
    }

    func session(
        _ session: WCSession,
        didReceiveMessage message: [String: Any],
        replyHandler: @escaping ([String: Any]) -> Void
    ) {
        handleIncomingMessage(message)
        replyHandler(["status": "ok"])
    }

    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        // Handle pending increments delivered via application context
        if let increments = applicationContext["pendingIncrements"] as? [[String: String]] {
            for entry in increments {
                guard
                    let objectTypeIDString = entry["objectTypeID"],
                    let sessionIDString = entry["sessionID"],
                    let objectTypeID = UUID(uuidString: objectTypeIDString),
                    let sessionID = UUID(uuidString: sessionIDString)
                else { continue }
                receiveCountIncrement(objectTypeID: objectTypeID, sessionID: sessionID)
            }
        }
    }

    // Required on iOS (not needed on watchOS)
    func sessionDidBecomeInactive(_ session: WCSession) {}
    func sessionDidDeactivate(_ session: WCSession) {
        // Re-activate after deactivation (e.g., user switches Apple Watch)
        session.activate()
    }

    // MARK: - Private Helpers

    private func handleIncomingMessage(_ message: [String: Any]) {
        guard
            let objectTypeIDString = message["objectTypeID"] as? String,
            let sessionIDString = message["sessionID"] as? String,
            let objectTypeID = UUID(uuidString: objectTypeIDString),
            let sessionID = UUID(uuidString: sessionIDString)
        else { return }

        receiveCountIncrement(objectTypeID: objectTypeID, sessionID: sessionID)
    }
}
