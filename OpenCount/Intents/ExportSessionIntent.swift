import AppIntents
import SwiftData
import Foundation
import UniformTypeIdentifiers

// MARK: - ExportFormatAppEnum
// Requirement 23.1, 23.6

/// Represents the supported export formats as an App Intents enum.
enum ExportFormatAppEnum: String, AppEnum {
    case csv = "CSV"
    case json = "JSON"

    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        TypeDisplayRepresentation(name: "Export Format")
    }

    static var caseDisplayRepresentations: [ExportFormatAppEnum: DisplayRepresentation] {
        [
            .csv: DisplayRepresentation(title: "CSV"),
            .json: DisplayRepresentation(title: "JSON"),
        ]
    }
}

// MARK: - ExportSessionIntent
// Requirement 23.1, 23.2, 23.6, 27.1

/// App Intent that exports a session as CSV or JSON and returns the file.
/// Donated to Siri after the user exports a session in the app.
struct ExportSessionIntent: AppIntent {

    static var title: LocalizedStringResource = "Export Session"
    static var description = IntentDescription(
        "Exports a counting session as CSV or JSON and returns the file.",
        categoryName: "Export"
    )

    /// The UUID string of the session to export.
    @Parameter(title: "Session ID", description: "The ID of the counting session to export.")
    var sessionID: String

    /// The export format (CSV or JSON).
    @Parameter(title: "Format", description: "The export format: CSV or JSON.", default: .csv)
    var format: ExportFormatAppEnum

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<IntentFile> & ProvidesDialog {
        guard let uuid = UUID(uuidString: sessionID) else {
            throw IntentError.general
        }

        let container = try IntentModelContainer.makeContainer()
        let context = container.mainContext

        let descriptor = FetchDescriptor<CountSession>(
            predicate: #Predicate { $0.id == uuid }
        )
        guard let session = try context.fetch(descriptor).first else {
            throw IntentError.general
        }

        let exportService = ExportService()
        let data: Data
        let filename: String
        let contentType: UTType

        switch format {
        case .csv:
            data = try exportService.exportCSV(session: session)
            filename = "\(session.name).csv"
            contentType = .commaSeparatedText
        case .json:
            data = try exportService.exportJSON(session: session)
            filename = "\(session.name).json"
            contentType = .json
        }

        let file = IntentFile(data: data, filename: filename, type: contentType)
        let dialogText = "Exported \"\(session.name)\" as \(format.rawValue)."
        return .result(value: file, dialog: IntentDialog(stringLiteral: dialogText))
    }
}
