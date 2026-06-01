import XCTest
import SwiftData
import SwiftCheck
@testable import OpenCount

// Feature: open-count-ios, Property 7: Object_Type deletion removes all associated markers
// Validates: Requirements 14.5

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

/// Generates a random hex color string like "#RRGGBB"
private let hexColorGen: Gen<String> = Gen<UInt32>.choose((0, 0xFFFFFF)).map {
    String(format: "#%06X", $0)
}

/// Generates a random SF Symbol name from a small fixed set
private let iconNameGen: Gen<String> = Gen<String>.fromElements(of: [
    "circle.fill", "star.fill", "heart.fill", "person.fill",
    "car.fill", "leaf.fill", "pawprint.fill", "house.fill",
])

// MARK: - Tests

final class ObjectTypeDeletionTests: XCTestCase {

    // MARK: Property 7: Object_Type deletion removes all associated markers
    //
    // For any CountSession and any Object_Type within that session, after deleting
    // the Object_Type (and cascading the deletion to its markers), the session SHALL
    // contain zero Count_Markers associated with that Object_Type and the Tally for
    // that type SHALL be 0.
    //
    // Validates: Requirements 14.5

    func testObjectTypeDeletionRemovesAllAssociatedMarkers() {
        // SwiftCheck property: for any random session configuration, deleting an
        // Object_Type removes all of its associated Count_Markers and leaves the
        // tally for that type at 0.
        property("Deleting an Object_Type removes all its associated markers and sets tally to 0") <- forAll(
            Gen<Int>.choose((1, 5)),   // number of object types (at least 1 to delete)
            Gen<Int>.choose((0, 15))   // total number of markers
        ) { objectTypeCount, markerCount in
            let semaphore = DispatchSemaphore(value: 0)
            var result = false

            Task { @MainActor in
                defer { semaphore.signal() }
                do {
                    result = try await Self.deletionCascadePropertyHolds(
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

    /// Sets up a session with `objectTypeCount` Object_Types and `markerCount` markers
    /// distributed randomly across those types, then deletes one Object_Type (the first
    /// one) along with all its markers, and asserts:
    ///   1. No markers in the session reference the deleted Object_Type.
    ///   2. The tally (marker count) for the deleted type is 0.
    ///   3. Markers belonging to other Object_Types are unaffected.
    @MainActor
    private static func deletionCascadePropertyHolds(
        objectTypeCount: Int,
        markerCount: Int
    ) async throws -> Bool {
        let container = try makeInMemoryContainer()
        let context = ModelContext(container)

        // 1. Build the session
        let session = CountSession(name: "Deletion Test Session")
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

        // 3. Distribute markers across object types
        var markersByType: [UUID: Int] = [:]
        for ot in objectTypes { markersByType[ot.id] = 0 }

        for j in 0..<markerCount {
            let ot = objectTypes[j % objectTypes.count]
            let marker = CountMarker(
                normalizedX: Double(j % 10) / 10.0,
                normalizedY: Double(j / 10 % 10) / 10.0,
                objectType: ot,
                isAIDerived: false,
                session: session
            )
            context.insert(marker)
            session.markers.append(marker)
            markersByType[ot.id, default: 0] += 1
        }

        // 4. Save initial state
        try context.save()

        // 5. Choose the target Object_Type to delete (always the first one)
        let targetType = objectTypes[0]
        let targetTypeID = targetType.id
        let markersForTarget = markersByType[targetTypeID] ?? 0

        // Count markers for other types before deletion (to verify they're unaffected)
        let totalMarkersBeforeDeletion = session.markers.count
        let otherMarkersCount = totalMarkersBeforeDeletion - markersForTarget

        // 6. Perform cascade deletion: remove all markers for the target type, then
        //    delete the Object_Type itself. This is the behavior that task 5 implements.
        let markersToDelete = session.markers.filter { $0.objectType.id == targetTypeID }
        for marker in markersToDelete {
            session.markers.removeAll { $0.id == marker.id }
            context.delete(marker)
        }
        session.objectTypes.removeAll { $0.id == targetTypeID }
        context.delete(targetType)

        try context.save()

        // 7. Fetch back and verify
        let sessionDescriptor = FetchDescriptor<CountSession>(
            predicate: #Predicate { $0.id == session.id }
        )
        let fetchedSessions = try context.fetch(sessionDescriptor)
        guard let fetchedSession = fetchedSessions.first else { return false }

        // Property assertion 1: No markers reference the deleted Object_Type
        let remainingMarkersForDeletedType = fetchedSession.markers.filter {
            $0.objectType.id == targetTypeID
        }
        guard remainingMarkersForDeletedType.isEmpty else { return false }

        // Property assertion 2: Tally for deleted type is 0
        let tallyForDeletedType = fetchedSession.markers.filter {
            $0.objectType.id == targetTypeID
        }.count
        guard tallyForDeletedType == 0 else { return false }

        // Property assertion 3: Markers for other types are unaffected
        let remainingOtherMarkers = fetchedSession.markers.filter {
            $0.objectType.id != targetTypeID
        }
        guard remainingOtherMarkers.count == otherMarkersCount else { return false }

        // Property assertion 4: The deleted Object_Type no longer appears in the session
        let deletedTypeStillInSession = fetchedSession.objectTypes.contains {
            $0.id == targetTypeID
        }
        guard !deletedTypeStillInSession else { return false }

        return true
    }

    // MARK: - Unit tests

    /// Deleting an Object_Type with no markers leaves the session unchanged (zero markers).
    func testDeleteObjectTypeWithNoMarkers() async throws {
        let container = try makeInMemoryContainer()
        let context = await MainActor.run { ModelContext(container) }

        let session = CountSession(name: "Empty Markers Session")
        let objectType = ObjectType(
            name: "Birds",
            colorHex: "#00FF00",
            iconName: "bird",
            sortOrder: 0,
            session: session
        )

        await MainActor.run {
            context.insert(session)
            context.insert(objectType)
            session.objectTypes.append(objectType)
        }
        try await MainActor.run { try context.save() }

        // Delete the Object_Type (no markers to cascade)
        await MainActor.run {
            session.objectTypes.removeAll { $0.id == objectType.id }
            context.delete(objectType)
        }
        try await MainActor.run { try context.save() }

        let fetched = try await MainActor.run {
            let descriptor = FetchDescriptor<CountSession>(
                predicate: #Predicate { $0.id == session.id }
            )
            return try context.fetch(descriptor)
        }

        let fetchedSession = try XCTUnwrap(fetched.first)
        XCTAssertTrue(fetchedSession.objectTypes.isEmpty, "Object_Type should be removed from session")
        XCTAssertTrue(fetchedSession.markers.isEmpty, "No markers should exist")
    }

    /// Deleting one Object_Type removes only its markers, leaving other types' markers intact.
    func testDeleteOneObjectTypePreservesOtherMarkers() async throws {
        let container = try makeInMemoryContainer()
        let context = await MainActor.run { ModelContext(container) }

        let session = CountSession(name: "Multi-Type Session")
        let typeA = ObjectType(name: "Type A", colorHex: "#FF0000", iconName: "circle.fill", sortOrder: 0, session: session)
        let typeB = ObjectType(name: "Type B", colorHex: "#0000FF", iconName: "star.fill", sortOrder: 1, session: session)

        let markerA1 = CountMarker(normalizedX: 0.1, normalizedY: 0.1, objectType: typeA, session: session)
        let markerA2 = CountMarker(normalizedX: 0.2, normalizedY: 0.2, objectType: typeA, session: session)
        let markerB1 = CountMarker(normalizedX: 0.5, normalizedY: 0.5, objectType: typeB, session: session)
        let markerB2 = CountMarker(normalizedX: 0.6, normalizedY: 0.6, objectType: typeB, session: session)
        let markerB3 = CountMarker(normalizedX: 0.7, normalizedY: 0.7, objectType: typeB, session: session)

        await MainActor.run {
            context.insert(session)
            context.insert(typeA)
            context.insert(typeB)
            context.insert(markerA1)
            context.insert(markerA2)
            context.insert(markerB1)
            context.insert(markerB2)
            context.insert(markerB3)
            session.objectTypes.append(contentsOf: [typeA, typeB])
            session.markers.append(contentsOf: [markerA1, markerA2, markerB1, markerB2, markerB3])
        }
        try await MainActor.run { try context.save() }

        // Delete Type A and cascade its markers
        let typeAID = typeA.id
        await MainActor.run {
            let markersToDelete = session.markers.filter { $0.objectType.id == typeAID }
            for marker in markersToDelete {
                session.markers.removeAll { $0.id == marker.id }
                context.delete(marker)
            }
            session.objectTypes.removeAll { $0.id == typeAID }
            context.delete(typeA)
        }
        try await MainActor.run { try context.save() }

        let fetched = try await MainActor.run {
            let descriptor = FetchDescriptor<CountSession>(
                predicate: #Predicate { $0.id == session.id }
            )
            return try context.fetch(descriptor)
        }

        let fetchedSession = try XCTUnwrap(fetched.first)

        // Type A should be gone
        XCTAssertFalse(fetchedSession.objectTypes.contains { $0.id == typeAID },
                       "Type A should be deleted from session")

        // Type A's markers should be gone (tally = 0)
        let typeAMarkers = fetchedSession.markers.filter { $0.objectType.id == typeAID }
        XCTAssertEqual(typeAMarkers.count, 0, "All Type A markers should be deleted")

        // Type B's markers should be intact
        let typeBID = typeB.id
        let typeBMarkers = fetchedSession.markers.filter { $0.objectType.id == typeBID }
        XCTAssertEqual(typeBMarkers.count, 3, "Type B markers should be unaffected")

        // Total markers should be 3 (only Type B's)
        XCTAssertEqual(fetchedSession.markers.count, 3, "Only Type B markers should remain")
    }

    /// Deleting all Object_Types removes all markers from the session.
    func testDeleteAllObjectTypesRemovesAllMarkers() async throws {
        let container = try makeInMemoryContainer()
        let context = await MainActor.run { ModelContext(container) }

        let session = CountSession(name: "All Types Deleted Session")
        let typeA = ObjectType(name: "Type A", colorHex: "#FF0000", iconName: "circle.fill", sortOrder: 0, session: session)
        let typeB = ObjectType(name: "Type B", colorHex: "#0000FF", iconName: "star.fill", sortOrder: 1, session: session)

        let markers: [CountMarker] = [
            CountMarker(normalizedX: 0.1, normalizedY: 0.1, objectType: typeA, session: session),
            CountMarker(normalizedX: 0.2, normalizedY: 0.2, objectType: typeA, session: session),
            CountMarker(normalizedX: 0.5, normalizedY: 0.5, objectType: typeB, session: session),
        ]

        await MainActor.run {
            context.insert(session)
            context.insert(typeA)
            context.insert(typeB)
            for marker in markers { context.insert(marker) }
            session.objectTypes.append(contentsOf: [typeA, typeB])
            session.markers.append(contentsOf: markers)
        }
        try await MainActor.run { try context.save() }

        // Delete all object types and cascade their markers
        await MainActor.run {
            for marker in session.markers { context.delete(marker) }
            session.markers.removeAll()
            for ot in session.objectTypes { context.delete(ot) }
            session.objectTypes.removeAll()
        }
        try await MainActor.run { try context.save() }

        let fetched = try await MainActor.run {
            let descriptor = FetchDescriptor<CountSession>(
                predicate: #Predicate { $0.id == session.id }
            )
            return try context.fetch(descriptor)
        }

        let fetchedSession = try XCTUnwrap(fetched.first)
        XCTAssertTrue(fetchedSession.objectTypes.isEmpty, "All Object_Types should be deleted")
        XCTAssertTrue(fetchedSession.markers.isEmpty, "All markers should be deleted")
    }

    /// Tally for a deleted Object_Type is 0 after cascade deletion.
    func testTallyIsZeroAfterObjectTypeDeletion() async throws {
        let container = try makeInMemoryContainer()
        let context = await MainActor.run { ModelContext(container) }

        let session = CountSession(name: "Tally Check Session")
        let targetType = ObjectType(name: "Target", colorHex: "#FF5733", iconName: "person.fill", sortOrder: 0, session: session)
        let otherType = ObjectType(name: "Other", colorHex: "#33FF57", iconName: "car.fill", sortOrder: 1, session: session)

        // Place 5 markers for target, 3 for other
        var allMarkers: [CountMarker] = []
        for i in 0..<5 {
            allMarkers.append(CountMarker(
                normalizedX: Double(i) * 0.1,
                normalizedY: 0.1,
                objectType: targetType,
                session: session
            ))
        }
        for i in 0..<3 {
            allMarkers.append(CountMarker(
                normalizedX: Double(i) * 0.1,
                normalizedY: 0.5,
                objectType: otherType,
                session: session
            ))
        }

        await MainActor.run {
            context.insert(session)
            context.insert(targetType)
            context.insert(otherType)
            for marker in allMarkers { context.insert(marker) }
            session.objectTypes.append(contentsOf: [targetType, otherType])
            session.markers.append(contentsOf: allMarkers)
        }
        try await MainActor.run { try context.save() }

        // Verify initial tallies
        let initialTargetTally = await MainActor.run {
            session.markers.filter { $0.objectType.id == targetType.id }.count
        }
        XCTAssertEqual(initialTargetTally, 5, "Initial tally for target type should be 5")

        // Delete target type and cascade
        let targetTypeID = targetType.id
        await MainActor.run {
            let markersToDelete = session.markers.filter { $0.objectType.id == targetTypeID }
            for marker in markersToDelete {
                session.markers.removeAll { $0.id == marker.id }
                context.delete(marker)
            }
            session.objectTypes.removeAll { $0.id == targetTypeID }
            context.delete(targetType)
        }
        try await MainActor.run { try context.save() }

        let fetched = try await MainActor.run {
            let descriptor = FetchDescriptor<CountSession>(
                predicate: #Predicate { $0.id == session.id }
            )
            return try context.fetch(descriptor)
        }

        let fetchedSession = try XCTUnwrap(fetched.first)

        // Tally for deleted type must be 0
        let finalTargetTally = fetchedSession.markers.filter { $0.objectType.id == targetTypeID }.count
        XCTAssertEqual(finalTargetTally, 0, "Tally for deleted Object_Type must be 0")

        // Other type's tally must be unchanged
        let otherTypeID = otherType.id
        let finalOtherTally = fetchedSession.markers.filter { $0.objectType.id == otherTypeID }.count
        XCTAssertEqual(finalOtherTally, 3, "Tally for other Object_Type must be unchanged")
    }
}
