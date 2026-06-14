import AppIntents
import Foundation

struct CreateSessionIntent: AppIntent {
    static var title: LocalizedStringResource = "Create Counting Session"
    static var description = IntentDescription(
        "Creates a new OpenCount counting session with the given name.",
        categoryName: "Session Management"
    )

    @Parameter(title: "Session Name", description: "The name for the new counting session.")
    var name: String

    func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog {
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw $name.needsValueError("Please provide a session name.")
        }
        let session = CountSession(
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            createdAt: Date(),
            modifiedAt: Date()
        )
        try await IntentModelContainer.save(session)
        return .result(
            value: session.id.uuidString,
            dialog: IntentDialog("Created a new session called \"\(session.name)\".")
        )
    }
}
