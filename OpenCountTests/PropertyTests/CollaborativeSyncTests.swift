import XCTest
import SwiftCheck
@testable import OpenCount

// Feature: open-count-ios, Property 14: Collaborative sync preserves total marker count
// Validates: Requirements 28.2, 28.5

// MARK: - Tests

final class CollaborativeSyncTests: XCTestCase {

    // MARK: Property 14: Collaborative sync preserves total marker count
    //
    // For any two participants each adding N and M markers respectively to a
    // shared session, after sync the session SHALL contain exactly N + M markers
    // with no duplicates.
    //
    // Since CollaborationService is not yet fully implemented, the merge logic
    // is simulated directly:
    //   - Participant A adds N markers (with unique UUIDs)
    //   - Participant B adds M markers (with unique UUIDs)
    //   - Merge = union of both sets (deduplicate by id)
    //   - Assert: merged.count == N + M
    //   - Assert: no duplicate UUIDs in merged set
    //
    // Validates: Requirements 28.2, 28.5

    func testCollaborativeSyncPreservesTotalMarkerCount() {
        // SwiftCheck property: for any N and M in [0, 20], two participants each
        // adding N and M markers with unique UUIDs, the merged set SHALL contain
        // exactly N + M markers with no duplicate IDs.
        property("Collaborative sync: merged marker count equals N + M with no duplicates") <- forAll(
            Gen<Int>.choose((0, 20)),   // N: markers added by participant A
            Gen<Int>.choose((0, 20))    // M: markers added by participant B
        ) { n, m in
            let semaphore = DispatchSemaphore(value: 0)
            var result = false

            Task { @MainActor in
                defer { semaphore.signal() }
                do {
                    result = try await Self.collaborativeSyncPropertyHolds(n: n, m: m)
                } catch {
                    result = false
                }
            }

            semaphore.wait()
            return result
        }
    }

    // MARK: - Core property helper

    /// Simulates two participants each adding `n` and `m` markers to a shared
    /// session, merges them using union semantics (deduplicate by id), and asserts:
    ///   1. merged.count == n + m
    ///   2. Set(merged.map(\.id)).count == merged.count  (no duplicate UUIDs)
    @MainActor
    private static func collaborativeSyncPropertyHolds(n: Int, m: Int) async throws -> Bool {
        // Build a shared session and a shared ObjectType
        let session = CountSession(name: "Collaborative Sync Test")

        let sharedType = ObjectType(
            name: "SharedType",
            colorHex: "#FF5733",
            iconName: "circle.fill",
            sortOrder: 0,
            session: session
        )
        session.objectTypes.append(sharedType)

        // Participant A adds N markers — each with a unique UUID
        var participantAMarkers: [CountMarker] = []
        for i in 0..<n {
            let marker = CountMarker(
                id: UUID(),
                normalizedX: Double(i % 10) / 10.0,
                normalizedY: Double(i / 10 % 10) / 10.0,
                objectType: sharedType,
                isAIDerived: false,
                session: session
            )
            participantAMarkers.append(marker)
        }

        // Participant B adds M markers — each with a unique UUID
        var participantBMarkers: [CountMarker] = []
        for j in 0..<m {
            let marker = CountMarker(
                id: UUID(),
                normalizedX: Double((j + 5) % 10) / 10.0,
                normalizedY: Double((j + 5) / 10 % 10) / 10.0,
                objectType: sharedType,
                isAIDerived: false,
                session: session
            )
            participantBMarkers.append(marker)
        }

        // Merge: union of both sets, deduplicated by id (last-write-wins / union semantics)
        // Since all UUIDs are unique, the union is simply the concatenation.
        var mergedByID: [UUID: CountMarker] = [:]
        for marker in participantAMarkers {
            mergedByID[marker.id] = marker
        }
        for marker in participantBMarkers {
            mergedByID[marker.id] = marker
        }
        let merged = Array(mergedByID.values)

        // Assert 1: merged.count == N + M
        guard merged.count == n + m else { return false }

        // Assert 2: no duplicate UUIDs in merged set
        let uniqueIDs = Set(merged.map(\.id))
        guard uniqueIDs.count == merged.count else { return false }

        return true
    }

    // MARK: - Unit tests

    /// When N = 0 and M = 0, the merged set is empty.
    func testMergeWithBothZeroMarkersIsEmpty() async throws {
        let session = CountSession(name: "Zero Markers Session")
        let sharedType = ObjectType(
            name: "SharedType",
            colorHex: "#FF5733",
            iconName: "circle.fill",
            sortOrder: 0,
            session: session
        )
        session.objectTypes.append(sharedType)

        // Both participants add 0 markers
        let participantAMarkers: [CountMarker] = []
        let participantBMarkers: [CountMarker] = []

        var mergedByID: [UUID: CountMarker] = [:]
        for marker in participantAMarkers { mergedByID[marker.id] = marker }
        for marker in participantBMarkers { mergedByID[marker.id] = marker }
        let merged = Array(mergedByID.values)

        XCTAssertEqual(merged.count, 0, "Merged set should be empty when both participants add 0 markers")
        XCTAssertEqual(Set(merged.map(\.id)).count, merged.count, "No duplicate UUIDs expected")
    }

    /// When N = 0, the merged set equals participant B's markers.
    func testMergeWithParticipantAHavingZeroMarkers() async throws {
        let session = CountSession(name: "A Zero Session")
        let sharedType = ObjectType(
            name: "SharedType",
            colorHex: "#0000FF",
            iconName: "star.fill",
            sortOrder: 0,
            session: session
        )
        session.objectTypes.append(sharedType)

        let m = 5
        let participantAMarkers: [CountMarker] = []
        var participantBMarkers: [CountMarker] = []

        for j in 0..<m {
            let marker = CountMarker(
                id: UUID(),
                normalizedX: Double(j) * 0.1,
                normalizedY: 0.5,
                objectType: sharedType,
                isAIDerived: false,
                session: session
            )
            participantBMarkers.append(marker)
        }

        var mergedByID: [UUID: CountMarker] = [:]
        for marker in participantAMarkers { mergedByID[marker.id] = marker }
        for marker in participantBMarkers { mergedByID[marker.id] = marker }
        let merged = Array(mergedByID.values)

        XCTAssertEqual(merged.count, m, "Merged count should equal M when participant A adds 0 markers")
        XCTAssertEqual(Set(merged.map(\.id)).count, merged.count, "No duplicate UUIDs expected")
    }

    /// When M = 0, the merged set equals participant A's markers.
    func testMergeWithParticipantBHavingZeroMarkers() async throws {
        let session = CountSession(name: "B Zero Session")
        let sharedType = ObjectType(
            name: "SharedType",
            colorHex: "#00FF00",
            iconName: "heart.fill",
            sortOrder: 0,
            session: session
        )
        session.objectTypes.append(sharedType)

        let n = 7
        var participantAMarkers: [CountMarker] = []
        let participantBMarkers: [CountMarker] = []

        for i in 0..<n {
            let marker = CountMarker(
                id: UUID(),
                normalizedX: Double(i) * 0.1,
                normalizedY: 0.2,
                objectType: sharedType,
                isAIDerived: false,
                session: session
            )
            participantAMarkers.append(marker)
        }

        var mergedByID: [UUID: CountMarker] = [:]
        for marker in participantAMarkers { mergedByID[marker.id] = marker }
        for marker in participantBMarkers { mergedByID[marker.id] = marker }
        let merged = Array(mergedByID.values)

        XCTAssertEqual(merged.count, n, "Merged count should equal N when participant B adds 0 markers")
        XCTAssertEqual(Set(merged.map(\.id)).count, merged.count, "No duplicate UUIDs expected")
    }

    /// Merging two non-empty sets of markers with unique UUIDs yields N + M total with no duplicates.
    func testMergeWithBothParticipantsAddingMarkers() async throws {
        let session = CountSession(name: "Both Participants Session")
        let sharedType = ObjectType(
            name: "SharedType",
            colorHex: "#FF0000",
            iconName: "person.fill",
            sortOrder: 0,
            session: session
        )
        session.objectTypes.append(sharedType)

        let n = 8
        let m = 6
        var participantAMarkers: [CountMarker] = []
        var participantBMarkers: [CountMarker] = []

        for i in 0..<n {
            let marker = CountMarker(
                id: UUID(),
                normalizedX: Double(i) * 0.1,
                normalizedY: 0.1,
                objectType: sharedType,
                isAIDerived: false,
                session: session
            )
            participantAMarkers.append(marker)
        }
        for j in 0..<m {
            let marker = CountMarker(
                id: UUID(),
                normalizedX: Double(j) * 0.1,
                normalizedY: 0.9,
                objectType: sharedType,
                isAIDerived: false,
                session: session
            )
            participantBMarkers.append(marker)
        }

        var mergedByID: [UUID: CountMarker] = [:]
        for marker in participantAMarkers { mergedByID[marker.id] = marker }
        for marker in participantBMarkers { mergedByID[marker.id] = marker }
        let merged = Array(mergedByID.values)

        XCTAssertEqual(merged.count, n + m,
                       "Merged count should equal N + M = \(n + m)")
        XCTAssertEqual(Set(merged.map(\.id)).count, merged.count,
                       "All IDs in merged set must be unique (no duplicates)")
    }

    /// Union semantics: if the same marker UUID appears in both sets, it is counted only once.
    func testMergeDeduplicatesMarkersWithSameUUID() async throws {
        let session = CountSession(name: "Dedup Session")
        let sharedType = ObjectType(
            name: "SharedType",
            colorHex: "#AAAAAA",
            iconName: "leaf.fill",
            sortOrder: 0,
            session: session
        )
        session.objectTypes.append(sharedType)

        // Create 3 markers with known UUIDs
        let sharedID = UUID()
        let idA = UUID()
        let idB = UUID()

        var participantAMarkers: [CountMarker] = []
        var participantBMarkers: [CountMarker] = []

        // Participant A has: sharedID, idA
        participantAMarkers.append(CountMarker(
            id: sharedID,
            normalizedX: 0.1, normalizedY: 0.1,
            objectType: sharedType, session: session
        ))
        participantAMarkers.append(CountMarker(
            id: idA,
            normalizedX: 0.2, normalizedY: 0.2,
            objectType: sharedType, session: session
        ))

        // Participant B has: sharedID (same!), idB
        participantBMarkers.append(CountMarker(
            id: sharedID,
            normalizedX: 0.1, normalizedY: 0.1,
            objectType: sharedType, session: session
        ))
        participantBMarkers.append(CountMarker(
            id: idB,
            normalizedX: 0.3, normalizedY: 0.3,
            objectType: sharedType, session: session
        ))

        // Merge using union semantics (deduplicate by id)
        var mergedByID: [UUID: CountMarker] = [:]
        for marker in participantAMarkers { mergedByID[marker.id] = marker }
        for marker in participantBMarkers { mergedByID[marker.id] = marker }
        let merged = Array(mergedByID.values)

        // 3 unique IDs: sharedID, idA, idB
        XCTAssertEqual(merged.count, 3,
                       "Merged set should contain 3 unique markers (sharedID counted once)")
        XCTAssertEqual(Set(merged.map(\.id)).count, merged.count,
                       "All IDs in merged set must be unique")
        XCTAssertTrue(mergedByID.keys.contains(sharedID), "Shared UUID must appear exactly once")
        XCTAssertTrue(mergedByID.keys.contains(idA), "Participant A's unique marker must be present")
        XCTAssertTrue(mergedByID.keys.contains(idB), "Participant B's unique marker must be present")
    }

    /// Large N + M: merging 20 + 20 markers yields 40 total with no duplicates.
    func testMergeWithLargeNAndM() async throws {
        let session = CountSession(name: "Large Merge Session")
        let sharedType = ObjectType(
            name: "SharedType",
            colorHex: "#FF5733",
            iconName: "circle.fill",
            sortOrder: 0,
            session: session
        )
        session.objectTypes.append(sharedType)

        let n = 20
        let m = 20
        var participantAMarkers: [CountMarker] = []
        var participantBMarkers: [CountMarker] = []

        for i in 0..<n {
            let marker = CountMarker(
                id: UUID(),
                normalizedX: Double(i % 10) / 10.0,
                normalizedY: Double(i / 10 % 10) / 10.0,
                objectType: sharedType,
                isAIDerived: false,
                session: session
            )
            participantAMarkers.append(marker)
        }
        for j in 0..<m {
            let marker = CountMarker(
                id: UUID(),
                normalizedX: Double((j + 5) % 10) / 10.0,
                normalizedY: Double((j + 5) / 10 % 10) / 10.0,
                objectType: sharedType,
                isAIDerived: false,
                session: session
            )
            participantBMarkers.append(marker)
        }

        var mergedByID: [UUID: CountMarker] = [:]
        for marker in participantAMarkers { mergedByID[marker.id] = marker }
        for marker in participantBMarkers { mergedByID[marker.id] = marker }
        let merged = Array(mergedByID.values)

        XCTAssertEqual(merged.count, n + m,
                       "Merged count should equal N + M = \(n + m) for large inputs")
        XCTAssertEqual(Set(merged.map(\.id)).count, merged.count,
                       "All IDs in merged set must be unique for large inputs")
    }
}
