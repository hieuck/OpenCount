import AppIntents
import Foundation

struct GetTallyIntent: AppIntent {
    static var title: LocalizedStringResource = "Get Count Tally"
    static var description = IntentDescription(
        "Returns the current tally for a counting session, optionally filtered by object type.",
        categoryName: "Counting"
    )

    @Parameter(title: "Session ID", description: "The ID of the counting session.")
    var sessionID: String

    @Parameter(title: "Object Type", description: "The name of the object type to get the tally for. Leave empty for the total count.")
    var objectTypeName: String?

    func perform() async throws -> some IntentResult & ReturnsValue<Int> & ProvidesDialog {
        guard let uuid = UUID(uuidString: sessionID) else {
            throw IntentError.general
        }
        let sessions = try await IntentModelContainer.fetchAllSessions()
        guard let session = sessions.first(where: { $0.id == uuid }) else {
            throw IntentError.general
        }
        let tally: Int
        let dialogText: String
        if let typeName = objectTypeName, !typeName.isEmpty {
            let lower = typeName.lowercased()
            tally = session.markers.filter { $0.objectType.name.lowercased() == lower }.count
            dialogText = "The tally for \"\(typeName)\" in \"\(session.name)\" is \(tally)."
        } else {
            tally = session.markers.count
            dialogText = "The total tally for \"\(session.name)\" is \(tally)."
        }
        return .result(value: tally, dialog: IntentDialog(stringLiteral: dialogText))
    }
}
