import UIKit

/// Service xử lý export kết quả đếm sang nhiều định dạng
final class ExportService {

    // MARK: - Export Formats
    enum ExportFormat {
        case csv
        case json
        case pdf
        case text
    }

    enum ExportError: LocalizedError {
        case noData
        case encodingFailed
        case pdfGenerationFailed
        case fileWriteFailed

        var errorDescription: String? {
            switch self {
            case .noData:
                return "Không có dữ liệu để export"
            case .encodingFailed:
                return "Không thể mã hóa dữ liệu"
            case .pdfGenerationFailed:
                return "Không thể tạo file PDF"
            case .fileWriteFailed:
                return "Không thể lưu file"
            }
        }
    }

    // MARK: - Export Methods

    /// Export một kết quả đếm
    func exportResult(_ result: DetectionResult, format: ExportFormat) throws -> URL {
        switch format {
        case .csv:
            return try exportToCSV(result)
        case .json:
            return try exportToJSON(result)
        case .pdf:
            return try exportToPDF(result)
        case .text:
            return try exportToText(result)
        }
    }

    /// Export nhiều kết quả đếm
    func exportResults(_ results: [DetectionResult], format: ExportFormat) throws -> URL {
        guard !results.isEmpty else {
            throw ExportError.noData
        }

        switch format {
        case .csv:
            return try exportMultipleToCSV(results)
        case .json:
            return try exportMultipleToJSON(results)
        case .pdf:
            return try exportMultipleToPDF(results)
        case .text:
            return try exportMultipleToText(results)
        }
    }

    // MARK: - CSV Export

    private func exportToCSV(_ result: DetectionResult) throws -> URL {
        var csv = "Label,Confidence,X,Y,Width,Height\n"

        for obj in result.objects {
            let box = obj.boundingBox
            csv += "\(obj.label),\(String(format: "%.3f", obj.confidence)),\(String(format: "%.3f", box.origin.x)),\(String(format: "%.3f", box.origin.y)),\(String(format: "%.3f", box.width)),\(String(format: "%.3f", box.height))\n"
        }

        return try saveToFile(csv, filename: "count_\(result.id).csv")
    }

    private func exportMultipleToCSV(_ results: [DetectionResult]) throws -> URL {
        var csv = "Timestamp,Label,Confidence,X,Y,Width,Height\n"

        for result in results {
            let timestamp = ISO8601DateFormatter().string(from: result.timestamp)
            for obj in result.objects {
                let box = obj.boundingBox
                csv += "\(timestamp),\(obj.label),\(String(format: "%.3f", obj.confidence)),\(String(format: "%.3f", box.origin.x)),\(String(format: "%.3f", box.origin.y)),\(String(format: "%.3f", box.width)),\(String(format: "%.3f", box.height))\n"
            }
        }

        return try saveToFile(csv, filename: "counts_batch.csv")
    }

    // MARK: - JSON Export

    private func exportToJSON(_ result: DetectionResult) throws -> URL {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        guard let data = try? encoder.encode(result) else {
            throw ExportError.encodingFailed
        }

        guard let json = String(data: data, encoding: .utf8) else {
            throw ExportError.encodingFailed
        }

        return try saveToFile(json, filename: "count_\(result.id).json")
    }

    private func exportMultipleToJSON(_ results: [DetectionResult]) throws -> URL {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        guard let data = try? encoder.encode(results) else {
            throw ExportError.encodingFailed
        }

        guard let json = String(data: data, encoding: .utf8) else {
            throw ExportError.encodingFailed
        }

        return try saveToFile(json, filename: "counts_batch.json")
    }

    // MARK: - Text Export

    private func exportToText(_ result: DetectionResult) throws -> URL {
        var text = "OpenCount Detection Report\n"
        text += "==========================\n\n"
        text += "Timestamp: \(formatDate(result.timestamp))\n"
        text += "Total Objects: \(result.totalCount)\n\n"

        let grouped = Dictionary(grouping: result.objects, by: { $0.label })

        text += "Summary by Type:\n"
        for (label, objects) in grouped.sorted(by: { $0.key < $1.key }) {
            text += "  \(label): \(objects.count)\n"
        }

        text += "\nDetailed Results:\n"
        for (index, obj) in result.objects.enumerated() {
            text += "\n\(index + 1). \(obj.label)\n"
            text += "   Confidence: \(String(format: "%.1f%%", obj.confidence * 100))\n"
            text += "   Position: (\(String(format: "%.3f", obj.boundingBox.origin.x)), "
            text += "\(String(format: "%.3f", obj.boundingBox.origin.y)))\n"
        }

        return try saveToFile(text, filename: "count_\(result.id).txt")
    }

    private func exportMultipleToText(_ results: [DetectionResult]) throws -> URL {
        var text = "OpenCount Batch Report\n"
        text += "======================\n\n"
        text += "Total Sessions: \(results.count)\n"
        text += "Total Objects Detected: \(results.reduce(0) { $0 + $1.totalCount })\n\n"

        for (index, result) in results.enumerated() {
            text += "\nSession \(index + 1)\n"
            text += "----------\n"
            text += "Timestamp: \(formatDate(result.timestamp))\n"
            text += "Objects: \(result.totalCount)\n"

            let grouped = Dictionary(grouping: result.objects, by: { $0.label })
            for (label, objects) in grouped.sorted(by: { $0.key < $1.key }) {
                text += "  \(label): \(objects.count)\n"
            }
        }

        return try saveToFile(text, filename: "counts_batch.txt")
    }

    // MARK: - PDF Export

    private func exportToPDF(_ result: DetectionResult) throws -> URL {
        let pdfMetaData = [
            kCGPDFContextCreator: "OpenCount",
            kCGPDFContextTitle: "Detection Report"
        ]

        let format = UIGraphicsPDFRendererFormat()
        format.documentInfo = pdfMetaData as [String: Any]

        let pageRect = CGRect(x: 0, y: 0, width: 595, height: 842) // A4
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect, format: format)

        let data = renderer.pdfData { context in
            context.beginPage()
            var yPosition: CGFloat = 50

            // Title
            let titleAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.boldSystemFont(ofSize: 24)
            ]
            let title = "OpenCount Detection Report"
            title.draw(at: CGPoint(x: 50, y: yPosition), withAttributes: titleAttributes)
            yPosition += 40

            // Metadata
            let metaAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 12)
            ]
            let timestamp = "Date: \(formatDate(result.timestamp))"
            timestamp.draw(at: CGPoint(x: 50, y: yPosition), withAttributes: metaAttributes)
            yPosition += 20

            let total = "Total Objects: \(result.totalCount)"
            total.draw(at: CGPoint(x: 50, y: yPosition), withAttributes: metaAttributes)
            yPosition += 40

            // Summary
            let summaryAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.boldSystemFont(ofSize: 14)
            ]
            let summary = "Summary by Type:"
            summary.draw(at: CGPoint(x: 50, y: yPosition), withAttributes: summaryAttributes)
            yPosition += 25

            let grouped = Dictionary(grouping: result.objects, by: { $0.label })
            let itemAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 11)
            ]

            for (label, objects) in grouped.sorted(by: { $0.key < $1.key }) {
                let item = "  • \(label): \(objects.count)"
                item.draw(at: CGPoint(x: 50, y: yPosition), withAttributes: itemAttributes)
                yPosition += 18

                if yPosition > 750 {
                    context.beginPage()
                    yPosition = 50
                }
            }
        }

        return try saveToFile(data, filename: "count_\(result.id).pdf")
    }

    private func exportMultipleToPDF(_ results: [DetectionResult]) throws -> URL {
        let pdfMetaData = [
            kCGPDFContextCreator: "OpenCount",
            kCGPDFContextTitle: "Batch Report"
        ]

        let format = UIGraphicsPDFRendererFormat()
        format.documentInfo = pdfMetaData as [String: Any]

        let pageRect = CGRect(x: 0, y: 0, width: 595, height: 842)
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect, format: format)

        let data = renderer.pdfData { context in
            context.beginPage()
            var yPosition: CGFloat = 50

            let titleAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.boldSystemFont(ofSize: 24)
            ]
            let title = "OpenCount Batch Report"
            title.draw(at: CGPoint(x: 50, y: yPosition), withAttributes: titleAttributes)
            yPosition += 40

            let metaAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 12)
            ]
            let summary = "Sessions: \(results.count) | Total Objects: \(results.reduce(0) { $0 + $1.totalCount })"
            summary.draw(at: CGPoint(x: 50, y: yPosition), withAttributes: metaAttributes)
            yPosition += 40

            for (index, result) in results.enumerated() {
                let sessionAttributes: [NSAttributedString.Key: Any] = [
                    .font: UIFont.boldSystemFont(ofSize: 12)
                ]
                let session = "Session \(index + 1) - \(formatDate(result.timestamp))"
                session.draw(at: CGPoint(x: 50, y: yPosition), withAttributes: sessionAttributes)
                yPosition += 20

                let itemAttributes: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 10)
                ]

                let grouped = Dictionary(grouping: result.objects, by: { $0.label })
                for (label, objects) in grouped.sorted(by: { $0.key < $1.key }) {
                    let item = "  • \(label): \(objects.count)"
                    item.draw(at: CGPoint(x: 50, y: yPosition), withAttributes: itemAttributes)
                    yPosition += 16

                    if yPosition > 750 {
                        context.beginPage()
                        yPosition = 50
                    }
                }

                yPosition += 15
            }
        }

        return try saveToFile(data, filename: "counts_batch.pdf")
    }

    // MARK: - File Management

    private func saveToFile(_ content: String, filename: String) throws -> URL {
        guard let data = content.data(using: .utf8) else {
            throw ExportError.encodingFailed
        }
        return try saveToFile(data, filename: filename)
    }

    private func saveToFile(_ data: Data, filename: String) throws -> URL {
        let fileManager = FileManager.default
        let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let fileURL = documentsURL.appendingPathComponent(filename)

        try data.write(to: fileURL, options: .atomic)
        return fileURL
    }

    // MARK: - Helpers

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .medium
        formatter.locale = Locale(identifier: "vi_VN")
        return formatter.string(from: date)
    }
}
