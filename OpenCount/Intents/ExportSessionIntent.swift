import AppIntents
import Foundation
import UniformTypeIdentifiers

enum ExportFormatAppEnum: String, AppEnum {
    case csv = "CSV"
    case json = "JSON"

    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        TypeDisplayRepresentation(name: "Export Format")
    }
    static var caseDisplayRepresentations: [ExportFormatAppEnum: DisplayRepresentation] {
        [.csv: DisplayRepresentation(title: "CSV"), .json: DisplayRepresentation(title: "JSON")]
    }
}

struct ExportSessionIntent: AppIntent {
    static var title: LocalizedStringResource = "Export Session"
    static var description = IntentDescription(
        "Exports a counting session as CSV or JSON and returns the file.",
        categoryName: "Export"
    )

    @Parameter(title: "Session ID", description: "The ID of the counting session to export.")
    var sessionID: String

    @Parameter(title: "Format", description: "The export format: CSV or JSON.", default: .csv)
    var format: ExportFormatAppEnum

    func perform() async throws -> some IntentResult & ReturnsValue<IntentFile> & ProvidesDialog {
        guard let uuid = UUID(uuidString: sessionID) else {
            throw IntentError.general
        }
        let sessions = try await IntentModelContainer.fetchAllSessions()
        guard let session = sessions.first(where: { $0.id == uuid }) else {
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
        return .result(value: file, dialog: IntentDialog(stringLiteral: "Exported \"\(session.name)\" as \(format.rawValue)."))
    }
}
