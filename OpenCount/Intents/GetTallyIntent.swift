import AppIntents
import SwiftData
import Foundation

// MARK: - GetTallyIntent
// Requirement 23.1, 23.2, 23.6, 27.1

/// App Intent that returns the tally for a session, optionally filtered by object type name.
/// Donated to Siri after the user views a session tally in the app.
struct GetTallyIntent: AppIntent {

    static var title: LocalizedStringResource = "Get Count Tally"
    static var description = IntentDescription(
        "Returns the current tally for a counting session, optionally filtered by object type.",
        categoryName: "Counting"
    )

    /// The UUID string of the session to query.
    @Parameter(title: "Session ID", description: "The ID of the counting session.")
    var sessionID: String

    /// Optional object type name to filter the tally.
    @Parameter(title: "Object Type", description: "The name of the object type to get the tally for. Leave empty for the total count.")
    var objectTypeName: String?

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

        let tally: Int
        let dialogText: String

        if let typeName = objectTypeName, !typeName.isEmpty {
            // Filter by object type name (case-insensitive)
            let lower = typeName.lowercased()
            tally = session.markers.filter {
                $0.objectType.name.lowercased() == lower
            }.count
            dialogText = "The tally for \"\(typeName)\" in \"\(session.name)\" is \(tally)."
        } else {
            // Total count across all object types
            tally = session.markers.count
            dialogText = "The total tally for \"\(session.name)\" is \(tally)."
        }

        return .result(value: tally, dialog: IntentDialog(stringLiteral: dialogText))
    }
}
