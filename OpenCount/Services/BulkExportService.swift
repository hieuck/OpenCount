import Foundation
import UIKit
import ZIPFoundation

// MARK: - BulkExportService

/// Exports multiple sessions as a single ZIP archive containing:
///   - One CSV file per session
///   - One JSON file per session
///   - One annotated PNG per session (if images are available)
///   - A summary CSV with totals across all sessions
///   - A README.txt with export metadata
///
/// This feature surpasses ZapCount and CountThings which only support
/// single-session exports.
final class BulkExportService {

    private let exportService = ExportService()

    // MARK: - Bulk ZIP export

    /// Creates a ZIP archive containing exports for all provided sessions.
    /// - Parameters:
    ///   - sessions: The sessions to export.
    ///   - formats: The export formats to include for each session.
    ///   - imageProvider: Optional closure that returns the UIImage for a session.
    /// - Returns: The URL of the generated ZIP file in the temporary directory.
    func exportZIP(
        sessions: [CountSession],
        formats: Set<ExportFormat> = [.csv, .json],
        imageProvider: ((CountSession) -> UIImage?)? = nil
    ) throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory
        let zipName = "OpenCount_Export_\(dateStamp()).zip"
        let zipURL = tempDir.appendingPathComponent(zipName)

        // Remove any existing file at the destination
        try? FileManager.default.removeItem(at: zipURL)

        guard let archive = Archive(url: zipURL, accessMode: .create) else {
            throw BulkExportError.archiveCreationFailed
        }

        // Export each session
        for session in sessions {
            let safeName = sanitizeFilename(session.name)

            if formats.contains(.csv) {
                let data = try exportService.exportCSV(session: session)
                try addData(data, named: "\(safeName)/\(safeName).csv", to: archive)
            }

            if formats.contains(.json) {
                let data = try exportService.exportJSON(session: session)
                try addData(data, named: "\(safeName)/\(safeName).json", to: archive)
            }

            if formats.contains(.coco) {
                let data = try exportService.exportCOCO(session: session)
                try addData(data, named: "\(safeName)/\(safeName)_coco.json", to: archive)
            }

            if formats.contains(.annotatedImage),
               let image = imageProvider?(session) {
                if let annotated = try? exportService.exportAnnotatedImage(session: session, image: image),
                   let pngData = annotated.pngData() {
                    try addData(pngData, named: "\(safeName)/\(safeName)_annotated.png", to: archive)
                }
            }

            if formats.contains(.pdf),
               let image = imageProvider?(session) {
                let pdfData = try exportService.exportPDF(session: session, image: image)
                try addData(pdfData, named: "\(safeName)/\(safeName).pdf", to: archive)
            }
        }

        // Summary CSV across all sessions
        let summaryData = buildSummaryCSV(sessions: sessions)
        try addData(summaryData, named: "summary.csv", to: archive)

        // README
        let readmeData = buildREADME(sessions: sessions, formats: formats)
        try addData(readmeData, named: "README.txt", to: archive)

        return zipURL
    }

    // MARK: - Summary CSV

    private func buildSummaryCSV(sessions: [CountSession]) -> Data {
        var lines = ["Session Name,Total Markers,Object Types,Created,Modified"]
        for session in sessions {
            let name = csvEscape(session.name)
            let total = session.markers.count
            let types = session.objectTypes.count
            let created = ISO8601DateFormatter().string(from: session.createdAt)
            let modified = ISO8601DateFormatter().string(from: session.modifiedAt)
            lines.append("\(name),\(total),\(types),\(created),\(modified)")
        }
        return lines.joined(separator: "\n").data(using: .utf8) ?? Data()
    }

    // MARK: - README

    private func buildREADME(sessions: [CountSession], formats: Set<ExportFormat>) -> Data {
        let formatList = formats.map(\.rawValue).sorted().joined(separator: ", ")
        let text = """
        OpenCount Bulk Export
        =====================
        Exported: \(Date().formatted())
        Sessions: \(sessions.count)
        Formats: \(formatList)

        Structure:
        - summary.csv          — totals across all sessions
        - <session_name>/      — one folder per session
          - <name>.csv         — marker data (if CSV selected)
          - <name>.json        — full session JSON (if JSON selected)
          - <name>_coco.json   — COCO format (if COCO selected)
          - <name>_annotated.png — annotated image (if Annotated Image selected)
          - <name>.pdf         — PDF report (if PDF selected)

        Generated by OpenCount — free, open-source counting app.
        https://github.com/opencount-app/opencount
        """
        return text.data(using: .utf8) ?? Data()
    }

    // MARK: - Helpers

    private func addData(_ data: Data, named name: String, to archive: Archive) throws {
        try archive.addEntry(
            with: name,
            type: .file,
            uncompressedSize: Int64(data.count),
            provider: { position, size in
                data.subdata(in: Int(position)..<Int(position) + size)
            }
        )
    }

    private func sanitizeFilename(_ name: String) -> String {
        let invalid = CharacterSet(charactersIn: "/\\:*?\"<>|")
        return name.components(separatedBy: invalid).joined(separator: "_")
    }

    private func csvEscape(_ value: String) -> String {
        if value.contains(",") || value.contains("\"") || value.contains("\n") {
            return "\"" + value.replacingOccurrences(of: "\"", with: "\"\"") + "\""
        }
        return value
    }

    private func dateStamp() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HHmmss"
        return formatter.string(from: Date())
    }
}

// MARK: - BulkExportError

enum BulkExportError: LocalizedError {
    case archiveCreationFailed

    var errorDescription: String? {
        switch self {
        case .archiveCreationFailed:
            return "Failed to create ZIP archive."
        }
    }
}
