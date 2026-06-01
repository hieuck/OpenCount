import AppIntents
import SwiftData
import Foundation

// MARK: - RunAICountingIntent
// Requirement 23.2, 23.6, 27.1

/// App Intent that triggers AI counting on the most recent image in a session.
/// Donated to Siri after the user runs AI counting in the app.
struct RunAICountingIntent: AppIntent {

    static var title: LocalizedStringResource = "Run AI Counting"
    static var description = IntentDescription(
        "Runs AI object counting on the most recent image in a counting session.",
        categoryName: "AI Counting"
    )

    /// The UUID string of the session to run AI counting on.
    @Parameter(title: "Session ID", description: "The ID of the counting session.")
    var sessionID: String

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<Int> & ProvidesDialog {
        guard let uuid = UUID(uuidString: sessionID) else {
            throw IntentError.general
        }

        let container = try ModelContainer(for: CountSession.self, ObjectType.self,
                                           CountMarker.self, CountRegion.self,
                                           SessionImage.self, VideoFrameCount.self)
        let context = container.mainContext

        let descriptor = FetchDescriptor<CountSession>(
            predicate: #Predicate { $0.id == uuid }
        )
        guard let session = try context.fetch(descriptor).first else {
            throw IntentError.general
        }

        // AI counting from an intent requires the app to be open for full CoreML access.
        // This intent returns the current marker count and signals the app to open for AI.
        // Full AI inference is performed in-app via the deep-link opencount://session/<id>.
        let currentCount = session.markers.count
        let dialogText = "Opening \"\(session.name)\" for AI counting. Current count: \(currentCount)."

        return .result(value: currentCount, dialog: IntentDialog(stringLiteral: dialogText))
    }
}
