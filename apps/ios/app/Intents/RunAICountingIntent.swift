import AppIntents
import Foundation

struct RunAICountingIntent: AppIntent {
    static var title: LocalizedStringResource = "Run AI Counting"
    static var description = IntentDescription(
        "Runs AI object counting on the most recent image in a counting session.",
        categoryName: "AI Counting"
    )

    @Parameter(title: "Session ID", description: "The ID of the counting session.")
    var sessionID: String

    func perform() async throws -> some IntentResult & ReturnsValue<Int> & ProvidesDialog {
        guard let uuid = UUID(uuidString: sessionID) else {
            throw IntentError.general
        }
        let sessions = try await IntentModelContainer.fetchAllSessions()
        guard let session = sessions.first(where: { $0.id == uuid }) else {
            throw IntentError.general
        }
        let currentCount = session.markers.count
        let dialogText = "Opening \"\(session.name)\" for AI counting. Current count: \(currentCount)."
        return .result(value: currentCount, dialog: IntentDialog(stringLiteral: dialogText))
    }
}
