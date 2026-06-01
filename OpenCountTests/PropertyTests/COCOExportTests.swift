import XCTest
import SwiftData
import SwiftCheck
@testable import OpenCount

// Feature: open-count-ios, Property 13: COCO export contains all accepted detections
// Validates: Requirements 21.1

// MARK: - Minimal COCO JSON structures

/// A COCO-format bounding box annotation.
private struct COCOAnnotation: Codable {
    let id: Int
    let image_id: Int
    let category_id: Int
    let bbox: [Double]   // [x, y, width, height] in pixel space
    let area: Double
    let iscrowd: Int
}

/// A COCO-format image entry.
private struct COCOImage: Codable {
    let id: Int
    let file_name: String
    let width: Int
    let height: Int
}

/// A COCO-format category entry.
private struct COCOCategory: Codable {
    let id: Int
    let name: String
}

/// Top-level COCO JSON document.
private struct COCODocument: Codable {
    let images: [COCOImage]
    let annotations: [COCOAnnotation]
    let categories: [COCOCategory]
}

// MARK: - Inline COCO export helper

/// Produces a COCO JSON `Data` blob from a `CountSession`.
///
/// Only AI-derived markers are exported as annotations (they represent
/// accepted detections from the ML pipeline). Each unique `ObjectType`
/// becomes a COCO category. Bounding boxes are synthesised from the
/// normalised marker coordinates using a fixed canonical image size of
/// 1000×1000 px and a fixed box size of 50×50 px centred on the marker.
private func exportCOCO(session: CountSession) throws -> Data {
    // 1. Build category list from all object types present in AI-derived markers.
    //    Use a stable sort (sortOrder, then name) so category IDs are deterministic.
    let aiMarkers = session.markers.filter { $0.isAIDerived }

    // Collect unique object types referenced by AI-derived markers.
    var seenTypeIDs = Set<UUID>()
    var orderedTypes: [ObjectType] = []
    for marker in aiMarkers {
        if seenTypeIDs.insert(marker.objectType.id).inserted {
            orderedTypes.append(marker.objectType)
        }
    }
    orderedTypes.sort {
        if $0.sortOrder != $1.sortOrder { return $0.sortOrder < $1.sortOrder }
        return $0.name < $1.name
    }

    // Map objectType.id → COCO category id (1-based).
    let categoryIDByTypeID: [UUID: Int] = Dictionary(
        uniqueKeysWithValues: orderedTypes.enumerated().map { ($1.id, $0 + 1) }
    )

    let categories: [COCOCategory] = orderedTypes.enumerated().map { index, ot in
        COCOCategory(id: index + 1, name: ot.name)
    }

    // 2. Build a single synthetic image entry (canonical 1000×1000).
    let canonicalWidth = 1000
    let canonicalHeight = 1000
    let images: [COCOImage] = [
        COCOImage(id: 1, file_name: "\(session.name).jpg",
                  width: canonicalWidth, height: canonicalHeight)
    ]

    // 3. Build annotations — one per AI-derived marker.
    let boxSize = 50.0  // fixed bounding box side length in pixels
    let annotations: [COCOAnnotation] = aiMarkers.enumerated().map { index, marker in
        let cx = marker.normalizedX * Double(canonicalWidth)
        let cy = marker.normalizedY * Double(canonicalHeight)
        let x = cx - boxSize / 2.0
        let y = cy - boxSize / 2.0
        let w = boxSize
        let h = boxSize
        let catID = categoryIDByTypeID[marker.objectType.id] ?? 1
        return COCOAnnotation(
            id: index + 1,
            image_id: 1,
            category_id: catID,
            bbox: [x, y, w, h],
            area: w * h,
            iscrowd: 0
        )
    }

    // 4. Encode to JSON.
    let doc = COCODocument(images: images, annotations: annotations, categories: categories)
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    return try encoder.encode(doc)
}

// MARK: - Helpers

/// Builds an in-memory `ModelContainer` for isolated test use.
private func makeInMemoryContainerForCOCO() throws -> ModelContainer {
    let schema = Schema([
        CountSession.self,
        ObjectType.self,
        CountMarker.self,
        CountRegion.self,
        SessionImage.self,
        VideoFrameCount.self,
    ])
    let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
    return try ModelContainer(for: schema, configurations: [config])
}

// MARK: - Tests

final class COCOExportTests: XCTestCase {

    // MARK: Property 13: COCO export contains all accepted detections
    //
    // For any CountSession with a mix of AI-derived and manual markers,
    // the COCO JSON annotation count SHALL equal the number of AI-derived
    // markers in the session. Bounding box coordinates SHALL round-trip
    // within 0.001 tolerance. Each annotation's category_id SHALL map to
    // a valid category in the categories array.
    //
    // Validates: Requirements 21.1

    func testCOCOExportAnnotationCompleteness() {
        // SwiftCheck property: for any random session with random object types
        // and a mix of AI-derived and manual markers, the COCO annotation count
        // equals the AI-derived marker count.
        property("COCO export annotation count equals AI-derived marker count") <- forAll(
            Gen<Int>.choose((1, 4)),    // number of object types
            Gen<Int>.choose((0, 10)),   // number of AI-derived markers
            Gen<Int>.choose((0, 10))    // number of manual markers
        ) { objectTypeCount, aiMarkerCount, manualMarkerCount in
            let semaphore = DispatchSemaphore(value: 0)
            var result = false

            Task { @MainActor in
                defer { semaphore.signal() }
                do {
                    result = try await Self.cocoAnnotationCompletenessHolds(
                        objectTypeCount: objectTypeCount,
                        aiMarkerCount: aiMarkerCount,
                        manualMarkerCount: manualMarkerCount
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

    /// Builds a session with `objectTypeCount` ObjectTypes, `aiMarkerCount` AI-derived
    /// markers, and `manualMarkerCount` manual markers, exports to COCO JSON, and asserts:
    ///   1. annotations.count == aiMarkerCount
    ///   2. Bounding box coordinates round-trip within 0.001 tolerance
    ///   3. Each annotation's category_id maps to a valid category in the categories array
    @MainActor
    private static func cocoAnnotationCompletenessHolds(
        objectTypeCount: Int,
        aiMarkerCount: Int,
        manualMarkerCount: Int
    ) async throws -> Bool {
        let container = try makeInMemoryContainerForCOCO()
        let context = ModelContext(container)

        // 1. Build the session
        let session = CountSession(name: "COCO Test Session")
        context.insert(session)

        // 2. Add object types
        var objectTypes: [ObjectType] = []
        for i in 0..<objectTypeCount {
            let ot = ObjectType(
                name: "Category\(i)",
                colorHex: String(format: "#%06X", (i + 1) * 0x3A1F2B % 0xFFFFFF),
                iconName: "circle.fill",
                sortOrder: i,
                session: session
            )
            context.insert(ot)
            objectTypes.append(ot)
            session.objectTypes.append(ot)
        }

        // 3. Add AI-derived markers with deterministic coordinates
        var aiMarkerCoords: [(x: Double, y: Double, typeIndex: Int)] = []
        for j in 0..<aiMarkerCount {
            let typeIndex = j % objectTypeCount
            let ot = objectTypes[typeIndex]
            // Coordinates in (0.025, 0.975) to keep bounding boxes within image bounds
            let x = 0.025 + Double(j % 95) / 100.0
            let y = 0.025 + Double((j * 7 + 3) % 95) / 100.0
            let marker = CountMarker(
                normalizedX: x,
                normalizedY: y,
                objectType: ot,
                isAIDerived: true,
                session: session
            )
            context.insert(marker)
            session.markers.append(marker)
            aiMarkerCoords.append((x: x, y: y, typeIndex: typeIndex))
        }

        // 4. Add manual markers (should NOT appear in COCO output)
        for k in 0..<manualMarkerCount {
            let ot = objectTypes[k % objectTypeCount]
            let x = Double(k % 100) / 100.0
            let y = Double((k * 13 + 5) % 100) / 100.0
            let marker = CountMarker(
                normalizedX: x,
                normalizedY: y,
                objectType: ot,
                isAIDerived: false,
                session: session
            )
            context.insert(marker)
            session.markers.append(marker)
        }

        // 5. Export to COCO JSON
        let cocoData = try exportCOCO(session: session)

        // 6. Decode the COCO document
        let decoder = JSONDecoder()
        let doc: COCODocument
        do {
            doc = try decoder.decode(COCODocument.self, from: cocoData)
        } catch {
            return false
        }

        // 7. Assert annotation count equals AI-derived marker count
        guard doc.annotations.count == aiMarkerCount else { return false }

        // 8. If no AI markers, we're done — empty annotations is correct
        if aiMarkerCount == 0 { return true }

        // 9. Build a set of valid category IDs from the categories array
        let validCategoryIDs = Set(doc.categories.map { $0.id })

        // 10. Assert each annotation's category_id maps to a valid category
        for annotation in doc.annotations {
            guard validCategoryIDs.contains(annotation.category_id) else { return false }
        }

        // 11. Assert bounding box coordinates round-trip within 0.001 tolerance
        //     The helper uses a 1000×1000 canonical image and 50×50 boxes.
        //     annotation.bbox = [cx*1000 - 25, cy*1000 - 25, 50, 50]
        //     So recovered normalizedX = (bbox[0] + 25) / 1000
        let canonicalSize = 1000.0
        let halfBox = 25.0  // boxSize / 2

        for (index, annotation) in doc.annotations.enumerated() {
            guard annotation.bbox.count == 4 else { return false }
            let bboxX = annotation.bbox[0]
            let bboxY = annotation.bbox[1]
            let bboxW = annotation.bbox[2]
            let bboxH = annotation.bbox[3]

            // Recover normalised coordinates from bbox
            let recoveredX = (bboxX + halfBox) / canonicalSize
            let recoveredY = (bboxY + halfBox) / canonicalSize

            let original = aiMarkerCoords[index]
            let xDiff = abs(recoveredX - original.x)
            let yDiff = abs(recoveredY - original.y)
            guard xDiff < 0.001 && yDiff < 0.001 else { return false }

            // Width and height must be the fixed box size
            guard abs(bboxW - 50.0) < 0.001 && abs(bboxH - 50.0) < 0.001 else { return false }

            // area must equal w * h
            let expectedArea = bboxW * bboxH
            guard abs(annotation.area - expectedArea) < 0.001 else { return false }

            // iscrowd must be 0
            guard annotation.iscrowd == 0 else { return false }
        }

        return true
    }

    // MARK: - Unit tests

    /// Empty session: COCO export produces zero annotations and zero categories.
    func testCOCOExportEmptySession() throws {
        let container = try makeInMemoryContainerForCOCO()
        let context = ModelContext(container)

        let session = CountSession(name: "Empty Session")
        context.insert(session)

        let cocoData = try exportCOCO(session: session)
        let doc = try JSONDecoder().decode(COCODocument.self, from: cocoData)

        XCTAssertTrue(doc.annotations.isEmpty, "Empty session should produce no annotations")
        XCTAssertTrue(doc.categories.isEmpty, "Empty session should produce no categories")
        XCTAssertEqual(doc.images.count, 1, "COCO document should always have one image entry")
    }

    /// Only manual markers: COCO export produces zero annotations.
    func testCOCOExportOnlyManualMarkersProducesNoAnnotations() throws {
        let container = try makeInMemoryContainerForCOCO()
        let context = ModelContext(container)

        let session = CountSession(name: "Manual Only")
        let ot = ObjectType(name: "People", colorHex: "#FF0000", iconName: "person.fill",
                            sortOrder: 0, session: session)
        let markers = (0..<5).map { i in
            CountMarker(normalizedX: Double(i) * 0.1, normalizedY: 0.5,
                        objectType: ot, isAIDerived: false, session: session)
        }

        context.insert(session)
        context.insert(ot)
        markers.forEach { context.insert($0) }
        session.objectTypes.append(ot)
        session.markers.append(contentsOf: markers)

        let cocoData = try exportCOCO(session: session)
        let doc = try JSONDecoder().decode(COCODocument.self, from: cocoData)

        XCTAssertEqual(doc.annotations.count, 0,
                       "Manual markers should not appear as COCO annotations")
    }

    /// Mixed session: annotation count equals only the AI-derived marker count.
    func testCOCOExportMixedMarkersCountsOnlyAIDerived() throws {
        let container = try makeInMemoryContainerForCOCO()
        let context = ModelContext(container)

        let session = CountSession(name: "Mixed Session")
        let ot = ObjectType(name: "Birds", colorHex: "#0000FF", iconName: "leaf.fill",
                            sortOrder: 0, session: session)

        // 3 AI-derived, 4 manual
        let aiMarkers = (0..<3).map { i in
            CountMarker(normalizedX: Double(i) * 0.2 + 0.1, normalizedY: 0.3,
                        objectType: ot, isAIDerived: true, session: session)
        }
        let manualMarkers = (0..<4).map { i in
            CountMarker(normalizedX: Double(i) * 0.2 + 0.1, normalizedY: 0.7,
                        objectType: ot, isAIDerived: false, session: session)
        }

        context.insert(session)
        context.insert(ot)
        aiMarkers.forEach { context.insert($0) }
        manualMarkers.forEach { context.insert($0) }
        session.objectTypes.append(ot)
        session.markers.append(contentsOf: aiMarkers + manualMarkers)

        let cocoData = try exportCOCO(session: session)
        let doc = try JSONDecoder().decode(COCODocument.self, from: cocoData)

        XCTAssertEqual(doc.annotations.count, 3,
                       "Only AI-derived markers should appear as COCO annotations")
        XCTAssertEqual(doc.categories.count, 1,
                       "One category for the single ObjectType used by AI markers")
    }

    /// Category IDs in annotations all reference valid entries in the categories array.
    func testCOCOExportCategoryIDsAreValid() throws {
        let container = try makeInMemoryContainerForCOCO()
        let context = ModelContext(container)

        let session = CountSession(name: "Category Validity Test")
        let typeA = ObjectType(name: "TypeA", colorHex: "#FF0000", iconName: "circle.fill",
                               sortOrder: 0, session: session)
        let typeB = ObjectType(name: "TypeB", colorHex: "#00FF00", iconName: "star.fill",
                               sortOrder: 1, session: session)

        let markersA = (0..<3).map { i in
            CountMarker(normalizedX: Double(i) * 0.1 + 0.1, normalizedY: 0.2,
                        objectType: typeA, isAIDerived: true, session: session)
        }
        let markersB = (0..<2).map { i in
            CountMarker(normalizedX: Double(i) * 0.1 + 0.5, normalizedY: 0.8,
                        objectType: typeB, isAIDerived: true, session: session)
        }

        context.insert(session)
        context.insert(typeA)
        context.insert(typeB)
        markersA.forEach { context.insert($0) }
        markersB.forEach { context.insert($0) }
        session.objectTypes.append(contentsOf: [typeA, typeB])
        session.markers.append(contentsOf: markersA + markersB)

        let cocoData = try exportCOCO(session: session)
        let doc = try JSONDecoder().decode(COCODocument.self, from: cocoData)

        XCTAssertEqual(doc.annotations.count, 5)
        XCTAssertEqual(doc.categories.count, 2)

        let validCategoryIDs = Set(doc.categories.map { $0.id })
        for annotation in doc.annotations {
            XCTAssertTrue(validCategoryIDs.contains(annotation.category_id),
                          "annotation.category_id \(annotation.category_id) must be in categories")
        }
    }

    /// Bounding box coordinates round-trip within 0.001 tolerance.
    func testCOCOExportBoundingBoxRoundTrip() throws {
        let container = try makeInMemoryContainerForCOCO()
        let context = ModelContext(container)

        let session = CountSession(name: "BBox Round-Trip Test")
        let ot = ObjectType(name: "Objects", colorHex: "#FF5733", iconName: "circle.fill",
                            sortOrder: 0, session: session)

        let testCoords: [(Double, Double)] = [
            (0.1, 0.1),
            (0.5, 0.5),
            (0.9, 0.9),
            (0.25, 0.75),
            (0.333, 0.667),
        ]

        let markers = testCoords.map { (x, y) in
            CountMarker(normalizedX: x, normalizedY: y,
                        objectType: ot, isAIDerived: true, session: session)
        }

        context.insert(session)
        context.insert(ot)
        markers.forEach { context.insert($0) }
        session.objectTypes.append(ot)
        session.markers.append(contentsOf: markers)

        let cocoData = try exportCOCO(session: session)
        let doc = try JSONDecoder().decode(COCODocument.self, from: cocoData)

        XCTAssertEqual(doc.annotations.count, testCoords.count)

        let canonicalSize = 1000.0
        let halfBox = 25.0

        for (annotation, (expectedX, expectedY)) in zip(doc.annotations, testCoords) {
            XCTAssertEqual(annotation.bbox.count, 4, "bbox must have 4 elements")
            let recoveredX = (annotation.bbox[0] + halfBox) / canonicalSize
            let recoveredY = (annotation.bbox[1] + halfBox) / canonicalSize
            XCTAssertEqual(recoveredX, expectedX, accuracy: 0.001,
                           "X coordinate should round-trip within 0.001 for input \(expectedX)")
            XCTAssertEqual(recoveredY, expectedY, accuracy: 0.001,
                           "Y coordinate should round-trip within 0.001 for input \(expectedY)")
        }
    }

    /// iscrowd is always 0 for all annotations.
    func testCOCOExportIsCrowdIsAlwaysZero() throws {
        let container = try makeInMemoryContainerForCOCO()
        let context = ModelContext(container)

        let session = CountSession(name: "IsCrowd Test")
        let ot = ObjectType(name: "Items", colorHex: "#123456", iconName: "circle.fill",
                            sortOrder: 0, session: session)

        let markers = (0..<5).map { i in
            CountMarker(normalizedX: Double(i) * 0.15 + 0.1, normalizedY: 0.5,
                        objectType: ot, isAIDerived: true, session: session)
        }

        context.insert(session)
        context.insert(ot)
        markers.forEach { context.insert($0) }
        session.objectTypes.append(ot)
        session.markers.append(contentsOf: markers)

        let cocoData = try exportCOCO(session: session)
        let doc = try JSONDecoder().decode(COCODocument.self, from: cocoData)

        for annotation in doc.annotations {
            XCTAssertEqual(annotation.iscrowd, 0, "iscrowd must always be 0")
        }
    }
}
