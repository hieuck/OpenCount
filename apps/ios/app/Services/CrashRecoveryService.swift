import Foundation

// MARK: - CrashRecoveryService

/// Provides lightweight crash-recovery persistence for the active counting session.
///
/// On every marker mutation the current session state is serialised as a
/// `SessionExportDTO` JSON blob and written to a dedicated recovery file in the
/// app's Documents directory.  On the next launch `OpenCountApp.init()` checks
/// for this file; if it exists the previous run terminated unexpectedly and the
/// data can be offered to the user for restoration.
///
/// Requirement 18.5: recover the in-progress Session including all Count_Markers
/// on the next launch after an unexpected termination.
enum CrashRecoveryService {

    // MARK: - File URL

    /// Returns the URL of the recovery file (`Documents/recovery.opencount`).
    static func recoveryFileURL() -> URL {
        let documents = FileManager.default.urls(
            for: .documentDirectory,
            in: .userDomainMask
        )[0]
        return documents.appendingPathComponent("recovery.opencount")
    }

    // MARK: - Save

    /// Encodes `session` as `SessionExportDTO` JSON and atomically writes it to
    /// the recovery file.  Errors are silently swallowed so that a write failure
    /// never interrupts the user's counting workflow.
    ///
    /// Call this after every marker mutation (place, remove, reassign).
    ///
    /// - Parameter session: The `CountSession` whose current state should be saved.
    static func saveRecovery(session: CountSession) {
        let dto = SessionExportDTO(session: session)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(dto) else { return }
        try? data.write(to: recoveryFileURL(), options: .atomic)
    }

    // MARK: - Load

    /// Reads and decodes the recovery file.
    ///
    /// - Returns: A `SessionExportDTO` if the file exists and is valid JSON;
    ///   `nil` if the file is absent, empty, or corrupt.
    static func loadRecovery() -> SessionExportDTO? {
        let url = recoveryFileURL()
        guard let data = try? Data(contentsOf: url) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(SessionExportDTO.self, from: data)
    }

    // MARK: - Clear

    /// Deletes the recovery file.
    ///
    /// Call this after a clean session save so that a subsequent launch does not
    /// incorrectly treat a normal exit as a crash.
    static func clearRecovery() {
        try? FileManager.default.removeItem(at: recoveryFileURL())
    }
}
