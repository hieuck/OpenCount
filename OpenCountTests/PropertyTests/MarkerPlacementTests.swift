import XCTest
import SwiftData
import SwiftCheck
@testable import OpenCount

// Feature: open-count-ios, Property 1: Marker placement increments tally by exactly one
// Validates: Requirements 3.1, 6.1

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

/// Generates a random normalized coordinate in [0.0, 1.0].
private let normalizedCoordGen: Gen<Double> = Gen<Double>.choose((0.0, 1.0))

/// Generates a random hex color string like "#RRGGBB".
private let hexColorGen: Gen<String> = Gen<UInt32>.choose((0, 0xFFFFFF)).map {
    String(format: "#%06X", $0)
}

/// Generates a random SF Symbol name from a small fixed set.
private let iconNameGen: Gen<String> = Gen<String>.fromElements(of: [
    "circle.fill", "star.fill", "heart.fill", "person.fill",
    "car.fill", "leaf.fill", "pawprint.fill", "house.fill",
])

// MARK: - Tests

final class MarkerPlacementTests: XCTestCase {

    // MARK: Property 1: Marker placement increments tally by exactly one
    //
    // For any counting session with any selected Object_Type and any valid tap
    // location, placing a Count_Marker SHALL increase the Tally for that
    // Object_Type by exactly 1 and leave all other Object_Type Tallies unchanged.
    //
    // Tally is defined as:
    //   markers.filter { $0.objectType.id == type.id }.count
    //
    // Validates: Requirements 3.1, 6.1

    func testMarkerPlacementIncrementsTallyByExactlyOne() {
        // SwiftCheck property: for any random session configuration (arbitrary
        // number of Object_Types, arbitrary pre-existing markers, arbitrary tap
        // location, and arbitrary selected Object_Type), placing one new marker
        // increments the tally for the selected type by exactly 1 and leaves
        // every other type's tally unchanged.
        property("Placing a marker increments the selected Object_Type tally by exactly 1") <- forAll(
            Gen<Int>.choose((1, 5)),    // number of object types (at least 1)
            Gen<Int>.choose((0, 20)),   // number of pre-existing markers
            normalizedCoordGen,         // tap X
            normalizedCoordGen,         // tap Y
            Gen<Int>.choose((0, 4))     // index of the selected Object_Type (clamped below)
        ) { objectTypeCount, existingMarkerCount, tapX, tapY, selectedTypeIndex in
            let semaphore = DispatchSemaphore(value: 0)
            var result = false

            Task { @MainActor in
                defer { semaphore.signal() }
                do {
                    result = try await Self.markerPlacementPropertyHolds(
                        objectTypeCount: objectTypeCount,
                        existingMarkerCount: existingMarkerCount,
                        tapX: tapX,
                        tapY: tapY,
                        selectedTypeIndex: selectedTypeIndex % objectTypeCount
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

    /// Sets up a session with `objectTypeCount` Object_Types and `existingMarkerCount`
    /// markers distributed across those types, then places one new marker for the
    /// Object_Type at `selectedTypeIndex`, and asserts:
    ///   1. The tally for the selected type increased by exactly 1.
    ///   2. The tally for every other type is unchanged.
    ///   3. The total marker count increased by exactly 1.
    @MainActor
    private static func markerPlacementPropertyHolds(
        objectTypeCount: Int,
        existingMarkerCount: Int,
        tapX: Double,
        tapY: Double,
        selectedTypeIndex: Int
    ) async throws -> Bool {
        let container = try makeInMemoryContainer()
        let context = ModelContext(container)

        // 1. Build the session
        let session = CountSession(name: "Marker Placement Test")
        context.insert(session)

        // 2. Add object types
        var objectTypes: [ObjectType] = []
        for i in 0..<objectTypeCount {
            let ot = ObjectType(
                name: "Type \(i)",
                colorHex: String(format: "#%06X", (i + 1) * 0x111111 % 0xFFFFFF),
                iconName: "circle.fill",
                sortOrder: i,
                session: session
            )
            context.insert(ot)
            objectTypes.append(ot)
            session.objectTypes.append(ot)
        }

        // 3. Distribute pre-existing markers across object types
        for j in 0..<existingMarkerCount {
            let ot = objectTypes[j % objectTypeCount]
            let marker = CountMarker(
                normalizedX: Double(j % 10) / 10.0,
                normalizedY: Double(j / 10 % 10) / 10.0,
                objectType: ot,
                isAIDerived: false,
                session: session
            )
            context.insert(marker)
            session.markers.append(marker)
        }

        // 4. Record tallies before placement
        var talliesBefore: [UUID: Int] = [:]
        for ot in objectTypes {
            talliesBefore[ot.id] = session.markers.filter { $0.objectType.id == ot.id }.count
        }
        let totalBefore = session.markers.count

        // 5. Select the Object_Type and place a new marker (the action under test)
        let selectedType = objectTypes[selectedTypeIndex]
        let newMarker = CountMarker(
            normalizedX: tapX,
            normalizedY: tapY,
            objectType: selectedType,
            isAIDerived: false,
            session: session
        )
        context.insert(newMarker)
        session.markers.append(newMarker)

        // 6. Compute tallies after placement
        var talliesAfter: [UUID: Int] = [:]
        for ot in objectTypes {
            talliesAfter[ot.id] = session.markers.filter { $0.objectType.id == ot.id }.count
        }
        let totalAfter = session.markers.count

        // 7. Assert Property 1 invariants

        // Invariant A: total marker count increased by exactly 1
        guard totalAfter == totalBefore + 1 else { return false }

        // Invariant B: selected type's tally increased by exactly 1
        let selectedID = selectedType.id
        guard let before = talliesBefore[selectedID],
              let after = talliesAfter[selectedID],
              after == before + 1 else { return false }

        // Invariant C: all other types' tallies are unchanged
        for ot in objectTypes where ot.id != selectedID {
            guard let before = talliesBefore[ot.id],
                  let after = talliesAfter[ot.id],
                  after == before else { return false }
        }

        return true
    }

    // MARK: - Unit tests

    /// Placing a marker on an empty session creates a tally of 1 for that type.
    func testPlaceMarkerOnEmptySessionCreatesTallyOfOne() async throws {
        let container = try makeInMemoryContainer()
        let context = await MainActor.run { ModelContext(container) }

        let session = CountSession(name: "Empty Session")
        let objectType = ObjectType(
            name: "People",
            colorHex: "#FF0000",
            iconName: "person.fill",
            sortOrder: 0,
            session: session
        )

        await MainActor.run {
            context.insert(session)
            context.insert(objectType)
            session.objectTypes.append(objectType)
        }

        // Tally before placement
        let tallyBefore = await MainActor.run {
            session.markers.filter { $0.objectType.id == objectType.id }.count
        }
        XCTAssertEqual(tallyBefore, 0, "Tally should be 0 before any marker is placed")

        // Place one marker
        await MainActor.run {
            let marker = CountMarker(
                normalizedX: 0.5,
                normalizedY: 0.5,
                objectType: objectType,
                session: session
            )
            context.insert(marker)
            session.markers.append(marker)
        }

        let tallyAfter = await MainActor.run {
            session.markers.filter { $0.objectType.id == objectType.id }.count
        }
        XCTAssertEqual(tallyAfter, 1, "Tally should be 1 after placing one marker")
    }

    /// Placing multiple markers increments the tally by 1 each time.
    func testEachMarkerPlacementIncrementsCountByOne() async throws {
        let container = try makeInMemoryContainer()
        let context = await MainActor.run { ModelContext(container) }

        let session = CountSession(name: "Incremental Session")
        let objectType = ObjectType(
            name: "Cars",
            colorHex: "#0000FF",
            iconName: "car.fill",
            sortOrder: 0,
            session: session
        )

        await MainActor.run {
            context.insert(session)
            context.insert(objectType)
            session.objectTypes.append(objectType)
        }

        let placements = 5
        for i in 0..<placements {
            let tallyBefore = await MainActor.run {
                session.markers.filter { $0.objectType.id == objectType.id }.count
            }

            await MainActor.run {
                let marker = CountMarker(
                    normalizedX: Double(i) * 0.1,
                    normalizedY: 0.5,
                    objectType: objectType,
                    session: session
                )
                context.insert(marker)
                session.markers.append(marker)
            }

            let tallyAfter = await MainActor.run {
                session.markers.filter { $0.objectType.id == objectType.id }.count
            }
            XCTAssertEqual(tallyAfter, tallyBefore + 1,
                           "Tally should increase by exactly 1 on placement \(i + 1)")
        }

        let finalTally = await MainActor.run {
            session.markers.filter { $0.objectType.id == objectType.id }.count
        }
        XCTAssertEqual(finalTally, placements, "Final tally should equal number of placements")
    }

    /// Placing a marker for one type does not affect another type's tally.
    func testMarkerPlacementDoesNotAffectOtherTypeTallies() async throws {
        let container = try makeInMemoryContainer()
        let context = await MainActor.run { ModelContext(container) }

        let session = CountSession(name: "Multi-Type Session")
        let typeA = ObjectType(name: "Type A", colorHex: "#FF0000", iconName: "circle.fill", sortOrder: 0, session: session)
        let typeB = ObjectType(name: "Type B", colorHex: "#00FF00", iconName: "star.fill", sortOrder: 1, session: session)
        let typeC = ObjectType(name: "Type C", colorHex: "#0000FF", iconName: "heart.fill", sortOrder: 2, session: session)

        // Pre-populate with some markers
        let markerB = CountMarker(normalizedX: 0.3, normalizedY: 0.3, objectType: typeB, session: session)
        let markerC1 = CountMarker(normalizedX: 0.6, normalizedY: 0.6, objectType: typeC, session: session)
        let markerC2 = CountMarker(normalizedX: 0.7, normalizedY: 0.7, objectType: typeC, session: session)

        await MainActor.run {
            context.insert(session)
            context.insert(typeA)
            context.insert(typeB)
            context.insert(typeC)
            context.insert(markerB)
            context.insert(markerC1)
            context.insert(markerC2)
            session.objectTypes.append(contentsOf: [typeA, typeB, typeC])
            session.markers.append(contentsOf: [markerB, markerC1, markerC2])
        }

        // Record tallies before placing a Type A marker
        let tallyABefore = await MainActor.run {
            session.markers.filter { $0.objectType.id == typeA.id }.count
        }
        let tallyBBefore = await MainActor.run {
            session.markers.filter { $0.objectType.id == typeB.id }.count
        }
        let tallyCBefore = await MainActor.run {
            session.markers.filter { $0.objectType.id == typeC.id }.count
        }

        XCTAssertEqual(tallyABefore, 0)
        XCTAssertEqual(tallyBBefore, 1)
        XCTAssertEqual(tallyCBefore, 2)

        // Place one marker for Type A
        await MainActor.run {
            let newMarker = CountMarker(
                normalizedX: 0.1,
                normalizedY: 0.1,
                objectType: typeA,
                session: session
            )
            context.insert(newMarker)
            session.markers.append(newMarker)
        }

        // Assert tallies after placement
        let tallyAAfter = await MainActor.run {
            session.markers.filter { $0.objectType.id == typeA.id }.count
        }
        let tallyBAfter = await MainActor.run {
            session.markers.filter { $0.objectType.id == typeB.id }.count
        }
        let tallyCAfter = await MainActor.run {
            session.markers.filter { $0.objectType.id == typeC.id }.count
        }

        XCTAssertEqual(tallyAAfter, tallyABefore + 1, "Type A tally should increase by 1")
        XCTAssertEqual(tallyBAfter, tallyBBefore, "Type B tally should be unchanged")
        XCTAssertEqual(tallyCAfter, tallyCBefore, "Type C tally should be unchanged")
    }

    /// Placing a marker at boundary coordinates (0.0, 0.0) and (1.0, 1.0) is valid.
    func testMarkerPlacementAtBoundaryCoordinates() async throws {
        let container = try makeInMemoryContainer()
        let context = await MainActor.run { ModelContext(container) }

        let session = CountSession(name: "Boundary Session")
        let objectType = ObjectType(
            name: "Boundary Type",
            colorHex: "#FF5733",
            iconName: "circle.fill",
            sortOrder: 0,
            session: session
        )

        await MainActor.run {
            context.insert(session)
            context.insert(objectType)
            session.objectTypes.append(objectType)
        }

        let boundaryCoords: [(Double, Double)] = [(0.0, 0.0), (1.0, 1.0), (0.0, 1.0), (1.0, 0.0)]
        for (x, y) in boundaryCoords {
            let tallyBefore = await MainActor.run {
                session.markers.filter { $0.objectType.id == objectType.id }.count
            }

            await MainActor.run {
                let marker = CountMarker(
                    normalizedX: x,
                    normalizedY: y,
                    objectType: objectType,
                    session: session
                )
                context.insert(marker)
                session.markers.append(marker)
            }

            let tallyAfter = await MainActor.run {
                session.markers.filter { $0.objectType.id == objectType.id }.count
            }
            XCTAssertEqual(tallyAfter, tallyBefore + 1,
                           "Tally should increase by 1 for boundary coordinate (\(x), \(y))")
        }
    }

    /// Placing an AI-derived marker also increments the tally by exactly 1.
    func testAIDerivedMarkerPlacementIncrementsTallyByOne() async throws {
        let container = try makeInMemoryContainer()
        let context = await MainActor.run { ModelContext(container) }

        let session = CountSession(name: "AI Marker Session")
        let objectType = ObjectType(
            name: "AI Type",
            colorHex: "#AA00FF",
            iconName: "star.fill",
            sortOrder: 0,
            session: session
        )

        await MainActor.run {
            context.insert(session)
            context.insert(objectType)
            session.objectTypes.append(objectType)
        }

        let tallyBefore = await MainActor.run {
            session.markers.filter { $0.objectType.id == objectType.id }.count
        }
        XCTAssertEqual(tallyBefore, 0)

        // Place an AI-derived marker
        await MainActor.run {
            let aiMarker = CountMarker(
                normalizedX: 0.4,
                normalizedY: 0.6,
                objectType: objectType,
                isAIDerived: true,
                session: session
            )
            context.insert(aiMarker)
            session.markers.append(aiMarker)
        }

        let tallyAfter = await MainActor.run {
            session.markers.filter { $0.objectType.id == objectType.id }.count
        }
        XCTAssertEqual(tallyAfter, tallyBefore + 1,
                       "AI-derived marker placement should also increment tally by exactly 1")
    }
}
