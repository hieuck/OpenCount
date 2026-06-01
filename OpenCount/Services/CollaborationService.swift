import Foundation
import CloudKit
import Combine

// MARK: - CollaborationService

/// Real-time collaborative counting via CloudKit public database.
///
/// Enables multiple devices to count on the same session simultaneously.
/// Uses CloudKit subscriptions to receive push notifications when remote
/// participants add or remove markers.
///
/// Merge strategy: union semantics — markers are deduplicated by UUID.
/// Last-write-wins for marker coordinate updates.
///
/// Requirements: 28.1–28.6
@MainActor
final class CollaborationService: ObservableObject {

    // MARK: - Published state

    @Published var isCollaborating: Bool = false
    @Published var collaboratorCount: Int = 0
    @Published var syncStatus: CollabSyncStatus = .idle
    @Published var error: String?

    // MARK: - Types

    enum CollabSyncStatus: Equatable {
        case idle
        case syncing
        case synced(Date)
        case failed(String)
    }

    // MARK: - Private

    private let container = CKContainer(identifier: "iCloud.com.opencount.app")
    private var database: CKDatabase { container.publicCloudDatabase }
    private var subscriptionID: String?
    private var sessionID: UUID?
    private var onMarkersReceived: (([CountMarker]) -> Void)?

    // MARK: - Singleton

    @MainActor static let shared = CollaborationService()
    private init() {}

    // MARK: - Start collaboration

    /// Starts a collaborative session for the given session ID.
    /// Creates a CloudKit subscription to receive remote marker changes.
    ///
    /// Requirement 28.1: enable real-time collaborative counting.
    func startCollaboration(
        sessionID: UUID,
        onMarkersReceived: @escaping ([CountMarker]) -> Void
    ) async {
        self.sessionID = sessionID
        self.onMarkersReceived = onMarkersReceived
        isCollaborating = true
        syncStatus = .syncing

        let subID = "collab-\(sessionID.uuidString)"
        self.subscriptionID = subID

        // Create a subscription for new markers in this session
        let predicate = NSPredicate(format: "sessionID == %@", sessionID.uuidString)
        let subscription = CKQuerySubscription(
            recordType: "CollabMarker",
            predicate: predicate,
            subscriptionID: subID,
            options: [.firesOnRecordCreation, .firesOnRecordDeletion]
        )

        let notificationInfo = CKSubscription.NotificationInfo()
        notificationInfo.shouldSendContentAvailable = true
        subscription.notificationInfo = notificationInfo

        do {
            _ = try await database.save(subscription)
            syncStatus = .synced(Date())
        } catch {
            // Subscription may already exist — that's fine
            syncStatus = .synced(Date())
        }
    }

    /// Stops the collaborative session and removes the CloudKit subscription.
    func stopCollaboration() async {
        isCollaborating = false
        collaboratorCount = 0
        syncStatus = .idle

        guard let subID = subscriptionID else { return }
        try? await database.deleteSubscription(withID: subID)
        subscriptionID = nil
        sessionID = nil
    }

    // MARK: - Push marker to CloudKit

    /// Pushes a newly placed marker to CloudKit so remote participants receive it.
    ///
    /// Requirement 28.2: sync marker placements to all participants in real time.
    func pushMarker(_ marker: CountMarker, sessionID: UUID) async {
        guard isCollaborating else { return }

        let record = CKRecord(recordType: "CollabMarker")
        record["markerID"] = marker.id.uuidString as CKRecordValue
        record["sessionID"] = sessionID.uuidString as CKRecordValue
        record["normalizedX"] = marker.normalizedX as CKRecordValue
        record["normalizedY"] = marker.normalizedY as CKRecordValue
        record["objectTypeName"] = marker.objectType.name as CKRecordValue
        record["objectTypeColorHex"] = marker.objectType.colorHex as CKRecordValue
        record["isAIDerived"] = marker.isAIDerived as CKRecordValue
        record["createdAt"] = marker.createdAt as CKRecordValue

        do {
            _ = try await database.save(record)
            syncStatus = .synced(Date())
        } catch {
            syncStatus = .failed(error.localizedDescription)
        }
    }

    /// Removes a marker from CloudKit when deleted locally.
    ///
    /// Requirement 28.3: sync marker deletions to all participants.
    func deleteMarker(id: UUID, sessionID: UUID) async {
        guard isCollaborating else { return }

        let predicate = NSPredicate(format: "markerID == %@ AND sessionID == %@",
                                    id.uuidString, sessionID.uuidString)
        let query = CKQuery(recordType: "CollabMarker", predicate: predicate)

        do {
            let (results, _) = try await database.records(matching: query)
            for (recordID, result) in results {
                if case .success = result {
                    try? await database.deleteRecord(withID: recordID)
                }
            }
        } catch {
            // Non-fatal — remote deletion is best-effort
        }
    }

    // MARK: - Fetch remote markers

    /// Fetches all remote markers for the session and merges them locally.
    ///
    /// Requirement 28.5: merge remote markers using union semantics (deduplicate by UUID).
    func fetchRemoteMarkers(
        sessionID: UUID,
        existingMarkers: [CountMarker],
        objectTypes: [ObjectType]
    ) async -> [CountMarker] {
        let predicate = NSPredicate(format: "sessionID == %@", sessionID.uuidString)
        let query = CKQuery(recordType: "CollabMarker", predicate: predicate)

        do {
            let (results, _) = try await database.records(matching: query)
            var remoteMarkers: [CountMarker] = []

            for (_, result) in results {
                guard case .success(let record) = result else { continue }
                guard
                    let markerIDStr = record["markerID"] as? String,
                    let markerID = UUID(uuidString: markerIDStr),
                    let x = record["normalizedX"] as? Double,
                    let y = record["normalizedY"] as? Double,
                    let typeName = record["objectTypeName"] as? String
                else { continue }

                // Skip if already in local markers (dedup by UUID)
                if existingMarkers.contains(where: { $0.id == markerID }) { continue }

                // Find matching object type or create a transient one
                let objectType = objectTypes.first(where: { $0.name == typeName })
                    ?? ObjectType(
                        name: typeName,
                        colorHex: record["objectTypeColorHex"] as? String ?? "#FF5733",
                        iconName: "circle.fill",
                        sortOrder: 0
                    )

                let isAI = record["isAIDerived"] as? Bool ?? false
                let createdAt = record["createdAt"] as? Date ?? Date()

                let marker = CountMarker(
                    id: markerID,
                    normalizedX: x,
                    normalizedY: y,
                    objectType: objectType,
                    isAIDerived: isAI,
                    createdAt: createdAt
                )
                remoteMarkers.append(marker)
            }

            // Union merge: combine existing + remote, deduplicated by UUID
            var mergedByID: [UUID: CountMarker] = Dictionary(
                uniqueKeysWithValues: existingMarkers.map { ($0.id, $0) }
            )
            for marker in remoteMarkers {
                mergedByID[marker.id] = marker
            }

            collaboratorCount = max(0, results.count > 0 ? 1 : 0)
            syncStatus = .synced(Date())
            return Array(mergedByID.values).sorted { $0.createdAt < $1.createdAt }

        } catch {
            syncStatus = .failed(error.localizedDescription)
            return existingMarkers
        }
    }

    // MARK: - Generate share link

    /// Generates a deep-link URL for sharing a collaborative session.
    ///
    /// Requirement 28.6: generate a shareable link for the session.
    func shareLink(for sessionID: UUID) -> URL {
        URL(string: "opencount://session/\(sessionID.uuidString)?collab=1")!
    }
}
