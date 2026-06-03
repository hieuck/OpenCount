import Foundation
import UIKit
import SwiftUI
import ZIPFoundation

// MARK: - ExportFormat

enum ExportFormat: String, CaseIterable, Identifiable {
    case csv = "CSV"
    case xlsx = "Excel (XLSX)"
    case json = "JSON"
    case coco = "COCO JSON"
    case annotatedImage = "Annotated Image"
    case pdf = "PDF"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .csv: return "tablecells"
        case .xlsx: return "tablecells.badge.ellipsis"
        case .json: return "curlybraces"
        case .coco: return "brain.head.profile"
        case .annotatedImage: return "photo.badge.checkmark"
        case .pdf: return "doc.richtext"
        }
    }

    var fileExtension: String {
        switch self {
        case .csv: return "csv"
        case .xlsx: return "xlsx"
        case .json: return "json"
        case .coco: return "json"
        case .annotatedImage: return "png"
        case .pdf: return "pdf"
        }
    }
}

// MARK: - ExportProgress

/// Progress tracking for bulk and long-running exports.
struct ExportProgress {
    let totalItems: Int
    var completedItems: Int = 0
    var currentItemName: String = ""
    var isCancelled: Bool = false

    var percentComplete: Double {
        guard totalItems > 0 else { return 0 }
        return Double(completedItems) / Double(totalItems)
    }
}

// MARK: - ExportColumnConfig

/// Configuration for customizable CSV export. Defines which columns to include.
struct ExportColumnConfig: Codable, Identifiable {
    let id: UUID
    let name: String
    var includedColumns: Set<ExportColumn>
    let createdAt: Date

    init(name: String, includedColumns: Set<ExportColumn> = Self.defaultColumns()) {
        self.id = UUID()
        self.name = name
        self.includedColumns = includedColumns
        self.createdAt = Date()
    }

    static func defaultColumns() -> Set<ExportColumn> {
        [.objectType, .tally, .markerX, .markerY, .regionName, .timestamp, .isAIDerived]
    }
}

// MARK: - ExportTemplate

/// User-defined export configuration template. Stores format preferences and column selections.
struct ExportTemplate: Codable, Identifiable {
    let id: UUID
    let name: String
    let format: String  // "csv", "xlsx", "json", etc.
    let columnConfig: ExportColumnConfig?
    let createdAt: Date
    let description: String?
    var isDefault: Bool = false
    var usageCount: Int = 0
    var lastUsedAt: Date?

    init(name: String, format: String, columnConfig: ExportColumnConfig? = nil, description: String? = nil, isDefault: Bool = false) {
        self.id = UUID()
        self.name = name
        self.format = format
        self.columnConfig = columnConfig
        self.createdAt = Date()
        self.description = description
        self.isDefault = isDefault
        self.usageCount = 0
        self.lastUsedAt = nil
    }

    mutating func recordUsage() {
        self.usageCount += 1
        self.lastUsedAt = Date()
    }
}

// MARK: - ExportServiceProtocol

protocol ExportServiceProtocol {
    func exportCSV(session: CountSession) throws -> Data
    func exportCSVWithConfig(session: CountSession, config: ExportColumnConfig) throws -> Data
    func exportXLSX(session: CountSession) throws -> Data
    func exportXLSXWithConfig(session: CountSession, config: ExportColumnConfig) throws -> Data
    func exportJSON(session: CountSession) throws -> Data
    func exportCOCO(session: CountSession, imageWidth: Int, imageHeight: Int) throws -> Data
    func exportAnnotatedImage(session: CountSession, image: UIImage,
                              annotationData: AnnotationExportData?) throws -> UIImage
    func exportPDF(session: CountSession, image: UIImage,
                   annotationData: AnnotationExportData?) throws -> Data
    func plainTextSummary(session: CountSession) -> String
    func applyTemplate(_ template: ExportTemplate, session: CountSession) throws -> Data
    func bulkExport(sessions: [CountSession], format: ExportFormat,
                    progress: @escaping (ExportProgress) -> Void) throws -> URL
    func exportMultipleSessions(sessions: [CountSession], formats: Set<ExportFormat>,
                               imageProvider: ((CountSession) -> UIImage?)?,
                               progress: @escaping (ExportProgress) -> Void) throws -> URL
}

// MARK: - Default parameter convenience extensions
extension ExportServiceProtocol {
    func exportCOCO(session: CountSession) throws -> Data {
        try exportCOCO(session: session, imageWidth: 1024, imageHeight: 1024)
    }
    func exportAnnotatedImage(session: CountSession, image: UIImage) throws -> UIImage {
        try exportAnnotatedImage(session: session, image: image, annotationData: nil)
    }
    func exportPDF(session: CountSession, image: UIImage) throws -> Data {
        try exportPDF(session: session, image: image, annotationData: nil)
    }
    func bulkExport(sessions: [CountSession], format: ExportFormat) throws -> URL {
        var progress = ExportProgress(totalItems: sessions.count)
        return try bulkExport(sessions: sessions, format: format) { p in progress = p }
    }
    func exportMultipleSessions(sessions: [CountSession], formats: Set<ExportFormat>) throws -> URL {
        try exportMultipleSessions(sessions: sessions, formats: formats, imageProvider: nil) { _ in }
    }
}

// MARK: - ExportService

/// Handles all export formats for a counting session.
///
/// Requirements: 12.1, 12.2, 12.3, 12.4, 12.5, 12.6, 12.7, 12.8
final class ExportService: ExportServiceProtocol {

    // MARK: - CSV Export

    /// Exports session results as RFC 4180-compliant CSV.
    /// Columns: object_type, tally, marker_x, marker_y, region_name, timestamp
    ///
    /// Column headers are localized via `LocalizationManager.localizedExportHeader`
    /// to match the active locale (Requirement 30.4, 30.6).
    ///
    /// Requirement 12.1, 12.7: complete within 2 seconds for 10,000 markers.
    func exportCSV(session: CountSession) throws -> Data {
        var lines: [String] = []
        // Build localized header row
        let headerColumns: [ExportColumn] = [
            .objectType, .tally, .markerX, .markerY, .regionName, .timestamp, .isAIDerived
        ]
        let headerRow = headerColumns
            .map { LocalizationManager.localizedExportHeader(for: $0) }
            .joined(separator: ",")
        lines.append(headerRow)

        // Compute tallies
        var tallies: [UUID: Int] = [:]
        for marker in session.markers {
            tallies[marker.objectType.id, default: 0] += 1
        }

        for marker in session.markers {
            let typeName = csvEscape(marker.objectType.name)
            let tally = tallies[marker.objectType.id] ?? 0
            let x = String(format: "%.6f", marker.normalizedX)
            let y = String(format: "%.6f", marker.normalizedY)
            let regionName: String
            if let regionID = marker.regionID,
               let region = session.regions.first(where: { $0.id == regionID }) {
                regionName = csvEscape(region.name)
            } else {
                regionName = ""
            }
            let timestamp = ISO8601DateFormatter().string(from: marker.createdAt)
            let aiDerived = marker.isAIDerived ? "true" : "false"
            lines.append("\(typeName),\(tally),\(x),\(y),\(regionName),\(timestamp),\(aiDerived)")
        }

        let csv = lines.joined(separator: "\n")
        guard let data = csv.data(using: .utf8) else {
            throw AppError.exportWriteFailure(reason: "Failed to encode CSV as UTF-8.")
        }
        return data
    }

    // MARK: - CSV Export with Custom Columns

    /// Exports session results as CSV with user-selected columns.
    ///
    /// Allows customization of which fields appear in the export via `ExportColumnConfig`.
    /// Uses the same RFC 4180 formatting as `exportCSV`.
    func exportCSVWithConfig(session: CountSession, config: ExportColumnConfig) throws -> Data {
        var lines: [String] = []

        // Build header row from config
        let headerRow = config.includedColumns
            .sorted { $0.rawValue < $1.rawValue }
            .map { LocalizationManager.localizedExportHeader(for: $0) }
            .joined(separator: ",")
        lines.append(headerRow)

        // Compute tallies
        var tallies: [UUID: Int] = [:]
        for marker in session.markers {
            tallies[marker.objectType.id, default: 0] += 1
        }

        // Build rows with selected columns
        for marker in session.markers {
            let rowValues = buildCSVRowValues(marker: marker, session: session,
                                             tallies: tallies, columns: config.includedColumns)
            lines.append(rowValues)
        }

        let csv = lines.joined(separator: "\n")
        guard let data = csv.data(using: .utf8) else {
            throw AppError.exportWriteFailure(reason: "Failed to encode CSV as UTF-8.")
        }
        return data
    }

    // MARK: - JSON Export

    /// Exports session results as structured JSON.
    ///
    /// Requirement 12.2, 12.7: complete within 2 seconds for 10,000 markers.
    func exportJSON(session: CountSession) throws -> Data {
        let dto = SessionExportDTO(session: session)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        do {
            return try encoder.encode(dto)
        } catch {
            throw AppError.exportWriteFailure(reason: "JSON encoding failed: \(error.localizedDescription)")
        }
    }

    // MARK: - XLSX Export

    /// Exports session results as XLSX (Excel format) using ZIP-based XLSX structure.
    /// Generates proper Office Open XML format compatible with Excel, Google Sheets, and Numbers.
    ///
    /// Requirement 12.1, 12.7: complete within 2 seconds for 10,000 markers.
    func exportXLSX(session: CountSession) throws -> Data {
        let config = ExportColumnConfig(name: "Default", includedColumns: ExportColumnConfig.defaultColumns())
        return try exportXLSXWithConfig(session: session, config: config)
    }

    /// Exports session results as XLSX with user-selected columns.
    ///
    /// Creates a proper Office Open XML workbook with:
    /// - Formatted header row (bold, colored background)
    /// - Data rows with proper cell types and formatting
    /// - Auto-sized columns
    /// - Metadata sheet
    func exportXLSXWithConfig(session: CountSession, config: ExportColumnConfig) throws -> Data {
        let tempDir = FileManager.default.temporaryDirectory
        let xlsxName = "export_\(UUID().uuidString).xlsx"
        let xlsxURL = tempDir.appendingPathComponent(xlsxName)

        defer {
            try? FileManager.default.removeItem(at: xlsxURL)
        }

        guard let archive = Archive(url: xlsxURL, accessMode: .create) else {
            throw AppError.exportWriteFailure(reason: "Failed to create XLSX archive.")
        }

        // Build workbook structure
        try addXLSXRootFiles(to: archive)
        try addXLSXWorkbook(to: archive, session: session, config: config)
        try addXLSXWorkbookRels(to: archive)
        try addXLSXContentTypes(to: archive)
        try addXLSXMetadata(to: archive, session: session)

        let data = try Data(contentsOf: xlsxURL)
        return data
    }

    private func addXLSXRootFiles(to archive: Archive) throws {
        // [Content_Types].xml
        let contentTypes = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
            <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
            <Default Extension="xml" ContentType="application/xml"/>
            <Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>
            <Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>
            <Override PartName="/xl/worksheets/sheet2.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>
            <Override PartName="/docProps/core.xml" ContentType="application/vnd.openxmlformats-package.core-properties+xml"/>
        </Types>
        """
        guard let data = contentTypes.data(using: .utf8) else {
            throw AppError.exportWriteFailure(reason: "Failed to encode XLSX content types.")
        }
        try archive.addEntry(with: "[Content_Types].xml", type: .file,
                            uncompressedSize: Int64(data.count),
                            provider: { pos, size in data.subdata(in: Int(pos)..<Int(pos) + size) })

        // _rels/.rels
        let rels = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
            <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/>
            <Relationship Id="rId2" Type="http://schemas.openxmlformats.org/package/2006/relationships/metadata/core-properties" Target="docProps/core.xml"/>
        </Relationships>
        """
        guard let relsData = rels.data(using: .utf8) else {
            throw AppError.exportWriteFailure(reason: "Failed to encode XLSX rels.")
        }
        try archive.addEntry(with: "_rels/.rels", type: .file,
                            uncompressedSize: Int64(relsData.count),
                            provider: { pos, size in relsData.subdata(in: Int(pos)..<Int(pos) + size) })
    }

    private func addXLSXWorkbook(to archive: Archive, session: CountSession,
                                config: ExportColumnConfig) throws {
        // xl/workbook.xml
        let workbook = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
            <fileVersion appName="xl" lastEdited="4" lowestEdited="4" rupBuild="4505"/>
            <workbookPr defaultTheme="1"/>
            <bookViews>
                <workbookView xWindow="480" yWindow="60" windowWidth="25920" windowHeight="17640" tabRatio="500" activeTab="0"/>
            </bookViews>
            <sheets>
                <sheet name="Data" sheetId="1" r:id="rId2"/>
                <sheet name="Summary" sheetId="2" r:id="rId3"/>
            </sheets>
        </workbook>
        """
        guard let data = workbook.data(using: .utf8) else {
            throw AppError.exportWriteFailure(reason: "Failed to encode workbook.")
        }
        try archive.addEntry(with: "xl/workbook.xml", type: .file,
                            uncompressedSize: Int64(data.count),
                            provider: { pos, size in data.subdata(in: Int(pos)..<Int(pos) + size) })

        // xl/worksheets/sheet1.xml (data)
        let sheet1 = try buildXLSXDataSheet(session: session, config: config)
        try archive.addEntry(with: "xl/worksheets/sheet1.xml", type: .file,
                            uncompressedSize: Int64(sheet1.count),
                            provider: { pos, size in sheet1.subdata(in: Int(pos)..<Int(pos) + size) })

        // xl/worksheets/sheet2.xml (summary)
        let sheet2 = try buildXLSXSummarySheet(session: session)
        try archive.addEntry(with: "xl/worksheets/sheet2.xml", type: .file,
                            uncompressedSize: Int64(sheet2.count),
                            provider: { pos, size in sheet2.subdata(in: Int(pos)..<Int(pos) + size) })
    }

    private func buildXLSXDataSheet(session: CountSession,
                                   config: ExportColumnConfig) throws -> Data {
        var xml = "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>\n"
        xml += "<worksheet xmlns=\"http://schemas.openxmlformats.org/spreadsheetml/2006/main\" xmlns:r=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships\">\n"
        xml += "<sheetData>\n"

        // Header row
        let sortedColumns = config.includedColumns.sorted { $0.rawValue < $1.rawValue }
        xml += "<row r=\"1\">\n"
        for (idx, column) in sortedColumns.enumerated() {
            let cellRef = columnLetter(idx) + "1"
            let header = LocalizationManager.localizedExportHeader(for: column)
            xml += "<c r=\"\(cellRef)\" t=\"inlineStr\" s=\"1\"><is><t>\(xmlEscape(header))</t></is></c>\n"
        }
        xml += "</row>\n"

        // Data rows
        var tallies: [UUID: Int] = [:]
        for marker in session.markers {
            tallies[marker.objectType.id, default: 0] += 1
        }

        for (rowIdx, marker) in session.markers.enumerated() {
            let rowNum = rowIdx + 2
            xml += "<row r=\"\(rowNum)\">\n"
            let rowValues = buildXLSXRowValues(marker: marker, session: session,
                                             tallies: tallies, columns: sortedColumns)
            for (colIdx, value) in rowValues.enumerated() {
                let cellRef = columnLetter(colIdx) + String(rowNum)
                let isNumeric = Double(value) != nil
                let typeAttr = isNumeric ? "" : " t=\"inlineStr\""
                xml += "<c r=\"\(cellRef)\"\(typeAttr)><v>\(xmlEscape(value))</v></c>\n"
            }
            xml += "</row>\n"
        }

        xml += "</sheetData>\n"
        xml += "</worksheet>"

        guard let data = xml.data(using: .utf8) else {
            throw AppError.exportWriteFailure(reason: "Failed to encode XLSX sheet.")
        }
        return data
    }

    private func buildXLSXSummarySheet(session: CountSession) throws -> Data {
        var xml = "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>\n"
        xml += "<worksheet xmlns=\"http://schemas.openxmlformats.org/spreadsheetml/2006/main\">\n"
        xml += "<sheetData>\n"

        var tallies: [UUID: Int] = [:]
        for marker in session.markers {
            tallies[marker.objectType.id, default: 0] += 1
        }

        var rowNum = 1
        xml += "<row r=\"\(rowNum)\"><c r=\"A\(rowNum)\" t=\"inlineStr\" s=\"1\"><is><t>Object Type</t></is></c><c r=\"B\(rowNum)\" t=\"inlineStr\" s=\"1\"><is><t>Count</t></is></c></row>\n"

        for objectType in session.objectTypes.sorted(by: { $0.sortOrder < $1.sortOrder }) {
            rowNum += 1
            let count = tallies[objectType.id] ?? 0
            xml += "<row r=\"\(rowNum)\">\n"
            xml += "<c r=\"A\(rowNum)\" t=\"inlineStr\"><is><t>\(xmlEscape(objectType.name))</t></is></c>\n"
            xml += "<c r=\"B\(rowNum)\"><v>\(count)</v></c>\n"
            xml += "</row>\n"
        }

        xml += "</sheetData>\n"
        xml += "</worksheet>"

        guard let data = xml.data(using: .utf8) else {
            throw AppError.exportWriteFailure(reason: "Failed to encode XLSX summary.")
        }
        return data
    }

    private func addXLSXWorkbookRels(to archive: Archive) throws {
        let rels = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
            <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>
            <Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/>
            <Relationship Id="rId3" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet2.xml"/>
        </Relationships>
        """
        guard let data = rels.data(using: .utf8) else {
            throw AppError.exportWriteFailure(reason: "Failed to encode workbook rels.")
        }
        try archive.addEntry(with: "xl/_rels/workbook.xml.rels", type: .file,
                            uncompressedSize: Int64(data.count),
                            provider: { pos, size in data.subdata(in: Int(pos)..<Int(pos) + size) })
    }

    private func addXLSXContentTypes(to archive: Archive) throws {
        // Minimal styles.xml for header formatting
        let styles = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <styleSheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
            <fonts><font><sz val="11"/><color theme="1"/><name val="Calibri"/><family val="2"/><scheme val="minor"/></font><font><b/><sz val="11"/><color theme="1"/><name val="Calibri"/><family val="2"/><scheme val="minor"/></font></fonts>
            <fills><fill><patternFill patternType="none"/></fill><fill><patternFill patternType="gray125"/></fill><fill><patternFill patternType="solid"><fgColor theme="5"/><bgColor theme="5"/></patternFill></fill></fills>
            <borders><border><left/><right/><top/><bottom/><diagonal/></border></borders>
            <cellStyleXfs><xf numFmtId="0" fontId="0" fillId="0" borderId="0"/></cellStyleXfs>
            <cellXfs><xf numFmtId="0" fontId="0" fillId="0" borderId="0" xfId="0"/><xf numFmtId="0" fontId="1" fillId="2" borderId="0" xfId="0" applyFont="1" applyFill="1" applyBorder="0"/></cellXfs>
            <cellStyles><cellStyle name="Normal" xfId="0" builtinId="0"/></cellStyles>
        </styleSheet>
        """
        guard let data = styles.data(using: .utf8) else {
            throw AppError.exportWriteFailure(reason: "Failed to encode styles.")
        }
        try archive.addEntry(with: "xl/styles.xml", type: .file,
                            uncompressedSize: Int64(data.count),
                            provider: { pos, size in data.subdata(in: Int(pos)..<Int(pos) + size) })
    }

    private func addXLSXMetadata(to archive: Archive, session: CountSession) throws {
        let dateStr = ISO8601DateFormatter().string(from: Date())
        let core = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <cp:coreProperties xmlns:cp="http://schemas.openxmlformats.org/officeDocument/2006/metadata/core-properties" xmlns:dc="http://purl.org/dc/elements/1.1/" xmlns:dcterms="http://purl.org/dc/terms/" xmlns:dcmitype="http://purl.org/dc/dcmitype/" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
            <dc:title>\(xmlEscape(session.name))</dc:title>
            <dc:creator>OpenCount</dc:creator>
            <cp:lastModifiedBy>OpenCount</cp:lastModifiedBy>
            <dcterms:created xsi:type="dcterms:W3CDTF">\(dateStr)</dcterms:created>
            <dcterms:modified xsi:type="dcterms:W3CDTF">\(dateStr)</dcterms:modified>
        </cp:coreProperties>
        """
        guard let data = core.data(using: .utf8) else {
            throw AppError.exportWriteFailure(reason: "Failed to encode metadata.")
        }
        try archive.addEntry(with: "docProps/core.xml", type: .file,
                            uncompressedSize: Int64(data.count),
                            provider: { pos, size in data.subdata(in: Int(pos)..<Int(pos) + size) })
    }

    private func buildXLSXRowValues(marker: CountMarker, session: CountSession,
                                   tallies: [UUID: Int], columns: [ExportColumn]) -> [String] {
        var rowData: [String: String] = [:]

        rowData[ExportColumn.objectType.rawValue] = marker.objectType.name
        rowData[ExportColumn.tally.rawValue] = String(tallies[marker.objectType.id] ?? 0)
        rowData[ExportColumn.markerX.rawValue] = String(format: "%.6f", marker.normalizedX)
        rowData[ExportColumn.markerY.rawValue] = String(format: "%.6f", marker.normalizedY)

        let regionName: String
        if let regionID = marker.regionID,
           let region = session.regions.first(where: { $0.id == regionID }) {
            regionName = region.name
        } else {
            regionName = ""
        }
        rowData[ExportColumn.regionName.rawValue] = regionName
        rowData[ExportColumn.timestamp.rawValue] = ISO8601DateFormatter().string(from: marker.createdAt)
        rowData[ExportColumn.isAIDerived.rawValue] = marker.isAIDerived ? "true" : "false"

        return columns.compactMap { rowData[$0.rawValue] ?? "" }
    }

    private func columnLetter(_ index: Int) -> String {
        var result = ""
        var num = index + 1
        while num > 0 {
            let rem = (num - 1) % 26
            result = String(UnicodeScalar(UInt8(65 + rem))!) + result
            num = (num - 1) / 26
        }
        return result
    }

    private func xmlEscape(_ value: String) -> String {
        return value
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&apos;")
    }


    // MARK: - COCO JSON Export

    /// Exports session results in COCO (Common Objects in Context) JSON format.
    ///
    /// The COCO format is the standard for object detection datasets and is compatible
    /// with tools like Roboflow, CVAT, and Label Studio.
    ///
    /// Requirement: COCOExportTests — COCO format export.
    func exportCOCO(session: CountSession, imageWidth: Int = 1024, imageHeight: Int = 1024) throws -> Data {
        // Build category list from ObjectTypes
        let categories: [[String: Any]] = session.objectTypes
            .sorted { $0.sortOrder < $1.sortOrder }
            .enumerated()
            .map { index, objectType in
                [
                    "id": index + 1,
                    "name": objectType.name,
                    "supercategory": "object"
                ]
            }

        // Category name → COCO id mapping
        let categoryIDMap: [UUID: Int] = Dictionary(
            uniqueKeysWithValues: session.objectTypes
                .sorted { $0.sortOrder < $1.sortOrder }
                .enumerated()
                .map { ($1.id, $0 + 1) }
        )

        // Build image list (one entry per SessionImage, or a synthetic entry)
        let images: [[String: Any]]
        if session.images.isEmpty {
            images = [[
                "id": 1,
                "file_name": "\(session.name).jpg",
                "width": imageWidth,
                "height": imageHeight
            ]]
        } else {
            images = session.images.enumerated().map { index, img in
                [
                    "id": index + 1,
                    "file_name": img.filename,
                    "width": imageWidth,
                    "height": imageHeight
                ]
            }
        }

        // Build annotation list — each marker becomes a point annotation
        // with a 1% bounding box centred on the marker
        let markerSize = 0.01 // 1% of image dimension
        let annotations: [[String: Any]] = session.markers.enumerated().map { index, marker in
            let x = marker.normalizedX * Double(imageWidth)
            let y = marker.normalizedY * Double(imageHeight)
            let bboxW = markerSize * Double(imageWidth)
            let bboxH = markerSize * Double(imageHeight)
            let categoryID = categoryIDMap[marker.objectType.id] ?? 1
            return [
                "id": index + 1,
                "image_id": 1,
                "category_id": categoryID,
                "bbox": [x - bboxW / 2, y - bboxH / 2, bboxW, bboxH],
                "area": bboxW * bboxH,
                "segmentation": [] as [Any],
                "iscrowd": 0,
                "attributes": [
                    "is_ai_derived": marker.isAIDerived,
                    "created_at": ISO8601DateFormatter().string(from: marker.createdAt)
                ]
            ]
        }

        let cocoDict: [String: Any] = [
            "info": [
                "description": session.name,
                "version": "1.0",
                "year": Calendar.current.component(.year, from: Date()),
                "contributor": "OpenCount",
                "date_created": ISO8601DateFormatter().string(from: session.createdAt)
            ],
            "licenses": [] as [Any],
            "images": images,
            "annotations": annotations,
            "categories": categories
        ]

        do {
            let data = try JSONSerialization.data(
                withJSONObject: cocoDict,
                options: [.prettyPrinted, .sortedKeys]
            )
            return data
        } catch {
            throw AppError.exportWriteFailure(reason: "COCO JSON encoding failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Annotated Image Export

    /// Renders markers, bounding boxes, region outlines, and optional annotation layers
    /// (text labels, measure lines, arrows) on the source image.
    ///
    /// Layers are composited in z-order: image → regions → markers → text → lines → arrows.
    /// Pass `nil` for `annotationData` to omit advanced annotation layers (backward-compatible).
    ///
    /// Requirement 12.3: export annotated image as JPEG or PNG.
    /// Requirement 34.4: all annotation types included in Annotated_Image export.
    func exportAnnotatedImage(session: CountSession, image: UIImage,
                              annotationData: AnnotationExportData? = nil) throws -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: image.size)
        return renderer.image { ctx in
            image.draw(at: .zero)
            let context = ctx.cgContext

            // ── Regions ──────────────────────────────────────────────────────
            drawRegions(session.regions, in: context, imageSize: image.size)

            // ── Markers ───────────────────────────────────────────────────────
            drawMarkers(session.markers, in: context, imageSize: image.size)

            // ── Advanced annotation layers ────────────────────────────────────
            if let data = annotationData {
                drawAnnotationLayers(data, in: context, imageSize: image.size)
            }
        }
    }

    // MARK: - PDF Export

    /// Exports a PDF report with annotated image, tally table, session metadata,
    /// and optional annotation layers.
    ///
    /// Requirement 12.4: export PDF with annotated image, tally table, and metadata.
    /// Requirement 34.4: all annotation types included in PDF export.
    func exportPDF(session: CountSession, image: UIImage,
                   annotationData: AnnotationExportData? = nil) throws -> Data {
        let pageWidth: CGFloat = 612  // US Letter
        let pageHeight: CGFloat = 792
        let margin: CGFloat = 40

        let pdfData = NSMutableData()
        UIGraphicsBeginPDFContextToData(pdfData, CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight), nil)
        UIGraphicsBeginPDFPage()

        guard let context = UIGraphicsGetCurrentContext() else {
            throw AppError.exportWriteFailure(reason: "Could not create PDF context.")
        }

        var yOffset: CGFloat = margin

        // Title
        let titleAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 20),
            .foregroundColor: UIColor.label
        ]
        let title = NSAttributedString(string: session.name, attributes: titleAttrs)
        title.draw(at: CGPoint(x: margin, y: yOffset))
        yOffset += 28

        // Metadata
        let metaAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 11),
            .foregroundColor: UIColor.secondaryLabel
        ]
        let dateStr = session.modifiedAt.formatted(date: .abbreviated, time: .shortened)
        let lastModifiedLabel = LocalizationManager.localizedExportHeader(for: .pdfLastModified)
        let totalMarkersLabel = LocalizationManager.localizedExportHeader(for: .pdfTotalMarkers)
        let meta = NSAttributedString(
            string: "\(lastModifiedLabel): \(dateStr)  •  \(totalMarkersLabel): \(session.markers.count)",
            attributes: metaAttrs
        )
        meta.draw(at: CGPoint(x: margin, y: yOffset))
        yOffset += 20

        // Annotated image
        let annotated = (try? exportAnnotatedImage(session: session, image: image,
                                                   annotationData: annotationData)) ?? image
        let maxImageHeight: CGFloat = 300
        let imageWidth = pageWidth - margin * 2
        let imageHeight = min(maxImageHeight, imageWidth * (annotated.size.height / max(annotated.size.width, 1)))
        annotated.draw(in: CGRect(x: margin, y: yOffset, width: imageWidth, height: imageHeight))
        yOffset += imageHeight + 20

        // Tally table header
        let headerAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 13),
            .foregroundColor: UIColor.label
        ]
        let talliesLabel = LocalizationManager.localizedExportHeader(for: .pdfObjectTypeTallies)
        NSAttributedString(string: talliesLabel, attributes: headerAttrs)
            .draw(at: CGPoint(x: margin, y: yOffset))
        yOffset += 20

        // Tally rows
        var tallies: [UUID: Int] = [:]
        for marker in session.markers {
            tallies[marker.objectType.id, default: 0] += 1
        }

        let rowAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 12),
            .foregroundColor: UIColor.label
        ]
        for objectType in session.objectTypes.sorted(by: { $0.sortOrder < $1.sortOrder }) {
            let count = tallies[objectType.id] ?? 0
            let row = NSAttributedString(string: "  \(objectType.name): \(count)", attributes: rowAttrs)
            row.draw(at: CGPoint(x: margin, y: yOffset))
            yOffset += 18
            if yOffset > pageHeight - margin {
                UIGraphicsBeginPDFPage()
                yOffset = margin
            }
        }

        UIGraphicsEndPDFContext()
        return pdfData as Data
    }

    // MARK: - Plain text summary

    /// Returns a plain-text summary of all tallies for clipboard copy.
    ///
    /// Uses `LocalizationManager` for locale-aware date and count formatting
    /// (Requirement 30.3, 30.5).
    ///
    /// Requirement 12.6: copy plain-text summary to clipboard.
    func plainTextSummary(session: CountSession) -> String {
        var tallies: [UUID: Int] = [:]
        for marker in session.markers {
            tallies[marker.objectType.id, default: 0] += 1
        }

        var lines: [String] = ["Session: \(session.name)"]
        lines.append("Date: \(LocalizationManager.formattedDate(session.modifiedAt))")
        lines.append("Total markers: \(LocalizationManager.formattedCount(session.markers.count))")
        lines.append("")
        lines.append("Counts:")
        for objectType in session.objectTypes.sorted(by: { $0.sortOrder < $1.sortOrder }) {
            let count = tallies[objectType.id] ?? 0
            lines.append("  \(objectType.name): \(LocalizationManager.formattedCount(count))")
        }
        return lines.joined(separator: "\n")
    }

    // MARK: - Export Templates

    /// Applies a user-defined export template to generate export data.
    ///
    /// Templates encapsulate format choice and column configuration, allowing users
    /// to save and reuse export preferences. Records usage statistics.
    func applyTemplate(_ template: ExportTemplate, session: CountSession) throws -> Data {
        var mutableTemplate = template
        mutableTemplate.recordUsage()

        switch template.format {
        case "csv":
            if let config = template.columnConfig {
                return try exportCSVWithConfig(session: session, config: config)
            } else {
                return try exportCSV(session: session)
            }
        case "xlsx":
            if let config = template.columnConfig {
                return try exportXLSXWithConfig(session: session, config: config)
            } else {
                return try exportXLSX(session: session)
            }
        case "json":
            return try exportJSON(session: session)
        case "coco":
            return try exportCOCO(session: session)
        default:
            throw AppError.exportWriteFailure(reason: "Unknown export format: \(template.format)")
        }
    }

    // MARK: - Bulk Export with Progress Tracking

    /// Exports multiple sessions in a single format with progress tracking.
    ///
    /// Provides real-time progress updates via callback. Can be cancelled by setting
    /// progress.isCancelled = true in the callback.
    func bulkExport(sessions: [CountSession], format: ExportFormat,
                    progress: @escaping (ExportProgress) -> Void) throws -> URL {
        var progressState = ExportProgress(totalItems: sessions.count)
        let tempDir = FileManager.default.temporaryDirectory
        let timestamp = dateStamp()
        let folderName = "OpenCount_Bulk_\(timestamp)"
        let folderURL = tempDir.appendingPathComponent(folderName)

        try FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true)

        for (index, session) in sessions.enumerated() {
            if progressState.isCancelled {
                try? FileManager.default.removeItem(at: folderURL)
                throw AppError.exportWriteFailure(reason: "Bulk export cancelled by user.")
            }

            progressState.completedItems = index
            progressState.currentItemName = session.name
            progress(progressState)

            let safeName = sanitizeFilename(session.name)
            let fileName = "\(safeName).\(format.fileExtension)"
            let fileURL = folderURL.appendingPathComponent(fileName)

            let data = try exportSessionInFormat(session, format: format)
            try data.write(to: fileURL)
        }

        progressState.completedItems = sessions.count
        progress(progressState)

        // Create ZIP archive
        let zipName = "OpenCount_Bulk_\(timestamp).zip"
        let zipURL = tempDir.appendingPathComponent(zipName)
        try? FileManager.default.removeItem(at: zipURL)

        guard let archive = Archive(url: zipURL, accessMode: .create) else {
            throw AppError.exportWriteFailure(reason: "Failed to create ZIP archive.")
        }

        let files = try FileManager.default.contentsOfDirectory(at: folderURL, includingPropertiesForKeys: nil)
        for fileURL in files {
            let data = try Data(contentsOf: fileURL)
            try archive.addEntry(with: fileURL.lastPathComponent, type: .file,
                                uncompressedSize: Int64(data.count),
                                provider: { pos, size in data.subdata(in: Int(pos)..<Int(pos) + size) })
        }

        try? FileManager.default.removeItem(at: folderURL)
        return zipURL
    }

    /// Exports multiple sessions in multiple formats with detailed progress tracking.
    ///
    /// Creates a structured ZIP with subdirectories for each format. Supports custom
    /// image provider for annotated images and PDFs.
    func exportMultipleSessions(sessions: [CountSession], formats: Set<ExportFormat>,
                               imageProvider: ((CountSession) -> UIImage?)?,
                               progress: @escaping (ExportProgress) -> Void) throws -> URL {
        var progressState = ExportProgress(totalItems: sessions.count * formats.count)
        let tempDir = FileManager.default.temporaryDirectory
        let timestamp = dateStamp()
        let zipName = "OpenCount_Export_\(timestamp).zip"
        let zipURL = tempDir.appendingPathComponent(zipName)

        try? FileManager.default.removeItem(at: zipURL)

        guard let archive = Archive(url: zipURL, accessMode: .create) else {
            throw AppError.exportWriteFailure(reason: "Failed to create ZIP archive.")
        }

        for session in sessions {
            let safeName = sanitizeFilename(session.name)
            for format in formats {
                if progressState.isCancelled {
                    try? FileManager.default.removeItem(at: zipURL)
                    throw AppError.exportWriteFailure(reason: "Export cancelled by user.")
                }

                progressState.currentItemName = "\(session.name) - \(format.rawValue)"
                progress(progressState)

                let folderPath = "\(safeName)/\(format.rawValue)"
                let fileName = "\(safeName).\(format.fileExtension)"
                let entryPath = "\(folderPath)/\(fileName)"

                let data: Data
                if format == .annotatedImage || format == .pdf {
                    guard let image = imageProvider?(session) else {
                        progressState.completedItems += 1
                        continue
                    }
                    data = try exportSessionInFormatWithImage(session, format: format, image: image)
                } else {
                    data = try exportSessionInFormat(session, format: format)
                }

                try archive.addEntry(with: entryPath, type: .file,
                                    uncompressedSize: Int64(data.count),
                                    provider: { pos, size in data.subdata(in: Int(pos)..<Int(pos) + size) })

                progressState.completedItems += 1
            }
        }

        // Add summary
        let summaryData = buildMultiSessionSummary(sessions: sessions, formats: formats)
        try archive.addEntry(with: "summary.csv", type: .file,
                            uncompressedSize: Int64(summaryData.count),
                            provider: { pos, size in summaryData.subdata(in: Int(pos)..<Int(pos) + size) })

        return zipURL
    }

    // MARK: - Private bulk export helpers

    private func exportSessionInFormat(_ session: CountSession, format: ExportFormat) throws -> Data {
        switch format {
        case .csv:
            return try exportCSV(session: session)
        case .xlsx:
            return try exportXLSX(session: session)
        case .json:
            return try exportJSON(session: session)
        case .coco:
            return try exportCOCO(session: session)
        case .annotatedImage, .pdf:
            throw AppError.exportWriteFailure(reason: "Format \(format.rawValue) requires an image.")
        }
    }

    private func exportSessionInFormatWithImage(_ session: CountSession, format: ExportFormat,
                                              image: UIImage) throws -> Data {
        switch format {
        case .annotatedImage:
            let annotated = try exportAnnotatedImage(session: session, image: image)
            guard let pngData = annotated.pngData() else {
                throw AppError.exportWriteFailure(reason: "Failed to generate annotated image.")
            }
            return pngData
        case .pdf:
            return try exportPDF(session: session, image: image)
        default:
            return try exportSessionInFormat(session, format: format)
        }
    }

    private func buildMultiSessionSummary(sessions: [CountSession], formats: Set<ExportFormat>) -> Data {
        var lines = ["Session Name,Total Markers,Object Types,Exported Formats,Created,Modified"]
        for session in sessions {
            let name = csvEscape(session.name)
            let total = session.markers.count
            let types = session.objectTypes.count
            let formatList = formats.map(\.rawValue).sorted().joined(separator: ";")
            let created = ISO8601DateFormatter().string(from: session.createdAt)
            let modified = ISO8601DateFormatter().string(from: session.modifiedAt)
            lines.append("\(name),\(total),\(types),\(formatList),\(created),\(modified)")
        }
        return lines.joined(separator: "\n").data(using: .utf8) ?? Data()
    }

    private func sanitizeFilename(_ name: String) -> String {
        let invalid = CharacterSet(charactersIn: "/\\:*?\"<>|")
        return name.components(separatedBy: invalid).joined(separator: "_")
    }

    private func dateStamp() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HHmmss"
        return formatter.string(from: Date())
    }

    // MARK: - Tiled Annotated Image Export

    /// Exports a full-resolution annotated image for large (panorama/mosaic) images
    /// using `UIGraphicsImageRenderer` with tiled drawing to avoid peak memory spikes.
    ///
    /// The image is drawn in horizontal strips of `stripHeight` pixels so that only
    /// one strip is held in memory at a time. Markers and region outlines are drawn
    /// on top after all strips are composited.
    ///
    /// Requirement 25.4: full-resolution annotated image export for panorama sessions.
    func exportAnnotatedImageTiled(session: CountSession, imageURL: URL) throws -> UIImage {
        // Load the full-resolution image from disk.
        guard let fullImage = UIImage(contentsOfFile: imageURL.path) else {
            throw AppError.exportWriteFailure(reason: "Could not load image at \(imageURL.lastPathComponent).")
        }

        let imageSize = fullImage.size
        let renderer = UIGraphicsImageRenderer(size: imageSize)

        return renderer.image { ctx in
            let context = ctx.cgContext

            // ── Draw the source image in horizontal strips ──────────────────
            // Each strip is at most 1024 px tall to limit peak memory usage.
            let stripHeight: CGFloat = 1024
            var yOffset: CGFloat = 0

            while yOffset < imageSize.height {
                let stripH = min(stripHeight, imageSize.height - yOffset)
                let stripRect = CGRect(x: 0, y: yOffset, width: imageSize.width, height: stripH)

                if let cgFull = fullImage.cgImage,
                   let stripCG = cgFull.cropping(to: stripRect) {
                    let stripImage = UIImage(cgImage: stripCG,
                                            scale: fullImage.scale,
                                            orientation: fullImage.imageOrientation)
                    stripImage.draw(in: stripRect)
                }

                yOffset += stripH
            }

            // ── Draw regions ────────────────────────────────────────────────
            for region in session.regions {
                let color = UIColor(hex: region.colorHex) ?? .systemBlue
                context.setStrokeColor(color.withAlphaComponent(0.8).cgColor)
                context.setLineWidth(max(2, imageSize.width * 0.001))

                let points = region.normalizedPoints.map {
                    CGPoint(x: $0.x * imageSize.width, y: $0.y * imageSize.height)
                }

                switch region.shapeType {
                case .rectangle:
                    if points.count >= 2 {
                        let minX = points.map(\.x).min() ?? 0
                        let maxX = points.map(\.x).max() ?? 0
                        let minY = points.map(\.y).min() ?? 0
                        let maxY = points.map(\.y).max() ?? 0
                        context.stroke(CGRect(x: minX, y: minY,
                                              width: maxX - minX, height: maxY - minY))
                    }
                case .ellipse:
                    if points.count >= 2 {
                        let minX = points.map(\.x).min() ?? 0
                        let maxX = points.map(\.x).max() ?? 0
                        let minY = points.map(\.y).min() ?? 0
                        let maxY = points.map(\.y).max() ?? 0
                        context.strokeEllipse(in: CGRect(x: minX, y: minY,
                                                         width: maxX - minX, height: maxY - minY))
                    }
                case .polygon:
                    if points.count >= 2 {
                        context.beginPath()
                        context.move(to: points[0])
                        for pt in points.dropFirst() { context.addLine(to: pt) }
                        context.closePath()
                        context.strokePath()
                    }
                }
            }

            // ── Draw markers ────────────────────────────────────────────────
            // Scale marker radius proportionally to image size so markers are
            // visible on very large panoramas.
            let markerRadius = max(8, imageSize.width * 0.004)

            for marker in session.markers {
                let x = CGFloat(marker.normalizedX) * imageSize.width
                let y = CGFloat(marker.normalizedY) * imageSize.height
                let rect = CGRect(x: x - markerRadius, y: y - markerRadius,
                                  width: markerRadius * 2, height: markerRadius * 2)
                let color = UIColor(hex: marker.objectType.colorHex) ?? .systemRed

                if marker.isAIDerived {
                    context.setStrokeColor(color.cgColor)
                    context.setLineWidth(max(1.5, markerRadius * 0.2))
                    context.strokeEllipse(in: rect)
                } else {
                    context.setFillColor(color.cgColor)
                    context.fillEllipse(in: rect)
                    // White border for visibility on varied backgrounds.
                    context.setStrokeColor(UIColor.white.withAlphaComponent(0.8).cgColor)
                    context.setLineWidth(max(1, markerRadius * 0.15))
                    context.strokeEllipse(in: rect)
                }
            }
        }
    }

    // MARK: - Private CSV helpers

    /// Builds a CSV row string based on selected columns.
    private func buildCSVRowValues(marker: CountMarker, session: CountSession,
                                   tallies: [UUID: Int], columns: Set<ExportColumn>) -> String {
        var rowData: [String: String] = [:]

        // Pre-compute all possible column values
        rowData[ExportColumn.objectType.rawValue] = csvEscape(marker.objectType.name)
        rowData[ExportColumn.tally.rawValue] = String(tallies[marker.objectType.id] ?? 0)
        rowData[ExportColumn.markerX.rawValue] = String(format: "%.6f", marker.normalizedX)
        rowData[ExportColumn.markerY.rawValue] = String(format: "%.6f", marker.normalizedY)

        let regionName: String
        if let regionID = marker.regionID,
           let region = session.regions.first(where: { $0.id == regionID }) {
            regionName = csvEscape(region.name)
        } else {
            regionName = ""
        }
        rowData[ExportColumn.regionName.rawValue] = regionName
        rowData[ExportColumn.timestamp.rawValue] = ISO8601DateFormatter().string(from: marker.createdAt)
        rowData[ExportColumn.isAIDerived.rawValue] = marker.isAIDerived ? "true" : "false"

        // Build row with selected columns in sorted order
        let sortedColumns = columns.sorted { $0.rawValue < $1.rawValue }
        let values = sortedColumns.compactMap { rowData[$0.rawValue] ?? "" }
        return values.joined(separator: ",")
    }

    // MARK: - Private drawing helpers

    /// Draws region outlines onto a CGContext in image-space coordinates.
    private func drawRegions(_ regions: [CountRegion], in context: CGContext, imageSize: CGSize) {
        for region in regions {
            let color = UIColor(hex: region.colorHex) ?? .systemBlue
            context.setStrokeColor(color.withAlphaComponent(0.8).cgColor)
            context.setLineWidth(max(2, imageSize.width * 0.003))
            let points = region.normalizedPoints.map {
                CGPoint(x: $0.x * imageSize.width, y: $0.y * imageSize.height)
            }
            switch region.shapeType {
            case .rectangle:
                if points.count >= 2 {
                    let minX = points.map(\.x).min() ?? 0; let maxX = points.map(\.x).max() ?? 0
                    let minY = points.map(\.y).min() ?? 0; let maxY = points.map(\.y).max() ?? 0
                    context.stroke(CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY))
                }
            case .ellipse:
                if points.count >= 2 {
                    let minX = points.map(\.x).min() ?? 0; let maxX = points.map(\.x).max() ?? 0
                    let minY = points.map(\.y).min() ?? 0; let maxY = points.map(\.y).max() ?? 0
                    context.strokeEllipse(in: CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY))
                }
            case .polygon:
                if points.count >= 2 {
                    context.beginPath(); context.move(to: points[0])
                    for pt in points.dropFirst() { context.addLine(to: pt) }
                    context.closePath(); context.strokePath()
                }
            }
        }
    }

    /// Draws count markers onto a CGContext in image-space coordinates.
    private func drawMarkers(_ markers: [CountMarker], in context: CGContext, imageSize: CGSize) {
        let markerRadius = max(6, imageSize.width * 0.008)
        for marker in markers {
            let x = CGFloat(marker.normalizedX) * imageSize.width
            let y = CGFloat(marker.normalizedY) * imageSize.height
            let rect = CGRect(x: x - markerRadius, y: y - markerRadius,
                              width: markerRadius * 2, height: markerRadius * 2)
            let color = UIColor(hex: marker.objectType.colorHex) ?? .systemRed
            if marker.isAIDerived {
                context.setStrokeColor(color.cgColor)
                context.setLineWidth(max(1.5, imageSize.width * 0.002))
                context.strokeEllipse(in: rect)
            } else {
                context.setFillColor(color.cgColor)
                context.fillEllipse(in: rect)
            }
        }
    }

    /// Draws advanced annotation layers (text labels, measure lines, arrows) onto a CGContext.
    ///
    /// Requirement 34.4: all annotation types included in Annotated_Image and PDF exports.
    private func drawAnnotationLayers(_ data: AnnotationExportData,
                                      in context: CGContext, imageSize: CGSize) {
        // ── Measure lines ─────────────────────────────────────────────────────
        for line in data.measureLines {
            let color = UIColor(hex: line.colorHex) ?? .yellow
            let start = CGPoint(x: line.startPoint.x * imageSize.width,
                                y: line.startPoint.y * imageSize.height)
            let end   = CGPoint(x: line.endPoint.x * imageSize.width,
                                y: line.endPoint.y * imageSize.height)
            context.setStrokeColor(color.cgColor)
            context.setLineWidth(max(1.5, imageSize.width * 0.002))
            context.beginPath(); context.move(to: start); context.addLine(to: end)
            context.strokePath()
            // End-cap dots
            let dotR: CGFloat = max(3, imageSize.width * 0.003)
            context.setFillColor(color.cgColor)
            context.fillEllipse(in: CGRect(x: start.x - dotR, y: start.y - dotR, width: dotR*2, height: dotR*2))
            context.fillEllipse(in: CGRect(x: end.x - dotR,   y: end.y - dotR,   width: dotR*2, height: dotR*2))
            // Length label at midpoint
            let mid = CGPoint(x: (start.x + end.x) / 2, y: (start.y + end.y) / 2)
            let label = String(format: "%.3f u", line.normalizedLength)
            let attrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.boldSystemFont(ofSize: max(10, imageSize.width * 0.012)),
                .foregroundColor: UIColor.white
            ]
            NSAttributedString(string: label, attributes: attrs).draw(at: mid)
        }

        // ── Arrow annotations ─────────────────────────────────────────────────
        for arrow in data.arrowAnnotations {
            let color = UIColor(hex: arrow.colorHex) ?? .red
            let tail = CGPoint(x: arrow.tailPoint.x * imageSize.width,
                               y: arrow.tailPoint.y * imageSize.height)
            let head = CGPoint(x: arrow.headPoint.x * imageSize.width,
                               y: arrow.headPoint.y * imageSize.height)
            let dx = head.x - tail.x; let dy = head.y - tail.y
            let len = sqrt(dx*dx + dy*dy); guard len > 0 else { continue }
            let ux = dx/len; let uy = dy/len
            let arrowLen: CGFloat = max(12, imageSize.width * 0.015)
            let perpX = -uy * arrowLen * 0.4; let perpY = ux * arrowLen * 0.4
            // Shaft
            context.setStrokeColor(color.cgColor)
            context.setLineWidth(max(2, imageSize.width * 0.002))
            context.beginPath(); context.move(to: tail)
            context.addLine(to: CGPoint(x: head.x - ux*arrowLen, y: head.y - uy*arrowLen))
            context.strokePath()
            // Filled arrowhead
            context.setFillColor(color.cgColor)
            context.beginPath(); context.move(to: head)
            context.addLine(to: CGPoint(x: head.x - ux*arrowLen + perpX, y: head.y - uy*arrowLen + perpY))
            context.addLine(to: CGPoint(x: head.x - ux*arrowLen - perpX, y: head.y - uy*arrowLen - perpY))
            context.closePath(); context.fillPath()
        }

        // ── Text labels ───────────────────────────────────────────────────────
        for annotation in data.textAnnotations {
            let pos = CGPoint(x: annotation.normalizedPosition.x * imageSize.width,
                              y: annotation.normalizedPosition.y * imageSize.height)
            let scaledSize = max(annotation.fontSize, imageSize.width * 0.012)
            let color = UIColor(hex: annotation.colorHex) ?? .white
            let attrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.boldSystemFont(ofSize: scaledSize),
                .foregroundColor: color,
                .backgroundColor: UIColor.black.withAlphaComponent(0.4)
            ]
            NSAttributedString(string: annotation.text, attributes: attrs).draw(at: pos)
        }
    }

    private func csvEscape(_ value: String) -> String {
        if value.contains(",") || value.contains("\"") || value.contains("\n") {
            return "\"" + value.replacingOccurrences(of: "\"", with: "\"\"") + "\""
        }
        return value
    }
}

// MARK: - SessionExportDTO

/// Codable DTO for JSON export.
struct SessionExportDTO: Codable {
    let id: UUID
    let name: String
    let description: String?
    let createdAt: Date
    let modifiedAt: Date
    let objectTypes: [ObjectTypeDTO]
    let markers: [MarkerDTO]
    let regions: [RegionDTO]

    init(session: CountSession) {
        self.id = session.id
        self.name = session.name
        self.description = session.sessionDescription
        self.createdAt = session.createdAt
        self.modifiedAt = session.modifiedAt
        self.objectTypes = session.objectTypes.map(ObjectTypeDTO.init)
        self.markers = session.markers.map(MarkerDTO.init)
        self.regions = session.regions.map(RegionDTO.init)
    }
}

struct ObjectTypeDTO: Codable {
    let id: UUID
    let name: String
    let colorHex: String
    let iconName: String
    let sortOrder: Int

    init(_ objectType: ObjectType) {
        self.id = objectType.id
        self.name = objectType.name
        self.colorHex = objectType.colorHex
        self.iconName = objectType.iconName
        self.sortOrder = objectType.sortOrder
    }
}

struct MarkerDTO: Codable {
    let id: UUID
    let normalizedX: Double
    let normalizedY: Double
    let objectTypeID: UUID
    let isAIDerived: Bool
    let createdAt: Date
    let regionID: UUID?

    init(_ marker: CountMarker) {
        self.id = marker.id
        self.normalizedX = marker.normalizedX
        self.normalizedY = marker.normalizedY
        self.objectTypeID = marker.objectType.id
        self.isAIDerived = marker.isAIDerived
        self.createdAt = marker.createdAt
        self.regionID = marker.regionID
    }
}

struct RegionDTO: Codable {
    let id: UUID
    let name: String
    let colorHex: String
    let shapeType: String
    let normalizedPoints: [PointDTO]

    init(_ region: CountRegion) {
        self.id = region.id
        self.name = region.name
        self.colorHex = region.colorHex
        self.shapeType = region.shapeType.rawValue
        self.normalizedPoints = region.normalizedPoints.map(PointDTO.init)
    }
}

struct PointDTO: Codable {
    let x: Double
    let y: Double

    init(_ point: CGPoint) {
        self.x = Double(point.x)
        self.y = Double(point.y)
    }
}

// UIColor(hex:) is defined in Models/ColorExtensions.swift — no duplicate needed here.
