import AppIntents
import Foundation

// MARK: - IntentError

/// Typed errors for App Intents.
/// Used by CreateSessionIntent, GetTallyIntent, ExportSessionIntent, RunAICountingIntent.
enum IntentError: Swift.Error, CustomLocalizedStringResourceConvertible {
    case general
    case sessionNotFound
    case invalidParameter(String)

    var localizedStringResource: LocalizedStringResource {
        switch self {
        case .general:
            return "An error occurred. Please try again."
        case .sessionNotFound:
            return "The specified session could not be found."
        case .invalidParameter(let param):
            return "Invalid parameter: \(param)"
        }
    }
}
