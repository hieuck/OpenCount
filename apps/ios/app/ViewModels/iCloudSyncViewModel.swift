import Foundation
import SwiftUI

// MARK: - iCloudSyncStatus

/// Represents the current state of iCloud sync.
/// Requirement 15.4
enum iCloudSyncStatus: Equatable {
    case idle
    case syncing
    case synced(Date)
    case failed(String)
}

// MARK: - iCloudSyncViewModel

/// Manages iCloud sync state, user preferences, and backup export/import.
///
/// Requirements: 15.1, 15.2, 15.3, 15.4, 15.5, 15.6
@MainActor
final class iCloudSyncViewModel: ObservableObject {

    // MARK: - Published state

    /// Whether the user has opted in to iCloud sync.
    /// Persisted in UserDefaults under "iCloudSyncEnabled".
    /// Requirement 15.3
    @Published var isSyncEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isSyncEnabled, forKey: Self.syncEnabledKey)
        }
    }

    /// Current sync status shown in the navigation bar indicator.
    /// Requirement 15.4
    @Published var syncStatus: iCloudSyncStatus = .idle

    // MARK: - Private constants

    private static let syncEnabledKey = "iCloudSyncEnabled"

    // MARK: - Init

    init() {
        self.isSyncEnabled = UserDefaults.standard.bool(forKey: Self.syncEnabledKey)
        setupNotifications()
    }

    // MARK: - Public API

    /// Enables iCloud sync and persists the preference.
    /// Requirement 15.3
    func enableSync() {
        isSyncEnabled = true
    }

    /// Disables iCloud sync and persists the preference.
    /// Requirement 15.3
    func disableSync() {
        isSyncEnabled = false
    }

    /// Returns true when iCloud is available (user is signed in).
    /// Requirement 15.1, 15.5
    var isICloudAvailable: Bool {
        FileManager.default.ubiquityIdentityToken != nil
    }

    // MARK: - Backup Export

    /// Serializes all sessions to a `.opencount` file in the temporary directory.
    ///
    /// Requirement 15.6
    /// - Parameter sessions: The sessions to include in the backup.
    /// - Returns: URL of the written `.opencount` file.
    func exportBackup(sessions: [CountSession]) throws -> URL {
        let dtos = sessions.map { SessionExportDTO(session: $0) }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        let data = try encoder.encode(dtos)

        let fileName = "OpenCount-Backup-\(formattedDate()).opencount"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        try data.write(to: url, options: .atomic)
        return url
    }

    // MARK: - Backup Import

    /// Reads and decodes a `.opencount` backup file.
    ///
    /// Requirement 15.6
    /// - Parameter url: URL of the `.opencount` file to import.
    /// - Returns: Array of decoded `SessionExportDTO` values.
    func importBackup(from url: URL) throws -> [SessionExportDTO] {
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode([SessionExportDTO].self, from: data)
    }

    // MARK: - Sync status helpers

    /// Call when a CloudKit sync operation begins.
    func markSyncing() {
        syncStatus = .syncing
    }

    /// Call when a CloudKit sync operation completes successfully.
    func markSynced() {
        syncStatus = .synced(Date())
    }

    /// Call when a CloudKit sync operation fails.
    /// - Parameter message: Human-readable error description.
    func markFailed(_ message: String) {
        syncStatus = .failed(message)
    }

    // MARK: - Private helpers

    /// Observes `NSUbiquitousKeyValueStore` external change notifications to detect
    /// iCloud availability changes and update sync status accordingly.
    /// Requirement 15.5
    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleUbiquitousStoreChange(_:)),
            name: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: NSUbiquitousKeyValueStore.default
        )
        // Synchronize the store to receive any pending remote changes.
        NSUbiquitousKeyValueStore.default.synchronize()
    }

    @objc private func handleUbiquitousStoreChange(_ notification: Notification) {
        guard isSyncEnabled else { return }
        // An external change means iCloud is reachable; update status.
        if case .failed = syncStatus {
            // iCloud connectivity restored — reset to idle so next sync can proceed.
            syncStatus = .idle
        }
    }

    private func formattedDate() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd-HHmmss"
        return formatter.string(from: Date())
    }
}
