import Foundation

// MARK: - ExportColumn

/// Represents a column in a CSV export, a label in a PDF report, or a field
/// description in a JSON export. Used by `LocalizationManager.localizedExportHeader`
/// to produce locale-aware header strings.
///
/// Requirement 30.4, 30.6, 30.7
enum ExportColumn: String, CaseIterable {
    // CSV / JSON shared fields
    case objectType     = "export.column.object_type"
    case tally          = "export.column.tally"
    case markerX        = "export.column.marker_x"
    case markerY        = "export.column.marker_y"
    case regionName     = "export.column.region_name"
    case timestamp      = "export.column.timestamp"
    case isAIDerived    = "export.column.is_ai_derived"

    // JSON-only session metadata fields
    case sessionID      = "export.column.session_id"
    case sessionName    = "export.column.session_name"
    case description    = "export.column.description"
    case createdAt      = "export.column.created_at"
    case modifiedAt     = "export.column.modified_at"

    // PDF labels
    case pdfTitle           = "export.pdf.title"
    case pdfLastModified    = "export.pdf.last_modified"
    case pdfTotalMarkers    = "export.pdf.total_markers"
    case pdfObjectTypeTallies = "export.pdf.object_type_tallies"
}

// MARK: - LocalizationManager

/// Thin wrapper ensuring locale-aware formatting throughout the app.
///
/// All methods use the device's current `Locale` so that numbers, dates, and
/// density values are presented in the format the user expects.
///
/// Requirement 30.3: locale-aware number, date, and density formatters.
/// Requirement 30.4: localized CSV headers, PDF labels, JSON field descriptions.
/// Requirement 30.7: locale-aware export headers.
enum LocalizationManager {

    // MARK: - Formatters (lazily created, cached as static lets)

    /// Locale-aware integer number formatter.
    /// e.g. 1234 → "1,234" (en-US), "1.234" (de-DE), "١٬٢٣٤" (ar)
    private static let countFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.locale = .current
        return f
    }()

    /// Locale-aware medium-style date formatter.
    /// e.g. "Jan 5, 2025" (en-US), "5 janv. 2025" (fr-FR)
    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .none
        f.locale = .current
        return f
    }()

    // MARK: - Public API

    /// Returns a locale-aware string representation of an integer count.
    ///
    /// - Parameter value: The integer count to format.
    /// - Returns: A locale-formatted string, e.g. `"1,234"` for en-US.
    static func formattedCount(_ value: Int) -> String {
        countFormatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }

    /// Returns a locale-aware medium-style date string.
    ///
    /// - Parameter date: The date to format.
    /// - Returns: A locale-formatted date string, e.g. `"Jan 5, 2025"` for en-US.
    static func formattedDate(_ date: Date) -> String {
        dateFormatter.string(from: date)
    }

    /// Returns a locale-aware density string in the form `"3.14 /100px²"`.
    ///
    /// The numeric part is formatted with up to 2 decimal places using the
    /// current locale's decimal separator.
    ///
    /// - Parameter value: The density value (count per 100 normalized square pixels).
    /// - Returns: A formatted density string.
    static func formattedDensity(_ value: Double) -> String {
        let densityFormatter = NumberFormatter()
        densityFormatter.numberStyle = .decimal
        densityFormatter.maximumFractionDigits = 2
        densityFormatter.minimumFractionDigits = 0
        densityFormatter.locale = .current
        let numStr = densityFormatter.string(from: NSNumber(value: value)) ?? String(format: "%.2f", value)
        // The unit suffix is intentionally not localized — it is a mathematical notation.
        return "\(numStr) /100px²"
    }

    /// Returns the localized header string for the given `ExportColumn`.
    ///
    /// Strings are looked up in the `ExportHeaders` strings table, which is
    /// provided in `Localizable.xcstrings` (String Catalog) for all supported
    /// locales. Falls back to the raw key if no translation is found.
    ///
    /// - Parameter column: The export column whose header to localize.
    /// - Returns: A localized header string suitable for use in CSV, PDF, or JSON exports.
    static func localizedExportHeader(for column: ExportColumn) -> String {
        NSLocalizedString(column.rawValue, tableName: "ExportHeaders", bundle: .main, comment: "")
    }
}
