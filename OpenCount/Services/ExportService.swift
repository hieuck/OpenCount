import Foundation
import UIKit
import SwiftUI

// MARK: - ExportFormat

enum ExportFormat: String, CaseIterable, Identifiable {
    case csv = "CSV"
    case json = "JSON"
    case annotatedImage = "Annotated Image"
    case pdf = "PDF"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .csv: return "tablecells"
        case .json: return "curlybraces"
        case .annotatedImage: return "photo.badge.checkmark"
        case .pdf: return "doc.richtext"
        }
    }

    var fileExtension: String {
        switch self {
        case .csv: return "csv"
        case .json: return "json"
        case .annotatedImage: return "png"
        case .pdf: return "pdf"
        }
    }
}

// MARK: - ExportServiceProtocol

protocol ExportServiceProtocol {
    func exportCSV(session: CountSession) throws -> Data
    func exportJSON(session: CountSession) throws -> Data
    func exportAnnotatedImage(session: CountSession, image: UIImage,
                              annotationData: AnnotationExportData?) throws -> UIImage
    func exportPDF(session: CountSession, image: UIImage,
                   annotationData: AnnotationExportData?) throws -> Data
    func plainTextSummary(session: CountSession) -> String
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

// MARK: - UIColor hex extension

extension UIColor {
    convenience init?(hex: String) {
        var hexStr = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if hexStr.hasPrefix("#") { hexStr.removeFirst() }
        guard hexStr.count == 6, let value = UInt64(hexStr, radix: 16) else { return nil }
        let r = CGFloat((value >> 16) & 0xFF) / 255
        let g = CGFloat((value >> 8) & 0xFF) / 255
        let b = CGFloat(value & 0xFF) / 255
        self.init(red: r, green: g, blue: b, alpha: 1)
    }
}
