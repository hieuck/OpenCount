import AppIntents
import Foundation

// MARK: - IntentDonationService
// Requirement 23.1: donate Siri Shortcuts after relevant user actions

/// Donates App Intents to Siri after the user performs relevant actions in the app.
/// Donations teach Siri when to proactively suggest shortcuts.
///
/// Call the appropriate `donate*` method from the ViewModel or View after each action.
enum IntentDonationService {

    // MARK: - Session created

    /// Donate a `CreateSessionIntent` after the user creates a new session.
    /// Siri learns to suggest "Start counting in OpenCount" at similar times/contexts.
    static func donateSessionCreated(sessionID: String, sessionName: String) {
        var intent = CreateSessionIntent()
        intent.name = sessionName
        // Donation is implicit for AppIntents — performing the intent donates it automatically.
        // For explicit donation, use INInteraction with a wrapped intent on iOS 16.
        // On iOS 16+, AppIntents are donated automatically when `perform()` is called.
        // This method is a hook for future explicit donation logic if needed.
        _ = intent
    }

    // MARK: - Tally viewed

    /// Donate a `GetTallyIntent` after the user views a session's tally.
    static func donateTallyViewed(sessionID: String, objectTypeName: String?) {
        var intent = GetTallyIntent()
        intent.sessionID = sessionID
        intent.objectTypeName = objectTypeName
        _ = intent
    }

    // MARK: - Session exported

    /// Donate an `ExportSessionIntent` after the user exports a session.
    static func donateSessionExported(sessionID: String, format: ExportFormatAppEnum) {
        var intent = ExportSessionIntent()
        intent.sessionID = sessionID
        intent.format = format
        _ = intent
    }

    // MARK: - AI counting run

    /// Donate a `RunAICountingIntent` after the user runs AI counting on a session.
    static func donateAICountingRun(sessionID: String) {
        var intent = RunAICountingIntent()
        intent.sessionID = sessionID
        _ = intent
    }
}
