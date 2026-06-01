import AppIntents
import SwiftData
import Foundation

// MARK: - CreateSessionIntent
// Requirement 23.1, 23.2, 23.6, 27.1

/// App Intent that creates a new counting session by name.
/// Donated to Siri after the user creates a session in the app.
struct CreateSessionIntent: AppIntent {

    static var title: LocalizedStringResource = "Create Counting Session"
    static var description = IntentDescription(
        "Creates a new OpenCount counting session with the given name.",
        categoryName: "Session Management"
    )

    /// The name for the new session.
    @Parameter(title: "Session Name", description: "The name for the new counting session.")
    var name: String

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog {
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw $name.needsValueError("Please provide a session name.")
        }

        // Create the session using the shared model container
        let container = try IntentModelContainer.makeContainer()
        let context = container.mainContext

        let session = CountSession(
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            createdAt: Date(),
            modifiedAt: Date()
        )
        context.insert(session)
        try context.save()

        let sessionID = session.id.uuidString
        return .result(
            value: sessionID,
            dialog: IntentDialog("Created a new session called \"\(session.name)\".")
        )
    }
}
