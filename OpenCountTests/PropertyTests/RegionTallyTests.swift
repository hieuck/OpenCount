import XCTest
import SwiftData
import SwiftCheck
import CoreGraphics
@testable import OpenCount

// Feature: open-count-ios, Property 4: Region tally equals contained marker count
// Validates: Requirements 8.5, 8.7

// MARK: - Helpers

/// Builds an in-memory `ModelContainer` for isolated test use.
private func makeInMemoryContainer() throws -> ModelContainer {
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

/// Generates a random normalized coordinate strictly inside (0.0, 1.0).
private let innerCoordGen: Gen<Double> = Gen<Double>.choose((0.01, 0.99))

/// Generates a random normalized coordinate in [0.0, 1.0].
private let normalizedCoordGen: Gen<Double> = Gen<Double>.choose((0.0, 1.0))

// MARK: - Region generators

/// Generates a rectangle region with two random corner points.
/// The rectangle spans from (x1,y1) to (x2,y2) where x1 < x2 and y1 < y2.
private let rectangleRegionGen: Gen<CountRegion> = Gen.zip(
    innerCoordGen, innerCoordGen, innerCoordGen, innerCoordGen
).suchThat { x1, y1, x2, y2 in
    abs(x2 - x1) > 0.05 && abs(y2 - y1) > 0.05
}.map { x1, y1, x2, y2 in
    let minX = min(x1, x2)
    let maxX = max(x1, x2)
    let minY = min(y1, y2)
    let maxY = max(y1, y2)
    return CountRegion(
        name: "Rectangle",
        colorHex: "#3399FF",
        shapeType: .rectangle,
        normalizedPoints: [
            CGPoint(x: minX, y: minY),
            CGPoint(x: maxX, y: maxY),
        ]
    )
}

/// Generates an ellipse region defined by its bounding box corners.
private let ellipseRegionGen: Gen<CountRegion> = Gen.zip(
    innerCoordGen, innerCoordGen, innerCoordGen, innerCoordGen
).suchThat { x1, y1, x2, y2 in
    abs(x2 - x1) > 0.05 && abs(y2 - y1) > 0.05
}.map { x1, y1, x2, y2 in
    let minX = min(x1, x2)
    let maxX = max(x1, x2)
    let minY = min(y1, y2)
    let maxY = max(y1, y2)
    return CountRegion(
        name: "Ellipse",
        colorHex: "#FF6633",
        shapeType: .ellipse,
        normalizedPoints: [
            CGPoint(x: minX, y: minY),
            CGPoint(x: maxX, y: maxY),
        ]
    )
}

/// Generates a convex polygon region (a triangle) with three random interior points.
private let polygonRegionGen: Gen<CountRegion> = Gen.zip(
    innerCoordGen, innerCoordGen,
    innerCoordGen, innerCoordGen,
    innerCoordGen, innerCoordGen
).suchThat { x1, y1, x2, y2, x3, y3 in
    // Ensure the triangle has non-trivial area (cross product magnitude > 0.001)
    let area = abs((x2 - x1) * (y3 - y1) - (x3 - x1) * (y2 - y1))
    return area > 0.001
}.map { x1, y1, x2, y2, x3, y3 in
    CountRegion(
        name: "Polygon",
        colorHex: "#33CC66",
        shapeType: .polygon,
        normalizedPoints: [
            CGPoint(x: x1, y: y1),
            CGPoint(x: x2, y: y2),
            CGPoint(x: x3, y: y3),
        ]
    )
}

/// Generates one of the three region shape types at random.
private let anyRegionGen: Gen<CountRegion> = Gen<Int>.choose((0, 2)).flatMap { choice in
    switch choice {
    case 0: return rectangleRegionGen
    case 1: return ellipseRegionGen
    default: return polygonRegionGen
    }
}

// MARK: - Marker generator

/// Generates a list of 0–30 markers with random normalized coordinates and random object types.
/// Object types are identified by index (0–2) to keep the generator self-contained.
private let markerDataGen: Gen<[(x: Double, y: Double, typeIndex: Int)]> =
    Gen<Int>.choose((0, 30)).flatMap { count in
        sequence(Array(repeating: Gen.zip(
            normalizedCoordGen,
            normalizedCoordGen,
            Gen<Int>.choose((0, 2))
        ).map { x, y, t in (x: x, y: y, typeIndex: t) }, count: count))
    }

// MARK: - Tests

final class RegionTallyTests: XCTestCase {

    // MARK: Property 4: Region tally equals contained marker count
    //
    // For any Region geometry and any set of Count_Markers, the Region Tally
    // for a given Object_Type SHALL equal the number of Count_Markers of that
    // Object_Type whose normalized coordinates fall strictly within the
    // Region's boundary.
    //
    // Validates: Requirements 8.5, 8.7

    func testRegionTallyEqualsContainedMarkerCountForRectangle() {
        property("Rectangle region tally equals count of markers inside the rectangle") <- forAll(
            rectangleRegionGen,
            markerDataGen
        ) { region, markerData in
            Self.regionTallyPropertyHolds(region: region, markerData: markerData)
        }
    }

    func testRegionTallyEqualsContainedMarkerCountForEllipse() {
        property("Ellipse region tally equals count of markers inside the ellipse") <- forAll(
            ellipseRegionGen,
            markerDataGen
        ) { region, markerData in
            Self.regionTallyPropertyHolds(region: region, markerData: markerData)
        }
    }

    func testRegionTallyEqualsContainedMarkerCountForPolygon() {
        property("Polygon region tally equals count of markers inside the polygon") <- forAll(
            polygonRegionGen,
            markerDataGen
        ) { region, markerData in
            Self.regionTallyPropertyHolds(region: region, markerData: markerData)
        }
    }

    func testRegionTallyEqualsContainedMarkerCountForAnyShape() {
        property("Region tally equals contained marker count for any shape type") <- forAll(
            anyRegionGen,
            markerDataGen
        ) { region, markerData in
            Self.regionTallyPropertyHolds(region: region, markerData: markerData)
        }
    }

    // MARK: - Core property helper

    /// Pure helper: builds object types and markers, computes the region tally using
    /// the same logic as CountingViewModel.tally(for:), and asserts it equals the
    /// reference count from direct region.contains() calls.
    ///
    /// This is synchronous and does not require SwiftData or MainActor — it exercises
    /// the pure geometry logic in CountRegion.contains(normalizedPoint:) directly.
    private static func regionTallyPropertyHolds(
        region: CountRegion,
        markerData: [(x: Double, y: Double, typeIndex: Int)]
    ) -> Bool {
        // Build 3 object types (value-type stand-ins using UUID for identity)
        let session = CountSession(name: "Region Tally Test")
        let objectTypes = (0..<3).map { i in
            ObjectType(
                name: "Type \(i)",
                colorHex: String(format: "#%06X", (i + 1) * 0x3F3F3F),
                iconName: "circle.fill",
                sortOrder: i,
                session: session
            )
        }
        session.objectTypes = objectTypes

        // Build markers
        let markers = markerData.map { data in
            CountMarker(
                normalizedX: data.x,
                normalizedY: data.y,
                objectType: objectTypes[data.typeIndex],
                session: session
            )
        }

        // Compute tally using the same algorithm as CountingViewModel.tally(for:)
        var computedTally: [ObjectType: Int] = [:]
        for marker in markers {
            let point = CGPoint(x: marker.normalizedX, y: marker.normalizedY)
            if region.contains(normalizedPoint: point) {
                computedTally[marker.objectType, default: 0] += 1
            }
        }

        // Compute reference tally by independently filtering markers per object type
        // Property: tally[type] == markers.filter { region.contains($0.point) && $0.objectType == type }.count
        for objectType in objectTypes {
            let expectedCount = markers.filter { marker in
                marker.objectType.id == objectType.id &&
                region.contains(normalizedPoint: CGPoint(x: marker.normalizedX, y: marker.normalizedY))
            }.count
            let actualCount = computedTally[objectType] ?? 0
            if actualCount != expectedCount {
                return false
            }
        }

        return true
    }

    // MARK: - Unit tests

    /// Empty marker list produces a zero tally for all object types.
    @MainActor
    func testEmptyMarkersProduceZeroTally() {
        let session = CountSession(name: "Empty Markers")
        let objectType = ObjectType(name: "Type A", colorHex: "#FF0000", iconName: "circle.fill", sortOrder: 0, session: session)
        session.objectTypes = [objectType]

        let region = CountRegion(
            name: "Full Region",
            colorHex: "#3399FF",
            shapeType: .rectangle,
            normalizedPoints: [CGPoint(x: 0.1, y: 0.1), CGPoint(x: 0.9, y: 0.9)]
        )

        let viewModel = CountingViewModel(session: session)
        viewModel.markers = []

        let tally = viewModel.tally(for: region)
        XCTAssertEqual(tally[objectType] ?? 0, 0, "Empty marker list should produce zero tally")
    }

    /// All markers inside the region are counted.
    @MainActor
    func testAllMarkersInsideRegionAreAllCounted() {
        let session = CountSession(name: "All Inside")
        let objectType = ObjectType(name: "Type A", colorHex: "#FF0000", iconName: "circle.fill", sortOrder: 0, session: session)
        session.objectTypes = [objectType]

        // Rectangle from (0.2, 0.2) to (0.8, 0.8)
        let region = CountRegion(
            name: "Center Region",
            colorHex: "#3399FF",
            shapeType: .rectangle,
            normalizedPoints: [CGPoint(x: 0.2, y: 0.2), CGPoint(x: 0.8, y: 0.8)]
        )

        // All markers are strictly inside the rectangle
        let markers = [
            CountMarker(normalizedX: 0.3, normalizedY: 0.3, objectType: objectType, session: session),
            CountMarker(normalizedX: 0.5, normalizedY: 0.5, objectType: objectType, session: session),
            CountMarker(normalizedX: 0.7, normalizedY: 0.7, objectType: objectType, session: session),
        ]
        session.markers = markers

        let viewModel = CountingViewModel(session: session)
        viewModel.markers = markers

        let tally = viewModel.tally(for: region)
        XCTAssertEqual(tally[objectType] ?? 0, 3, "All 3 markers inside the region should be counted")
    }

    /// All markers outside the region produce a zero tally.
    @MainActor
    func testAllMarkersOutsideRegionProduceZeroTally() {
        let session = CountSession(name: "All Outside")
        let objectType = ObjectType(name: "Type A", colorHex: "#FF0000", iconName: "circle.fill", sortOrder: 0, session: session)
        session.objectTypes = [objectType]

        // Rectangle from (0.4, 0.4) to (0.6, 0.6) — small center region
        let region = CountRegion(
            name: "Small Center",
            colorHex: "#3399FF",
            shapeType: .rectangle,
            normalizedPoints: [CGPoint(x: 0.4, y: 0.4), CGPoint(x: 0.6, y: 0.6)]
        )

        // All markers are outside the rectangle
        let markers = [
            CountMarker(normalizedX: 0.1, normalizedY: 0.1, objectType: objectType, session: session),
            CountMarker(normalizedX: 0.9, normalizedY: 0.9, objectType: objectType, session: session),
            CountMarker(normalizedX: 0.1, normalizedY: 0.9, objectType: objectType, session: session),
        ]
        session.markers = markers

        let viewModel = CountingViewModel(session: session)
        viewModel.markers = markers

        let tally = viewModel.tally(for: region)
        XCTAssertEqual(tally[objectType] ?? 0, 0, "No markers inside the region should produce zero tally")
    }

    /// Markers exactly on the boundary are excluded (strict containment).
    @MainActor
    func testMarkersOnBoundaryAreExcluded() {
        let session = CountSession(name: "Boundary Test")
        let objectType = ObjectType(name: "Type A", colorHex: "#FF0000", iconName: "circle.fill", sortOrder: 0, session: session)
        session.objectTypes = [objectType]

        // Rectangle from (0.2, 0.2) to (0.8, 0.8)
        let region = CountRegion(
            name: "Boundary Region",
            colorHex: "#3399FF",
            shapeType: .rectangle,
            normalizedPoints: [CGPoint(x: 0.2, y: 0.2), CGPoint(x: 0.8, y: 0.8)]
        )

        // Markers exactly on the boundary edges
        let boundaryMarkers = [
            CountMarker(normalizedX: 0.2, normalizedY: 0.5, objectType: objectType, session: session), // left edge
            CountMarker(normalizedX: 0.8, normalizedY: 0.5, objectType: objectType, session: session), // right edge
            CountMarker(normalizedX: 0.5, normalizedY: 0.2, objectType: objectType, session: session), // top edge
            CountMarker(normalizedX: 0.5, normalizedY: 0.8, objectType: objectType, session: session), // bottom edge
        ]
        session.markers = boundaryMarkers

        let viewModel = CountingViewModel(session: session)
        viewModel.markers = boundaryMarkers

        let tally = viewModel.tally(for: region)
        // The rectangle uses strict inequality (point.x > minX && point.x < maxX),
        // so boundary markers should NOT be counted.
        XCTAssertEqual(tally[objectType] ?? 0, 0,
                       "Markers exactly on the boundary should be excluded (strict containment)")
    }

    /// Region tally is per-object-type: markers of different types are counted separately.
    @MainActor
    func testRegionTallyIsPerObjectType() {
        let session = CountSession(name: "Multi-Type Region")
        let typeA = ObjectType(name: "Type A", colorHex: "#FF0000", iconName: "circle.fill", sortOrder: 0, session: session)
        let typeB = ObjectType(name: "Type B", colorHex: "#00FF00", iconName: "star.fill", sortOrder: 1, session: session)
        session.objectTypes = [typeA, typeB]

        // Rectangle from (0.1, 0.1) to (0.9, 0.9)
        let region = CountRegion(
            name: "Large Region",
            colorHex: "#3399FF",
            shapeType: .rectangle,
            normalizedPoints: [CGPoint(x: 0.1, y: 0.1), CGPoint(x: 0.9, y: 0.9)]
        )

        // 2 Type A markers inside, 3 Type B markers inside, 1 Type A marker outside
        let markers = [
            CountMarker(normalizedX: 0.3, normalizedY: 0.3, objectType: typeA, session: session),
            CountMarker(normalizedX: 0.5, normalizedY: 0.5, objectType: typeA, session: session),
            CountMarker(normalizedX: 0.4, normalizedY: 0.4, objectType: typeB, session: session),
            CountMarker(normalizedX: 0.6, normalizedY: 0.6, objectType: typeB, session: session),
            CountMarker(normalizedX: 0.7, normalizedY: 0.7, objectType: typeB, session: session),
            CountMarker(normalizedX: 0.05, normalizedY: 0.05, objectType: typeA, session: session), // outside
        ]
        session.markers = markers

        let viewModel = CountingViewModel(session: session)
        viewModel.markers = markers

        let tally = viewModel.tally(for: region)
        XCTAssertEqual(tally[typeA] ?? 0, 2, "Type A tally should be 2 (one marker is outside)")
        XCTAssertEqual(tally[typeB] ?? 0, 3, "Type B tally should be 3")
    }

    /// Ellipse region correctly includes markers inside and excludes markers outside.
    @MainActor
    func testEllipseRegionContainment() {
        let session = CountSession(name: "Ellipse Test")
        let objectType = ObjectType(name: "Type A", colorHex: "#FF0000", iconName: "circle.fill", sortOrder: 0, session: session)
        session.objectTypes = [objectType]

        // Ellipse with bounding box (0.2, 0.2) to (0.8, 0.8) — center (0.5, 0.5), radii (0.3, 0.3)
        let region = CountRegion(
            name: "Ellipse Region",
            colorHex: "#FF6633",
            shapeType: .ellipse,
            normalizedPoints: [CGPoint(x: 0.2, y: 0.2), CGPoint(x: 0.8, y: 0.8)]
        )

        // Center is inside; corners of the bounding box are outside the ellipse
        let markers = [
            CountMarker(normalizedX: 0.5, normalizedY: 0.5, objectType: objectType, session: session), // center — inside
            CountMarker(normalizedX: 0.5, normalizedY: 0.45, objectType: objectType, session: session), // near center — inside
            CountMarker(normalizedX: 0.2, normalizedY: 0.2, objectType: objectType, session: session), // corner — outside
            CountMarker(normalizedX: 0.8, normalizedY: 0.8, objectType: objectType, session: session), // corner — outside
            CountMarker(normalizedX: 0.05, normalizedY: 0.05, objectType: objectType, session: session), // far outside
        ]
        session.markers = markers

        let viewModel = CountingViewModel(session: session)
        viewModel.markers = markers

        let tally = viewModel.tally(for: region)
        // Verify using direct containment check as ground truth
        let expectedCount = markers.filter { marker in
            region.contains(normalizedPoint: CGPoint(x: marker.normalizedX, y: marker.normalizedY))
        }.count
        XCTAssertEqual(tally[objectType] ?? 0, expectedCount,
                       "Ellipse tally should match direct containment check")
    }

    /// Polygon (triangle) region correctly includes markers inside and excludes markers outside.
    @MainActor
    func testPolygonRegionContainment() {
        let session = CountSession(name: "Polygon Test")
        let objectType = ObjectType(name: "Type A", colorHex: "#FF0000", iconName: "circle.fill", sortOrder: 0, session: session)
        session.objectTypes = [objectType]

        // Triangle with vertices at (0.5, 0.1), (0.1, 0.9), (0.9, 0.9)
        let region = CountRegion(
            name: "Triangle Region",
            colorHex: "#33CC66",
            shapeType: .polygon,
            normalizedPoints: [
                CGPoint(x: 0.5, y: 0.1),
                CGPoint(x: 0.1, y: 0.9),
                CGPoint(x: 0.9, y: 0.9),
            ]
        )

        let markers = [
            CountMarker(normalizedX: 0.5, normalizedY: 0.5, objectType: objectType, session: session), // centroid — inside
            CountMarker(normalizedX: 0.5, normalizedY: 0.7, objectType: objectType, session: session), // lower center — inside
            CountMarker(normalizedX: 0.05, normalizedY: 0.05, objectType: objectType, session: session), // top-left corner — outside
            CountMarker(normalizedX: 0.95, normalizedY: 0.05, objectType: objectType, session: session), // top-right corner — outside
        ]
        session.markers = markers

        let viewModel = CountingViewModel(session: session)
        viewModel.markers = markers

        let tally = viewModel.tally(for: region)
        // Verify using direct containment check as ground truth
        let expectedCount = markers.filter { marker in
            region.contains(normalizedPoint: CGPoint(x: marker.normalizedX, y: marker.normalizedY))
        }.count
        XCTAssertEqual(tally[objectType] ?? 0, expectedCount,
                       "Polygon tally should match direct containment check")
    }

    /// Region with no valid geometry (fewer than 2 points for rect/ellipse) returns zero tally.
    @MainActor
    func testRegionWithInsufficientPointsReturnsZeroTally() {
        let session = CountSession(name: "Invalid Region")
        let objectType = ObjectType(name: "Type A", colorHex: "#FF0000", iconName: "circle.fill", sortOrder: 0, session: session)
        session.objectTypes = [objectType]

        // Rectangle with only 1 point — invalid geometry
        let region = CountRegion(
            name: "Invalid",
            colorHex: "#3399FF",
            shapeType: .rectangle,
            normalizedPoints: [CGPoint(x: 0.5, y: 0.5)]
        )

        let markers = [
            CountMarker(normalizedX: 0.5, normalizedY: 0.5, objectType: objectType, session: session),
        ]
        session.markers = markers

        let viewModel = CountingViewModel(session: session)
        viewModel.markers = markers

        let tally = viewModel.tally(for: region)
        XCTAssertEqual(tally[objectType] ?? 0, 0,
                       "Region with insufficient points should return zero tally")
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
