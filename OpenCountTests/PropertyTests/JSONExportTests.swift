import XCTest
import SwiftCheck
@testable import OpenCount

// Feature: open-count-ios, Property 6: JSON export round-trip preserves session data
// Validates: Requirements 12.2

// MARK: - Helpers

/// Generates a random normalized coordinate in [0.0, 1.0].
private let jsonNormalizedCoordGen: Gen<Double> = Gen<Double>.choose((0.0, 1.0))

/// Generates a random hex color string like "#RRGGBB".
private let jsonHexColorGen: Gen<String> = Gen<UInt32>.choose((0, 0xFFFFFF)).map {
    String(format: "#%06X", $0)
}

/// Generates a safe object type name (alphanumeric and spaces only).
private let jsonSafeObjectTypeNameGen: Gen<String> = Gen<Int>.choose((1, 12)).flatMap { length in
    let chars = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789 ")
    return sequence(Array(repeating: Gen<Character>.fromElements(of: chars), count: length))
        .map { String($0).trimmingCharacters(in: .whitespaces) }
        .suchThat { !$0.isEmpty }
}

// MARK: - Tests

final class JSONExportTests: XCTestCase {

    // MARK: Property 6: JSON export round-trip preserves session data
    //
    // For any valid CountSession, encoding to JSON and decoding back SHALL
    // produce the same session id, name, objectType names and colorHex values,
    // marker coordinates (within 1e-5 precision), and isAIDerived flags.
    //
    // Validates: Requirements 12.2

    func testJSONExportRoundTripPreservesSessionData() {
        // SwiftCheck property: for any random session with random object types
        // and markers, the JSON export round-trip preserves structural equivalence.
        property("JSON export round-trip preserves session id, name, objectTypes, and marker data") <- forAll(
            Gen<Int>.choose((1, 4)),    // number of object types (at least 1)
            Gen<Int>.choose((0, 15))    // number of markers
        ) { objectTypeCount, markerCount in
            let semaphore = DispatchSemaphore(value: 0)
            var result = false

            Task { @MainActor in
                defer { semaphore.signal() }
                do {
                    result = try await Self.jsonRoundTripPropertyHolds(
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

    /// Builds a session with `objectTypeCount` ObjectTypes and `markerCount` markers,
    /// exports to JSON, decodes back to `SessionExportDTO`, and asserts:
    ///   1. Session id and name are preserved.
    ///   2. Number of objectTypes matches.
    ///   3. ObjectType names and colorHex values are preserved.
    ///   4. Number of markers matches.
    ///   5. Marker coordinates round-trip within 1e-5 precision.
    ///   6. isAIDerived flag is preserved for each marker.
    @MainActor
    private static func jsonRoundTripPropertyHolds(
        objectTypeCount: Int,
        markerCount: Int
    ) async throws -> Bool {
        // 1. Build the session
        let sessionID = UUID()
        let sessionName = "JSON Round-Trip Test \(sessionID.uuidString.prefix(8))"
        let session = CountSession(id: sessionID, name: sessionName)

        // 2. Add object types with deterministic safe names and colors
        var objectTypes: [ObjectType] = []
        for i in 0..<objectTypeCount {
            let colorValue = (i + 1) * 0x3A1F2B % 0xFFFFFF
            let ot = ObjectType(
                name: "ObjectType\(i)",
                colorHex: String(format: "#%06X", colorValue),
                iconName: "circle.fill",
                sortOrder: i,
                session: session
            )
            objectTypes.append(ot)
            session.objectTypes.append(ot)
        }

        // 3. Add markers distributed across object types
        var originalMarkers: [(id: UUID, objectTypeID: UUID, x: Double, y: Double, isAIDerived: Bool)] = []
        for j in 0..<markerCount {
            let ot = objectTypes[j % objectTypeCount]
            let x = Double(j % 100) / 100.0
            let y = Double((j * 7 + 3) % 100) / 100.0
            let aiDerived = j % 3 == 0
            let markerID = UUID()
            let marker = CountMarker(
                id: markerID,
                normalizedX: x,
                normalizedY: y,
                objectType: ot,
                isAIDerived: aiDerived,
                session: session
            )
            session.markers.append(marker)
            originalMarkers.append((id: markerID, objectTypeID: ot.id, x: x, y: y, isAIDerived: aiDerived))
        }

        // 4. Export to JSON
        let exportService = ExportService()
        let jsonData = try exportService.exportJSON(session: session)

        // 5. Decode back to SessionExportDTO
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let dto: SessionExportDTO
        do {
            dto = try decoder.decode(SessionExportDTO.self, from: jsonData)
        } catch {
            return false
        }

        // 6. Assert session id and name are preserved
        guard dto.id == sessionID else { return false }
        guard dto.name == sessionName else { return false }

        // 7. Assert number of objectTypes matches
        guard dto.objectTypes.count == objectTypeCount else { return false }

        // 8. Assert objectType names and colorHex values are preserved
        let originalTypesByID: [UUID: ObjectType] = Dictionary(
            uniqueKeysWithValues: objectTypes.map { ($0.id, $0) }
        )
        for dtoType in dto.objectTypes {
            guard let original = originalTypesByID[dtoType.id] else { return false }
            guard dtoType.name == original.name else { return false }
            guard dtoType.colorHex == original.colorHex else { return false }
        }

        // 9. Assert number of markers matches
        guard dto.markers.count == markerCount else { return false }

        // 10. If no markers, we're done — empty session exports correctly
        if markerCount == 0 { return true }

        // 11. Build a lookup from marker id to original marker data
        let originalMarkersByID: [UUID: (objectTypeID: UUID, x: Double, y: Double, isAIDerived: Bool)] =
            Dictionary(uniqueKeysWithValues: originalMarkers.map {
                ($0.id, (objectTypeID: $0.objectTypeID, x: $0.x, y: $0.y, isAIDerived: $0.isAIDerived))
            })

        // 12. Assert marker coordinates and isAIDerived flag round-trip correctly
        for dtoMarker in dto.markers {
            guard let original = originalMarkersByID[dtoMarker.id] else { return false }

            // Coordinates must round-trip within 1e-5 precision
            let xDiff = abs(dtoMarker.normalizedX - original.x)
            let yDiff = abs(dtoMarker.normalizedY - original.y)
            guard xDiff < 1e-5 && yDiff < 1e-5 else { return false }

            // isAIDerived flag must be preserved exactly
            guard dtoMarker.isAIDerived == original.isAIDerived else { return false }

            // objectTypeID must be preserved
            guard dtoMarker.objectTypeID == original.objectTypeID else { return false }
        }

        return true
    }

    // MARK: - Unit tests

    /// Empty session: JSON encodes and decodes with zero objectTypes and zero markers.
    func testJSONExportEmptySession() async throws {
        let sessionID = UUID()
        let session = CountSession(id: sessionID, name: "Empty Session")

        let jsonData = try ExportService().exportJSON(session: session)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let dto = try decoder.decode(SessionExportDTO.self, from: jsonData)

        XCTAssertEqual(dto.id, sessionID)
        XCTAssertEqual(dto.name, "Empty Session")
        XCTAssertTrue(dto.objectTypes.isEmpty, "Empty session should have no objectTypes")
        XCTAssertTrue(dto.markers.isEmpty, "Empty session should have no markers")
        XCTAssertTrue(dto.regions.isEmpty, "Empty session should have no regions")
    }

    /// Single marker: coordinates, objectTypeID, and isAIDerived are preserved.
    func testJSONExportSingleMarkerRoundTrip() async throws {
        let session = CountSession(name: "Single Marker")
        let objectType = ObjectType(
            name: "People",
            colorHex: "#FF0000",
            iconName: "person.fill",
            sortOrder: 0,
            session: session
        )
        let markerID = UUID()
        let marker = CountMarker(
            id: markerID,
            normalizedX: 0.123456,
            normalizedY: 0.654321,
            objectType: objectType,
            isAIDerived: false,
            session: session
        )

        session.objectTypes.append(objectType)
        session.markers.append(marker)

        let jsonData = try ExportService().exportJSON(session: session)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let dto = try decoder.decode(SessionExportDTO.self, from: jsonData)

        XCTAssertEqual(dto.markers.count, 1)
        let dtoMarker = try XCTUnwrap(dto.markers.first)
        XCTAssertEqual(dtoMarker.id, markerID)
        XCTAssertEqual(dtoMarker.normalizedX, 0.123456, accuracy: 1e-5)
        XCTAssertEqual(dtoMarker.normalizedY, 0.654321, accuracy: 1e-5)
        XCTAssertEqual(dtoMarker.objectTypeID, objectType.id)
        XCTAssertFalse(dtoMarker.isAIDerived)
    }

    /// Multiple object types: all names and colorHex values are preserved in the DTO.
    func testJSONExportMultipleObjectTypes() async throws {
        let session = CountSession(name: "Multi-Type Test")
        let typeA = ObjectType(name: "TypeA", colorHex: "#FF0000", iconName: "circle.fill", sortOrder: 0, session: session)
        let typeB = ObjectType(name: "TypeB", colorHex: "#00FF00", iconName: "star.fill", sortOrder: 1, session: session)
        let typeC = ObjectType(name: "TypeC", colorHex: "#0000FF", iconName: "leaf.fill", sortOrder: 2, session: session)

        session.objectTypes.append(contentsOf: [typeA, typeB, typeC])

        let jsonData = try ExportService().exportJSON(session: session)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let dto = try decoder.decode(SessionExportDTO.self, from: jsonData)

        XCTAssertEqual(dto.objectTypes.count, 3)

        let dtoTypesByID = Dictionary(uniqueKeysWithValues: dto.objectTypes.map { ($0.id, $0) })

        let dtoA = try XCTUnwrap(dtoTypesByID[typeA.id])
        XCTAssertEqual(dtoA.name, "TypeA")
        XCTAssertEqual(dtoA.colorHex, "#FF0000")

        let dtoB = try XCTUnwrap(dtoTypesByID[typeB.id])
        XCTAssertEqual(dtoB.name, "TypeB")
        XCTAssertEqual(dtoB.colorHex, "#00FF00")

        let dtoC = try XCTUnwrap(dtoTypesByID[typeC.id])
        XCTAssertEqual(dtoC.name, "TypeC")
        XCTAssertEqual(dtoC.colorHex, "#0000FF")
    }

    /// AI-derived flag is preserved for both human-placed and AI-derived markers.
    func testJSONExportPreservesAIDerivedFlag() async throws {
        let session = CountSession(name: "AI Flag Test")
        let objectType = ObjectType(
            name: "Birds",
            colorHex: "#0000FF",
            iconName: "leaf.fill",
            sortOrder: 0,
            session: session
        )

        let humanMarkerID = UUID()
        let aiMarkerID = UUID()
        let humanMarker = CountMarker(
            id: humanMarkerID,
            normalizedX: 0.2,
            normalizedY: 0.3,
            objectType: objectType,
            isAIDerived: false,
            session: session
        )
        let aiMarker = CountMarker(
            id: aiMarkerID,
            normalizedX: 0.7,
            normalizedY: 0.8,
            objectType: objectType,
            isAIDerived: true,
            session: session
        )

        session.objectTypes.append(objectType)
        session.markers.append(contentsOf: [humanMarker, aiMarker])

        let jsonData = try ExportService().exportJSON(session: session)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let dto = try decoder.decode(SessionExportDTO.self, from: jsonData)

        XCTAssertEqual(dto.markers.count, 2)

        let dtoMarkersByID = Dictionary(uniqueKeysWithValues: dto.markers.map { ($0.id, $0) })

        let dtoHuman = try XCTUnwrap(dtoMarkersByID[humanMarkerID])
        XCTAssertFalse(dtoHuman.isAIDerived, "Human-placed marker should not be AI-derived")

        let dtoAI = try XCTUnwrap(dtoMarkersByID[aiMarkerID])
        XCTAssertTrue(dtoAI.isAIDerived, "AI-derived marker should have isAIDerived = true")
    }

    /// Session description is preserved (both nil and non-nil cases).
    func testJSONExportPreservesSessionDescription() async throws {
        // Session with description
        let sessionWithDesc = CountSession(
            name: "Described Session",
            sessionDescription: "A test description"
        )
        // Session without description
        let sessionNoDesc = CountSession(name: "No Description Session")

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let jsonWithDesc = try ExportService().exportJSON(session: sessionWithDesc)
        let dtoWithDesc = try decoder.decode(SessionExportDTO.self, from: jsonWithDesc)
        XCTAssertEqual(dtoWithDesc.description, "A test description")

        let jsonNoDesc = try ExportService().exportJSON(session: sessionNoDesc)
        let dtoNoDesc = try decoder.decode(SessionExportDTO.self, from: jsonNoDesc)
        XCTAssertNil(dtoNoDesc.description, "Session without description should decode to nil")
    }
}
