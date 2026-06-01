import XCTest
import SwiftData
import SwiftCheck
@testable import OpenCount

// Feature: open-count-ios, Property 8: Session persistence round-trip preserves state
// Validates: Requirements 18.5, 1.3

// MARK: - Arbitrary instances

extension UUID: Arbitrary {
    public static var arbitrary: Gen<UUID> {
        Gen<UUID>.compose { _ in UUID() }
    }
}

/// Generates a random hex color string like "#RRGGBB"
private let hexColorGen: Gen<String> = Gen<UInt32>.choose((0, 0xFFFFFF)).map {
    String(format: "#%06X", $0)
}

/// Generates a random SF Symbol name from a small fixed set
private let iconNameGen: Gen<String> = Gen<String>.fromElements(of: [
    "circle.fill", "star.fill", "heart.fill", "person.fill",
    "car.fill", "leaf.fill", "pawprint.fill", "house.fill",
])

/// Generates a random ObjectType (not yet inserted into a context)
private func makeObjectTypeGen() -> Gen<(UUID, String, String, String, Int)> {
    Gen<(UUID, String, String, String, Int)>.zip(
        UUID.arbitrary,
        String.arbitrary.suchThat { !$0.isEmpty },
        hexColorGen,
        iconNameGen,
        Int.arbitrary.map { abs($0) % 100 }
    )
}

/// Generates a random normalized coordinate in [0.0, 1.0]
private let normalizedCoordGen: Gen<Double> = Gen<Double>.choose((0.0, 1.0))

/// Generates a random CountSession name
private let sessionNameGen: Gen<String> = String.arbitrary.suchThat { !$0.isEmpty }

// MARK: - Helper: build an in-memory ModelContainer

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

// MARK: - Tests

final class SessionPersistenceTests: XCTestCase {

    // MARK: Property 8: Session persistence round-trip preserves state
    //
    // For any CountSession state (including all markers and regions), persisting
    // the session to SwiftData and then fetching it back SHALL produce a session
    // that is structurally equivalent to the original.
    //
    // Validates: Requirements 18.5, 1.3

    func testSessionPersistenceRoundTrip() {
        // SwiftCheck property: for any random session configuration, the round-trip
        // through an in-memory SwiftData store preserves all structural data.
        property("Session persistence round-trip preserves name, description, and marker count") <- forAll(
            sessionNameGen,
            String.arbitrary,                          // description (may be empty)
            Gen<Int>.choose((0, 5)),                   // number of object types
            Gen<Int>.choose((0, 10))                   // number of markers
        ) { name, description, objectTypeCount, markerCount in
            // Run synchronously on the main actor via a semaphore so SwiftCheck can evaluate
            let semaphore = DispatchSemaphore(value: 0)
            var result = false

            Task { @MainActor in
                defer { semaphore.signal() }
                do {
                    result = try await Self.roundTripCheck(
                        name: name,
                        description: description.isEmpty ? nil : description,
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

    // MARK: - Round-trip helper

    @MainActor
    private static func roundTripCheck(
        name: String,
        description: String?,
        objectTypeCount: Int,
        markerCount: Int
    ) async throws -> Bool {
        let container = try makeInMemoryContainer()
        let context = ModelContext(container)

        // 1. Build the session
        let session = CountSession(
            name: name,
            sessionDescription: description
        )
        context.insert(session)

        // 2. Add object types
        var objectTypes: [ObjectType] = []
        for i in 0..<objectTypeCount {
            let ot = ObjectType(
                name: "Type \(i)",
                colorHex: "#\(String(format: "%06X", i * 0x111111 % 0xFFFFFF))",
                iconName: "circle.fill",
                sortOrder: i,
                session: session
            )
            context.insert(ot)
            objectTypes.append(ot)
            session.objectTypes.append(ot)
        }

        // 3. Add markers (only if we have at least one object type)
        var originalMarkerCount = 0
        if !objectTypes.isEmpty {
            for j in 0..<markerCount {
                let ot = objectTypes[j % objectTypes.count]
                let marker = CountMarker(
                    normalizedX: Double(j) / Double(max(markerCount, 1)),
                    normalizedY: Double(j) / Double(max(markerCount, 1)),
                    objectType: ot,
                    isAIDerived: j % 2 == 0,
                    session: session
                )
                context.insert(marker)
                session.markers.append(marker)
                originalMarkerCount += 1
            }
        }

        // 4. Add a region
        let region = CountRegion(
            name: "Region A",
            colorHex: "#0000FF",
            shapeType: .rectangle,
            normalizedPoints: [
                CGPoint(x: 0.1, y: 0.1),
                CGPoint(x: 0.9, y: 0.9),
            ],
            session: session
        )
        context.insert(region)
        session.regions.append(region)

        // 5. Save
        try context.save()

        // 6. Fetch back
        let descriptor = FetchDescriptor<CountSession>(
            predicate: #Predicate { $0.id == session.id }
        )
        let fetched = try context.fetch(descriptor)
        guard let fetchedSession = fetched.first else { return false }

        // 7. Assert structural equivalence
        let nameMatches = fetchedSession.name == name
        let descriptionMatches = fetchedSession.sessionDescription == description
        let markerCountMatches = fetchedSession.markers.count == originalMarkerCount
        let objectTypeCountMatches = fetchedSession.objectTypes.count == objectTypeCount
        let regionCountMatches = fetchedSession.regions.count == 1

        // Verify marker coordinates are preserved
        var coordinatesPreserved = true
        for (original, fetched) in zip(
            session.markers.sorted(by: { $0.normalizedX < $1.normalizedX }),
            fetchedSession.markers.sorted(by: { $0.normalizedX < $1.normalizedX })
        ) {
            if abs(original.normalizedX - fetched.normalizedX) > 1e-9 ||
               abs(original.normalizedY - fetched.normalizedY) > 1e-9 {
                coordinatesPreserved = false
                break
            }
        }

        return nameMatches
            && descriptionMatches
            && markerCountMatches
            && objectTypeCountMatches
            && regionCountMatches
            && coordinatesPreserved
    }

    // MARK: - Unit test: basic round-trip with known values

    func testBasicSessionRoundTrip() async throws {
        let container = try makeInMemoryContainer()
        let context = await MainActor.run { ModelContext(container) }

        let sessionID = UUID()
        let session = CountSession(
            id: sessionID,
            name: "Test Session",
            sessionDescription: "A test description"
        )

        let objectType = ObjectType(
            name: "People",
            colorHex: "#FF0000",
            iconName: "person.fill",
            sortOrder: 0,
            session: session
        )

        let marker = CountMarker(
            normalizedX: 0.25,
            normalizedY: 0.75,
            objectType: objectType,
            isAIDerived: false,
            session: session
        )

        await MainActor.run {
            context.insert(session)
            context.insert(objectType)
            context.insert(marker)
            session.objectTypes.append(objectType)
            session.markers.append(marker)
        }

        try await MainActor.run { try context.save() }

        let fetched = try await MainActor.run {
            let descriptor = FetchDescriptor<CountSession>(
                predicate: #Predicate { $0.id == sessionID }
            )
            return try context.fetch(descriptor)
        }

        XCTAssertEqual(fetched.count, 1)
        let fetchedSession = try XCTUnwrap(fetched.first)
        XCTAssertEqual(fetchedSession.name, "Test Session")
        XCTAssertEqual(fetchedSession.sessionDescription, "A test description")
        XCTAssertEqual(fetchedSession.objectTypes.count, 1)
        XCTAssertEqual(fetchedSession.markers.count, 1)
        XCTAssertEqual(fetchedSession.objectTypes.first?.name, "People")
        XCTAssertEqual(fetchedSession.markers.first?.normalizedX ?? 0, 0.25, accuracy: 1e-9)
        XCTAssertEqual(fetchedSession.markers.first?.normalizedY ?? 0, 0.75, accuracy: 1e-9)
        XCTAssertEqual(fetchedSession.markers.first?.isAIDerived, false)
    }

    // MARK: - Unit test: empty session round-trip

    func testEmptySessionRoundTrip() async throws {
        let container = try makeInMemoryContainer()
        let context = await MainActor.run { ModelContext(container) }

        let sessionID = UUID()
        let session = CountSession(id: sessionID, name: "Empty Session")

        await MainActor.run { context.insert(session) }
        try await MainActor.run { try context.save() }

        let fetched = try await MainActor.run {
            let descriptor = FetchDescriptor<CountSession>(
                predicate: #Predicate { $0.id == sessionID }
            )
            return try context.fetch(descriptor)
        }

        XCTAssertEqual(fetched.count, 1)
        let fetchedSession = try XCTUnwrap(fetched.first)
        XCTAssertEqual(fetchedSession.name, "Empty Session")
        XCTAssertNil(fetchedSession.sessionDescription)
        XCTAssertTrue(fetchedSession.objectTypes.isEmpty)
        XCTAssertTrue(fetchedSession.markers.isEmpty)
        XCTAssertTrue(fetchedSession.regions.isEmpty)
    }

    // MARK: - Unit test: region geometry preserved

    func testRegionGeometryPreservedAfterPersistence() async throws {
        let container = try makeInMemoryContainer()
        let context = await MainActor.run { ModelContext(container) }

        let sessionID = UUID()
        let session = CountSession(id: sessionID, name: "Region Test")

        let points: [CGPoint] = [
            CGPoint(x: 0.1, y: 0.2),
            CGPoint(x: 0.8, y: 0.2),
            CGPoint(x: 0.8, y: 0.9),
            CGPoint(x: 0.1, y: 0.9),
        ]
        let region = CountRegion(
            name: "Polygon Region",
            colorHex: "#00FF00",
            shapeType: .polygon,
            normalizedPoints: points,
            session: session
        )

        await MainActor.run {
            context.insert(session)
            context.insert(region)
            session.regions.append(region)
        }
        try await MainActor.run { try context.save() }

        let fetched = try await MainActor.run {
            let descriptor = FetchDescriptor<CountSession>(
                predicate: #Predicate { $0.id == sessionID }
            )
            return try context.fetch(descriptor)
        }

        let fetchedSession = try XCTUnwrap(fetched.first)
        XCTAssertEqual(fetchedSession.regions.count, 1)
        let fetchedRegion = try XCTUnwrap(fetchedSession.regions.first)
        XCTAssertEqual(fetchedRegion.shapeType, .polygon)
        XCTAssertEqual(fetchedRegion.normalizedPoints.count, 4)
        for (original, fetched) in zip(points, fetchedRegion.normalizedPoints) {
            XCTAssertEqual(original.x, fetched.x, accuracy: 1e-9)
            XCTAssertEqual(original.y, fetched.y, accuracy: 1e-9)
        }
    }
}
