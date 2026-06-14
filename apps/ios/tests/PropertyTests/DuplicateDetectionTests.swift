import XCTest
import SwiftCheck
@testable import OpenCount

// Feature: open-count-ios, Property 15: Duplicate detection radius is symmetric
// Validates: Requirements 35.1

/// Tests that `SmartCountService.isDuplicate` is symmetric:
/// if placing marker A near B triggers a duplicate warning,
/// then placing B near A also triggers a duplicate warning.
///
/// Also tests the basic correctness of the duplicate detection logic.
final class DuplicateDetectionTests: XCTestCase {

    private let service = SmartCountService()

    // MARK: - Helpers

    /// Creates a minimal ObjectType with a given id for testing.
    private func makeObjectType(id: UUID = UUID()) -> ObjectType {
        let session = CountSession(name: "Test")
        let ot = ObjectType(name: "Test", colorHex: "#FF0000", iconName: "circle", sortOrder: 0, session: session)
        return ot
    }

    /// Creates a CountMarker at a normalized position.
    private func makeMarker(x: Double, y: Double, objectType: ObjectType) -> CountMarker {
        let session = CountSession(name: "Test")
        return CountMarker(normalizedX: x, normalizedY: y, objectType: objectType, session: session)
    }

    // MARK: - Property 15: Duplicate detection radius is symmetric

    /// For any two points A and B of the same ObjectType,
    /// isDuplicate(A, [B]) == isDuplicate(B, [A]).
    ///
    /// Distance is commutative, so the result must be identical in both directions.
    func testDuplicateDetectionIsSymmetric() {
        // SwiftCheck property: for any two normalized points (clamped to [0,1]),
        // the duplicate check is symmetric.
        property("isDuplicate is symmetric for any two points of the same ObjectType") <- forAll(
            Gen<Double>.choose((0.0, 1.0)),  // ax
            Gen<Double>.choose((0.0, 1.0)),  // ay
            Gen<Double>.choose((0.0, 1.0)),  // bx
            Gen<Double>.choose((0.0, 1.0))   // by
        ) { ax, ay, bx, by in
            let objectType = self.makeObjectType()
            let pointA = CGPoint(x: ax, y: ay)
            let pointB = CGPoint(x: bx, y: by)

            let markerAtA = self.makeMarker(x: ax, y: ay, objectType: objectType)
            let markerAtB = self.makeMarker(x: bx, y: by, objectType: objectType)

            // isDuplicate(B near A) should equal isDuplicate(A near B)
            let bNearA = self.service.isDuplicate(
                newPoint: pointB,
                existingMarkers: [markerAtA],
                objectType: objectType
            )
            let aNearB = self.service.isDuplicate(
                newPoint: pointA,
                existingMarkers: [markerAtB],
                objectType: objectType
            )

            return bNearA == aNearB
        }
    }

    // MARK: - Unit tests for basic correctness

    /// A point placed exactly on an existing marker should be a duplicate.
    func testExactOverlapIsDuplicate() {
        let ot = makeObjectType()
        let existing = makeMarker(x: 0.5, y: 0.5, objectType: ot)
        let isDup = service.isDuplicate(
            newPoint: CGPoint(x: 0.5, y: 0.5),
            existingMarkers: [existing],
            objectType: ot
        )
        XCTAssertTrue(isDup, "Exact overlap should be detected as duplicate")
    }

    /// A point just inside the default radius (0.02) should be a duplicate.
    func testPointInsideRadiusIsDuplicate() {
        let ot = makeObjectType()
        let existing = makeMarker(x: 0.5, y: 0.5, objectType: ot)
        // Place new point 0.01 away (inside default radius of 0.02)
        let isDup = service.isDuplicate(
            newPoint: CGPoint(x: 0.51, y: 0.5),
            existingMarkers: [existing],
            objectType: ot
        )
        XCTAssertTrue(isDup, "Point inside radius should be detected as duplicate")
    }

    /// A point just outside the default radius should NOT be a duplicate.
    func testPointOutsideRadiusIsNotDuplicate() {
        let ot = makeObjectType()
        let existing = makeMarker(x: 0.5, y: 0.5, objectType: ot)
        // Place new point 0.03 away (outside default radius of 0.02)
        let isDup = service.isDuplicate(
            newPoint: CGPoint(x: 0.53, y: 0.5),
            existingMarkers: [existing],
            objectType: ot
        )
        XCTAssertFalse(isDup, "Point outside radius should not be detected as duplicate")
    }

    /// A point near a marker of a DIFFERENT ObjectType should NOT be a duplicate.
    func testDifferentObjectTypeIsNotDuplicate() {
        let session = CountSession(name: "Test")
        let ot1 = ObjectType(name: "A", colorHex: "#FF0000", iconName: "circle", sortOrder: 0, session: session)
        let ot2 = ObjectType(name: "B", colorHex: "#0000FF", iconName: "square", sortOrder: 1, session: session)

        let existing = makeMarker(x: 0.5, y: 0.5, objectType: ot1)
        // New point is near existing but belongs to a different type
        let isDup = service.isDuplicate(
            newPoint: CGPoint(x: 0.51, y: 0.5),
            existingMarkers: [existing],
            objectType: ot2  // different type
        )
        XCTAssertFalse(isDup, "Different ObjectType should not trigger duplicate warning")
    }

    /// Empty marker list should never produce a duplicate.
    func testEmptyMarkersNeverDuplicate() {
        property("isDuplicate with empty markers always returns false") <- forAll(
            Gen<Double>.choose((0.0, 1.0)),
            Gen<Double>.choose((0.0, 1.0))
        ) { x, y in
            let ot = self.makeObjectType()
            return !self.service.isDuplicate(
                newPoint: CGPoint(x: x, y: y),
                existingMarkers: [],
                objectType: ot
            )
        }
    }

    /// Custom radius: a point at exactly the radius boundary should NOT be a duplicate
    /// (strict less-than comparison).
    func testExactRadiusBoundaryIsNotDuplicate() {
        let ot = makeObjectType()
        let existing = makeMarker(x: 0.0, y: 0.0, objectType: ot)
        let radius = 0.05
        // Point at exactly the radius distance
        let isDup = service.isDuplicate(
            newPoint: CGPoint(x: radius, y: 0.0),
            existingMarkers: [existing],
            objectType: ot,
            duplicateRadius: radius
        )
        XCTAssertFalse(isDup, "Point at exactly the radius boundary should not be a duplicate (strict <)")
    }

    // MARK: - CountingVelocityTracker tests

    /// Velocity tracker starts at zero.
    func testVelocityTrackerStartsAtZero() {
        let tracker = CountingVelocityTracker()
        XCTAssertEqual(tracker.currentVelocity, 0.0)
    }

    /// Recording placements increases velocity.
    func testVelocityIncreasesWithPlacements() {
        let tracker = CountingVelocityTracker()
        for _ in 0..<10 {
            tracker.recordPlacement()
        }
        XCTAssertEqual(tracker.currentVelocity, 10.0)
    }

    /// Reset clears all timestamps.
    func testVelocityTrackerReset() {
        let tracker = CountingVelocityTracker()
        for _ in 0..<20 {
            tracker.recordPlacement()
        }
        tracker.reset()
        XCTAssertEqual(tracker.currentVelocity, 0.0)
    }
}
