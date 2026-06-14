import XCTest
import SwiftCheck
@testable import OpenCount

// Feature: open-count-ios, Property 5: CSV export round-trip preserves session data
// Validates: Requirements 12.1

// MARK: - Helpers

/// Generates a random normalized coordinate in [0.0, 1.0].
private let csvNormalizedCoordGen: Gen<Double> = Gen<Double>.choose((0.0, 1.0))

/// Generates a random hex color string like "#RRGGBB".
private let csvHexColorGen: Gen<String> = Gen<UInt32>.choose((0, 0xFFFFFF)).map {
    String(format: "#%06X", $0)
}

/// Generates a safe object type name (no commas, quotes, or newlines to keep CSV parsing simple).
/// Uses alphanumeric characters and spaces only.
private let safeObjectTypeNameGen: Gen<String> = Gen<Int>.choose((1, 12)).flatMap { length in
    let chars = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789 ")
    return sequence(Array(repeating: Gen<Character>.fromElements(of: chars), count: length))
        .map { String($0).trimmingCharacters(in: .whitespaces) }
        .suchThat { !$0.isEmpty }
}

// MARK: - CSV Parsing helpers

/// Parsed representation of a single CSV row.
private struct CSVRow {
    let objectType: String
    let tally: Int
    let markerX: Double
    let markerY: Double
    let regionName: String
    let timestamp: String
    let isAIDerived: Bool
}

/// Minimal RFC 4180-aware CSV field parser.
private func parseCSVField(_ scanner: inout Substring) -> String {
    if scanner.first == "\"" {
        // Quoted field
        scanner.removeFirst() // consume opening quote
        var result = ""
        while !scanner.isEmpty {
            if scanner.first == "\"" {
                scanner.removeFirst()
                if scanner.first == "\"" {
                    // Escaped quote
                    result.append("\"")
                    scanner.removeFirst()
                } else {
                    break // closing quote
                }
            } else {
                result.append(scanner.removeFirst())
            }
        }
        // Consume trailing comma if present
        if scanner.first == "," { scanner.removeFirst() }
        return result
    } else {
        // Unquoted field: read until comma or end
        if let commaIdx = scanner.firstIndex(of: ",") {
            let field = String(scanner[scanner.startIndex..<commaIdx])
            scanner = scanner[scanner.index(after: commaIdx)...]
            return field
        } else {
            let field = String(scanner)
            scanner = scanner[scanner.endIndex...]
            return field
        }
    }
}

/// Parses a CSV line into its 7 fields.
private func parseCSVLine(_ line: String) -> CSVRow? {
    var remaining = line[...]
    var fields: [String] = []
    while !remaining.isEmpty || fields.count < 7 {
        fields.append(parseCSVField(&remaining))
        if fields.count == 7 { break }
    }
    guard fields.count == 7,
          let tally = Int(fields[1]),
          let x = Double(fields[2]),
          let y = Double(fields[3]) else { return nil }
    return CSVRow(
        objectType: fields[0],
        tally: tally,
        markerX: x,
        markerY: y,
        regionName: fields[4],
        timestamp: fields[5],
        isAIDerived: fields[6] == "true"
    )
}

/// Parses the full CSV data produced by `ExportService.exportCSV(session:)`.
/// Returns an array of `CSVRow` (header row is skipped by position).
///
/// Note: The header row is now localized via `LocalizationManager.localizedExportHeader`,
/// so we skip it by index rather than checking for a hardcoded English string.
private func parseCSV(_ data: Data) -> [CSVRow]? {
    guard let text = String(data: data, encoding: .utf8) else { return nil }
    let lines = text.components(separatedBy: "\n")
    // Must have at least a header row
    guard !lines.isEmpty else { return nil }
    // Skip the first line (header) and parse the rest
    return lines.dropFirst().filter { !$0.isEmpty }.compactMap { parseCSVLine($0) }
}

// MARK: - Tests

final class CSVExportTests: XCTestCase {

    // MARK: Property 5: CSV export round-trip preserves session data
    //
    // For any valid CountSession, serializing to CSV and parsing back SHALL
    // produce the same Object_Type names, tallies, and marker coordinates
    // (within 1e-5 precision, matching the %.6f format used in the export).
    //
    // Validates: Requirements 12.1

    func testCSVExportRoundTripPreservesSessionData() {
        // SwiftCheck property: for any random session with random object types
        // and markers, the CSV export round-trip preserves object type names,
        // tallies, and marker coordinates.
        property("CSV export round-trip preserves object type names, tallies, and marker coordinates") <- forAll(
            Gen<Int>.choose((1, 4)),    // number of object types (at least 1)
            Gen<Int>.choose((0, 15))    // number of markers
        ) { objectTypeCount, markerCount in
            let semaphore = DispatchSemaphore(value: 0)
            var result = false

            Task { @MainActor in
                defer { semaphore.signal() }
                do {
                    result = try await Self.csvRoundTripPropertyHolds(
                        objectTypeCount: objectTypeCount,
                        markerCount: markerCount
                    )
                } catch {
                    result = false
                }
            }

            semaphore.wait()
            return result
        }
    }

    // MARK: - Core property helper

    /// Builds a session with `objectTypeCount` Object_Types and `markerCount` markers,
    /// exports to CSV, parses back, and asserts:
    ///   1. The number of CSV rows equals the number of markers.
    ///   2. For each object type, the tally in every CSV row matches the actual count.
    ///   3. Marker coordinates round-trip within 1e-5 precision.
    ///   4. Object type names are preserved exactly.
    @MainActor
    private static func csvRoundTripPropertyHolds(
        objectTypeCount: Int,
        markerCount: Int
    ) async throws -> Bool {
        // 1. Build the session
        let session = CountSession(name: "CSV Round-Trip Test")

        // 2. Add object types with deterministic safe names
        var objectTypes: [ObjectType] = []
        for i in 0..<objectTypeCount {
            let ot = ObjectType(
                name: "ObjectType\(i)",
                colorHex: String(format: "#%06X", (i + 1) * 0x3A1F2B % 0xFFFFFF),
                iconName: "circle.fill",
                sortOrder: i,
                session: session
            )
            objectTypes.append(ot)
            session.objectTypes.append(ot)
        }

        // 3. Add markers distributed across object types
        var originalMarkers: [(objectTypeID: UUID, objectTypeName: String, x: Double, y: Double)] = []
        for j in 0..<markerCount {
            let ot = objectTypes[j % objectTypeCount]
            // Use varied coordinates to exercise the full range
            let x = Double(j % 100) / 100.0
            let y = Double((j * 7 + 3) % 100) / 100.0
            let marker = CountMarker(
                normalizedX: x,
                normalizedY: y,
                objectType: ot,
                isAIDerived: j % 3 == 0,
                session: session
            )
            session.markers.append(marker)
            originalMarkers.append((objectTypeID: ot.id, objectTypeName: ot.name, x: x, y: y))
        }

        // 4. Compute expected tallies per object type
        var expectedTallies: [UUID: Int] = [:]
        for ot in objectTypes {
            expectedTallies[ot.id] = session.markers.filter { $0.objectType.id == ot.id }.count
        }

        // 5. Export to CSV
        let exportService = ExportService()
        let csvData = try exportService.exportCSV(session: session)

        // 6. Parse CSV back
        guard let rows = parseCSV(csvData) else { return false }

        // 7. Assert row count matches marker count
        guard rows.count == markerCount else { return false }

        // 8. If no markers, we're done — empty session exports correctly
        if markerCount == 0 { return true }

        // 9. Assert each row's tally matches the expected tally for its object type
        //    and that object type names are preserved
        let objectTypesByName: [String: UUID] = Dictionary(
            uniqueKeysWithValues: objectTypes.map { ($0.name, $0.id) }
        )

        for row in rows {
            // Object type name must be one of the known names
            guard let typeID = objectTypesByName[row.objectType] else { return false }

            // Tally in the CSV row must match the actual count
            guard let expectedTally = expectedTallies[typeID],
                  row.tally == expectedTally else { return false }
        }

        // 10. Assert marker coordinates round-trip within 1e-5 precision
        //     Match rows to original markers by position in the export order
        //     (ExportService iterates session.markers in order)
        for (index, row) in rows.enumerated() {
            let original = originalMarkers[index]
            let xDiff = abs(row.markerX - original.x)
            let yDiff = abs(row.markerY - original.y)
            guard xDiff < 1e-5 && yDiff < 1e-5 else { return false }

            // Also verify the object type name matches the original marker's type
            guard row.objectType == original.objectTypeName else { return false }
        }

        return true
    }

    // MARK: - Unit tests

    /// CSV header row is present and contains the expected (English) localized column names.
    func testCSVExportHasCorrectHeader() async throws {
        let session = CountSession(name: "Header Test")

        let csvData = try ExportService().exportCSV(session: session)
        let text = try XCTUnwrap(String(data: csvData, encoding: .utf8))
        let firstLine = text.components(separatedBy: "\n").first ?? ""

        // Build the expected header using the same LocalizationManager path
        // so the test stays in sync with the implementation.
        let expectedHeader = [
            ExportColumn.objectType, .tally, .markerX, .markerY,
            .regionName, .timestamp, .isAIDerived
        ]
        .map { LocalizationManager.localizedExportHeader(for: $0) }
        .joined(separator: ",")

        XCTAssertEqual(firstLine, expectedHeader)
    }

    /// Empty session exports only the header row.
    func testCSVExportEmptySessionProducesOnlyHeader() async throws {
        let session = CountSession(name: "Empty Session")

        let csvData = try ExportService().exportCSV(session: session)
        let rows = try XCTUnwrap(parseCSV(csvData))
        XCTAssertTrue(rows.isEmpty, "Empty session should produce no data rows")
    }

    /// Single marker: tally is 1, coordinates are preserved.
    func testCSVExportSingleMarkerRoundTrip() async throws {
        let session = CountSession(name: "Single Marker")
        let objectType = ObjectType(
            name: "People",
            colorHex: "#FF0000",
            iconName: "person.fill",
            sortOrder: 0,
            session: session
        )
        let marker = CountMarker(
            normalizedX: 0.123456,
            normalizedY: 0.654321,
            objectType: objectType,
            isAIDerived: false,
            session: session
        )
        session.objectTypes.append(objectType)
        session.markers.append(marker)

        let csvData = try ExportService().exportCSV(session: session)
        let rows = try XCTUnwrap(parseCSV(csvData))

        XCTAssertEqual(rows.count, 1)
        let row = try XCTUnwrap(rows.first)
        XCTAssertEqual(row.objectType, "People")
        XCTAssertEqual(row.tally, 1)
        XCTAssertEqual(row.markerX, 0.123456, accuracy: 1e-5)
        XCTAssertEqual(row.markerY, 0.654321, accuracy: 1e-5)
        XCTAssertFalse(row.isAIDerived)
    }

    /// Multiple object types: each row's tally reflects the correct per-type count.
    func testCSVExportTalliesAreCorrectPerObjectType() async throws {
        let session = CountSession(name: "Multi-Type Tally Test")
        let typeA = ObjectType(name: "TypeA", colorHex: "#FF0000", iconName: "circle.fill", sortOrder: 0, session: session)
        let typeB = ObjectType(name: "TypeB", colorHex: "#00FF00", iconName: "star.fill", sortOrder: 1, session: session)

        // 3 markers for TypeA, 2 for TypeB
        let markersA = (0..<3).map { i in
            CountMarker(normalizedX: Double(i) * 0.1, normalizedY: 0.1, objectType: typeA, session: session)
        }
        let markersB = (0..<2).map { i in
            CountMarker(normalizedX: Double(i) * 0.1, normalizedY: 0.9, objectType: typeB, session: session)
        }

        session.objectTypes.append(contentsOf: [typeA, typeB])
        session.markers.append(contentsOf: markersA + markersB)

        let csvData = try ExportService().exportCSV(session: session)
        let rows = try XCTUnwrap(parseCSV(csvData))

        XCTAssertEqual(rows.count, 5)

        let rowsA = rows.filter { $0.objectType == "TypeA" }
        let rowsB = rows.filter { $0.objectType == "TypeB" }

        XCTAssertEqual(rowsA.count, 3)
        XCTAssertEqual(rowsB.count, 2)

        // Every TypeA row should report tally = 3
        for row in rowsA {
            XCTAssertEqual(row.tally, 3, "TypeA tally should be 3 in every row")
        }
        // Every TypeB row should report tally = 2
        for row in rowsB {
            XCTAssertEqual(row.tally, 2, "TypeB tally should be 2 in every row")
        }
    }

    /// AI-derived flag is preserved in the CSV round-trip.
    func testCSVExportPreservesAIDerivedFlag() async throws {
        let session = CountSession(name: "AI Flag Test")
        let objectType = ObjectType(name: "Birds", colorHex: "#0000FF", iconName: "leaf.fill", sortOrder: 0, session: session)

        let humanMarker = CountMarker(normalizedX: 0.2, normalizedY: 0.3, objectType: objectType, isAIDerived: false, session: session)
        let aiMarker = CountMarker(normalizedX: 0.7, normalizedY: 0.8, objectType: objectType, isAIDerived: true, session: session)

        session.objectTypes.append(objectType)
        session.markers.append(contentsOf: [humanMarker, aiMarker])

        let csvData = try ExportService().exportCSV(session: session)
        let rows = try XCTUnwrap(parseCSV(csvData))

        XCTAssertEqual(rows.count, 2)
        // First marker is human-placed
        XCTAssertFalse(rows[0].isAIDerived, "First marker should not be AI-derived")
        // Second marker is AI-derived
        XCTAssertTrue(rows[1].isAIDerived, "Second marker should be AI-derived")
    }

    /// Marker coordinates are preserved within 1e-5 precision across the full [0,1] range.
    func testCSVExportCoordinatePrecision() async throws {
        let session = CountSession(name: "Coordinate Precision Test")
        let objectType = ObjectType(name: "Dots", colorHex: "#FF5733", iconName: "circle.fill", sortOrder: 0, session: session)

        let testCoords: [(Double, Double)] = [
            (0.0, 0.0),
            (1.0, 1.0),
            (0.5, 0.5),
            (0.123456, 0.987654),
            (0.999999, 0.000001),
        ]

        let markers = testCoords.map { (x, y) in
            CountMarker(normalizedX: x, normalizedY: y, objectType: objectType, session: session)
        }

        session.objectTypes.append(objectType)
        session.markers.append(contentsOf: markers)

        let csvData = try ExportService().exportCSV(session: session)
        let rows = try XCTUnwrap(parseCSV(csvData))

        XCTAssertEqual(rows.count, testCoords.count)
        for (row, (expectedX, expectedY)) in zip(rows, testCoords) {
            XCTAssertEqual(row.markerX, expectedX, accuracy: 1e-5,
                           "X coordinate should round-trip within 1e-5 for input \(expectedX)")
            XCTAssertEqual(row.markerY, expectedY, accuracy: 1e-5,
                           "Y coordinate should round-trip within 1e-5 for input \(expectedY)")
        }
    }
}

// MARK: - SwiftCheck helper

/// Sequences a list of generators into a generator of lists.
private func sequence<T>(_ gens: [Gen<T>]) -> Gen<[T]> {
    guard !gens.isEmpty else { return Gen.pure([]) }
    return gens.reduce(Gen.pure([])) { acc, gen in
        acc.flatMap { list in
            gen.map { element in list + [element] }
        }
    }
}
