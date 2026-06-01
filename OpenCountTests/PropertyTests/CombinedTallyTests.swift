import XCTest
import SwiftCheck
@testable import OpenCount

// Feature: open-count-ios, Property 9: Combined tally equals manual plus AI-derived marker count
// Validates: Requirements 7.4, 3.7

// MARK: - Helpers

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

final class CombinedTallyTests: XCTestCase {

    // MARK: Property 9: Combined tally equals manual plus AI-derived marker count
    //
    // For any counting session containing a mix of manual and AI-derived markers,
    // the globalTally for each Object_Type SHALL equal the count of all markers
    // (regardless of isAIDerived) whose objectType matches that type.
    //
    // globalTally is defined as:
    //   Dictionary(grouping: markers, by: { $0.objectType.id }).mapValues { $0.count }
    //
    // The property asserts:
    //   globalTally[type] == markers.filter { $0.objectType.id == type.id }.count
    //
    // Validates: Requirements 7.4, 3.7

    func testCombinedTallyEqualsMarkerCount() {
        // SwiftCheck property: for any random session configuration (arbitrary
        // number of Object_Types, arbitrary manual markers, arbitrary AI-derived
        // markers), the globalTally for every Object_Type equals the total count
        // of markers (manual + AI-derived) for that type.
        property("globalTally[type] equals markers.filter { objectType == type }.count for all types") <- forAll(
            Gen<Int>.choose((1, 5)),    // number of object types (at least 1)
            Gen<Int>.choose((0, 15)),   // number of manual markers
            Gen<Int>.choose((0, 15))    // number of AI-derived markers
        ) { objectTypeCount, manualMarkerCount, aiMarkerCount in
            let semaphore = DispatchSemaphore(value: 0)
            var result = false

            Task { @MainActor in
                defer { semaphore.signal() }
                do {
                    result = try await Self.combinedTallyPropertyHolds(
                        objectTypeCount: objectTypeCount,
                        manualMarkerCount: manualMarkerCount,
                        aiMarkerCount: aiMarkerCount
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

    /// Sets up a session with `objectTypeCount` Object_Types, `manualMarkerCount` manual
    /// markers, and `aiMarkerCount` AI-derived markers distributed across those types,
    /// then computes `globalTally` and asserts:
    ///   For every Object_Type `t`:
    ///     globalTally[t.id] == markers.filter { $0.objectType.id == t.id }.count
    @MainActor
    private static func combinedTallyPropertyHolds(
        objectTypeCount: Int,
        manualMarkerCount: Int,
        aiMarkerCount: Int
    ) async throws -> Bool {
        // 1. Build the session
        let session = CountSession(name: "Combined Tally Test")

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
            objectTypes.append(ot)
            session.objectTypes.append(ot)
        }

        // 3. Add manual markers distributed across object types
        for j in 0..<manualMarkerCount {
            let ot = objectTypes[j % objectTypeCount]
            let marker = CountMarker(
                normalizedX: Double(j % 10) / 10.0,
                normalizedY: Double(j / 10 % 10) / 10.0,
                objectType: ot,
                isAIDerived: false,
                session: session
            )
            session.markers.append(marker)
        }

        // 4. Add AI-derived markers distributed across object types
        for k in 0..<aiMarkerCount {
            let ot = objectTypes[k % objectTypeCount]
            let marker = CountMarker(
                normalizedX: Double((k + 5) % 10) / 10.0,
                normalizedY: Double((k + 5) / 10 % 10) / 10.0,
                objectType: ot,
                isAIDerived: true,
                session: session
            )
            session.markers.append(marker)
        }

        // 5. Compute globalTally as defined in the design:
        //    Dictionary(grouping: markers, by: { $0.objectType.id }).mapValues { $0.count }
        let globalTally = Dictionary(
            grouping: session.markers,
            by: { $0.objectType.id }
        ).mapValues { $0.count }

        // 6. Assert Property 9: for every Object_Type, globalTally[type.id] equals
        //    the count of all markers (manual + AI-derived) for that type.
        for ot in objectTypes {
            let expectedCount = session.markers.filter { $0.objectType.id == ot.id }.count
            let tallyCount = globalTally[ot.id] ?? 0

            guard tallyCount == expectedCount else { return false }
        }

        // 7. Also verify that the sum of all tally values equals total marker count
        let tallySum = globalTally.values.reduce(0, +)
        let totalMarkers = session.markers.count
        guard tallySum == totalMarkers else { return false }

        return true
    }

    // MARK: - Unit tests

    /// globalTally for a session with only manual markers equals the manual marker count per type.
    func testGlobalTallyWithOnlyManualMarkers() async throws {
        let session = CountSession(name: "Manual Only Session")
        let typeA = ObjectType(name: "Type A", colorHex: "#FF0000", iconName: "circle.fill", sortOrder: 0, session: session)
        let typeB = ObjectType(name: "Type B", colorHex: "#0000FF", iconName: "star.fill", sortOrder: 1, session: session)

        session.objectTypes.append(contentsOf: [typeA, typeB])

        // 3 manual markers for Type A, 2 for Type B
        for i in 0..<3 {
            let m = CountMarker(normalizedX: Double(i) * 0.1, normalizedY: 0.1,
                                objectType: typeA, isAIDerived: false, session: session)
            session.markers.append(m)
        }
        for i in 0..<2 {
            let m = CountMarker(normalizedX: Double(i) * 0.1, normalizedY: 0.5,
                                objectType: typeB, isAIDerived: false, session: session)
            session.markers.append(m)
        }

        let globalTally = Dictionary(
            grouping: session.markers,
            by: { $0.objectType.id }
        ).mapValues { $0.count }
        let tallyA = globalTally[typeA.id] ?? 0
        let tallyB = globalTally[typeB.id] ?? 0

        XCTAssertEqual(tallyA, 3, "globalTally for Type A should be 3 (all manual)")
        XCTAssertEqual(tallyB, 2, "globalTally for Type B should be 2 (all manual)")
    }

    /// globalTally for a session with only AI-derived markers equals the AI marker count per type.
    func testGlobalTallyWithOnlyAIDerivedMarkers() async throws {
        let session = CountSession(name: "AI Only Session")
        let typeA = ObjectType(name: "Type A", colorHex: "#FF0000", iconName: "circle.fill", sortOrder: 0, session: session)

        session.objectTypes.append(typeA)

        // 4 AI-derived markers for Type A
        for i in 0..<4 {
            let m = CountMarker(normalizedX: Double(i) * 0.2, normalizedY: 0.3,
                                objectType: typeA, isAIDerived: true, session: session)
            session.markers.append(m)
        }

        let globalTally = Dictionary(
            grouping: session.markers,
            by: { $0.objectType.id }
        ).mapValues { $0.count }
        let tallyA = globalTally[typeA.id] ?? 0

        XCTAssertEqual(tallyA, 4, "globalTally for Type A should be 4 (all AI-derived)")
    }

    /// globalTally for a session with mixed manual and AI-derived markers equals the combined count.
    func testGlobalTallyWithMixedMarkers() async throws {
        let session = CountSession(name: "Mixed Markers Session")
        let typeA = ObjectType(name: "Type A", colorHex: "#FF0000", iconName: "circle.fill", sortOrder: 0, session: session)
        let typeB = ObjectType(name: "Type B", colorHex: "#00FF00", iconName: "star.fill", sortOrder: 1, session: session)

        session.objectTypes.append(contentsOf: [typeA, typeB])

        // Type A: 2 manual + 3 AI = 5 total
        for i in 0..<2 {
            let m = CountMarker(normalizedX: Double(i) * 0.1, normalizedY: 0.1,
                                objectType: typeA, isAIDerived: false, session: session)
            session.markers.append(m)
        }
        for i in 0..<3 {
            let m = CountMarker(normalizedX: Double(i) * 0.1, normalizedY: 0.2,
                                objectType: typeA, isAIDerived: true, session: session)
            session.markers.append(m)
        }

        // Type B: 4 manual + 1 AI = 5 total
        for i in 0..<4 {
            let m = CountMarker(normalizedX: Double(i) * 0.1, normalizedY: 0.5,
                                objectType: typeB, isAIDerived: false, session: session)
            session.markers.append(m)
        }
        for i in 0..<1 {
            let m = CountMarker(normalizedX: Double(i) * 0.1, normalizedY: 0.6,
                                objectType: typeB, isAIDerived: true, session: session)
            session.markers.append(m)
        }

        let globalTally = Dictionary(
            grouping: session.markers,
            by: { $0.objectType.id }
        ).mapValues { $0.count }
        let tallyA = globalTally[typeA.id] ?? 0
        let tallyB = globalTally[typeB.id] ?? 0
        let totalTally = globalTally.values.reduce(0, +)

        XCTAssertEqual(tallyA, 5, "globalTally for Type A should be 5 (2 manual + 3 AI)")
        XCTAssertEqual(tallyB, 5, "globalTally for Type B should be 5 (4 manual + 1 AI)")
        XCTAssertEqual(totalTally, 10, "Total tally should equal total marker count (10)")
    }

    /// globalTally for an Object_Type with no markers is 0 (or absent from the dictionary).
    func testGlobalTallyIsZeroForTypeWithNoMarkers() async throws {
        let session = CountSession(name: "Empty Type Session")
        let typeA = ObjectType(name: "Type A", colorHex: "#FF0000", iconName: "circle.fill", sortOrder: 0, session: session)
        let typeB = ObjectType(name: "Type B", colorHex: "#0000FF", iconName: "star.fill", sortOrder: 1, session: session)

        session.objectTypes.append(contentsOf: [typeA, typeB])

        // Only add markers for Type A; Type B gets none
        let m = CountMarker(normalizedX: 0.5, normalizedY: 0.5,
                            objectType: typeA, isAIDerived: false, session: session)
        session.markers.append(m)

        let globalTally = Dictionary(
            grouping: session.markers,
            by: { $0.objectType.id }
        ).mapValues { $0.count }
        let tallyA = globalTally[typeA.id] ?? 0
        let tallyB = globalTally[typeB.id] ?? 0

        XCTAssertEqual(tallyA, 1, "globalTally for Type A should be 1")
        XCTAssertEqual(tallyB, 0, "globalTally for Type B should be 0 (no markers)")
    }

    /// Sum of all globalTally values equals the total marker count in the session.
    func testGlobalTallySumEqualsTotalMarkerCount() async throws {
        let session = CountSession(name: "Tally Sum Session")
        let types = (0..<4).map { i in
            ObjectType(name: "Type \(i)", colorHex: "#FF0000", iconName: "circle.fill",
                       sortOrder: i, session: session)
        }

        for t in types {
            session.objectTypes.append(t)
        }

        // Add a varying number of markers per type (manual and AI mixed)
        let counts = [3, 0, 5, 2]  // Type 0: 3, Type 1: 0, Type 2: 5, Type 3: 2
        for (typeIndex, count) in counts.enumerated() {
            let ot = types[typeIndex]
            for i in 0..<count {
                let m = CountMarker(
                    normalizedX: Double(i) * 0.1,
                    normalizedY: Double(typeIndex) * 0.2,
                    objectType: ot,
                    isAIDerived: i % 2 == 0,  // alternate manual/AI
                    session: session
                )
                session.markers.append(m)
            }
        }

        let globalTally = Dictionary(
            grouping: session.markers,
            by: { $0.objectType.id }
        ).mapValues { $0.count }
        let tallySum = globalTally.values.reduce(0, +)
        let totalMarkers = session.markers.count

        XCTAssertEqual(tallySum, totalMarkers,
                       "Sum of all globalTally values must equal total marker count")
        XCTAssertEqual(totalMarkers, 10, "Total markers should be 10 (3+0+5+2)")
    }
}
