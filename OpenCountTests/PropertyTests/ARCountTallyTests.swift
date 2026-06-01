import XCTest
import SwiftCheck
import simd
@testable import OpenCount

// Feature: open-count-ios, Property 11: AR anchor tally equals placed anchor count
// Validates: Requirements 19.2

// MARK: - Helpers

/// A lightweight description of an anchor operation used in property tests.
private enum AnchorOp: CustomStringConvertible {
    case place(typeIndex: Int)   // place an anchor for the object type at this index
    case remove(anchorIndex: Int) // remove the anchor at this index (no-op if out of range)

    var description: String {
        switch self {
        case .place(let i):  return "place(typeIndex:\(i))"
        case .remove(let i): return "remove(anchorIndex:\(i))"
        }
    }
}

extension AnchorOp: Arbitrary {
    public static var arbitrary: Gen<AnchorOp> {
        Gen<Int>.choose((0, 1)).flatMap { choice in
            if choice == 0 {
                // place: type index in 0..<typeCount; we use a small range and clamp in the test
                return Gen<Int>.choose((0, 4)).map { .place(typeIndex: $0) }
            } else {
                // remove: anchor index in 0..<anchorCount; we clamp in the test
                return Gen<Int>.choose((0, 19)).map { .remove(anchorIndex: $0) }
            }
        }
    }
}

// MARK: - Tests

final class ARCountTallyTests: XCTestCase {

    // MARK: - Property 11: AR anchor tally equals placed anchor count
    //
    // For any sequence of anchor placements and removals, the globalTally for
    // each ObjectType SHALL equal the number of currently active (not removed)
    // anchors of that type.
    //
    // Validates: Requirements 19.2

    func testARTallyEqualsActivePlacedAnchorCount() {
        // SwiftCheck property: for any random sequence of place/remove operations
        // across a fixed set of ObjectTypes, globalTally[type] must always equal
        // the number of arAnchors currently associated with that type.
        property("AR anchor tally equals active placed anchor count") <- forAll(
            Gen<Int>.choose((1, 5)),   // number of distinct object types
            Gen<[AnchorOp]>.sized { size in
                let count = max(1, size % 30 + 1)
                return sequence(Array(repeating: AnchorOp.arbitrary, count: count))
            }
        ) { typeCount, ops in
            let semaphore = DispatchSemaphore(value: 0)
            var result = false

            Task { @MainActor in
                defer { semaphore.signal() }
                result = Self.arTallyPropertyHolds(typeCount: typeCount, ops: ops)
            }

            semaphore.wait()
            return result
        }
    }

    // MARK: - Core property helper

    /// Applies a sequence of place/remove operations to an ARCountViewModel and
    /// asserts that globalTally[type] == arAnchors.filter { $0.objectType.id == type.id }.count
    /// after every operation.
    @MainActor
    private static func arTallyPropertyHolds(typeCount: Int, ops: [AnchorOp]) -> Bool {
        let viewModel = ARCountViewModel()

        // Build a fixed set of ObjectType instances (not persisted — ARCountViewModel
        // only needs the ObjectType value, not a SwiftData context).
        var objectTypes: [ObjectType] = []
        for i in 0..<typeCount {
            let ot = ObjectType(
                name: "ARType \(i)",
                colorHex: String(format: "#%06X", (i + 1) * 0x111111 % 0xFFFFFF),
                iconName: "circle.fill",
                sortOrder: i
            )
            objectTypes.append(ot)
        }

        // Apply each operation and verify the tally invariant after each step.
        for op in ops {
            switch op {
            case .place(let typeIndex):
                let ot = objectTypes[typeIndex % typeCount]
                viewModel.selectedObjectType = ot
                viewModel.placeAnchor(at: matrix_identity_float4x4)

            case .remove(let anchorIndex):
                guard !viewModel.arAnchors.isEmpty else { continue }
                let idx = anchorIndex % viewModel.arAnchors.count
                viewModel.removeAnchor(viewModel.arAnchors[idx])
            }

            // Invariant: globalTally[type] == active anchor count for that type
            for ot in objectTypes {
                let activeCount = viewModel.arAnchors.filter { $0.objectType.id == ot.id }.count
                let tallyCount = viewModel.globalTally[ot] ?? 0
                if tallyCount != activeCount {
                    return false
                }
            }
        }

        return true
    }

    // MARK: - Unit test: placing N anchors of type A and M of type B

    func testPlacingNAnchorsOfTypeAAndMOfTypeBGivesCorrectTallies() {
        let semaphore = DispatchSemaphore(value: 0)
        var passed = false

        Task { @MainActor in
            defer { semaphore.signal() }

            let viewModel = ARCountViewModel()
            let typeA = ObjectType(name: "TypeA", colorHex: "#FF0000", iconName: "circle.fill", sortOrder: 0)
            let typeB = ObjectType(name: "TypeB", colorHex: "#0000FF", iconName: "star.fill", sortOrder: 1)

            let n = 7
            let m = 4

            // Place N anchors of type A
            viewModel.selectedObjectType = typeA
            for _ in 0..<n {
                viewModel.placeAnchor(at: matrix_identity_float4x4)
            }

            // Place M anchors of type B
            viewModel.selectedObjectType = typeB
            for _ in 0..<m {
                viewModel.placeAnchor(at: matrix_identity_float4x4)
            }

            let tallyA = viewModel.globalTally[typeA] ?? 0
            let tallyB = viewModel.globalTally[typeB] ?? 0

            passed = (tallyA == n) && (tallyB == m)
        }

        semaphore.wait()
        XCTAssertTrue(passed, "Tally[A] should be \(7) and Tally[B] should be \(4)")
    }

    // MARK: - Unit test: removing an anchor decrements tally by exactly 1

    func testRemovingAnchorDecrementsTallyByExactlyOne() {
        let semaphore = DispatchSemaphore(value: 0)
        var passed = false

        Task { @MainActor in
            defer { semaphore.signal() }

            let viewModel = ARCountViewModel()
            let objectType = ObjectType(name: "RemoveType", colorHex: "#00FF00", iconName: "heart.fill", sortOrder: 0)

            // Place 5 anchors
            viewModel.selectedObjectType = objectType
            for _ in 0..<5 {
                viewModel.placeAnchor(at: matrix_identity_float4x4)
            }

            let tallyBefore = viewModel.globalTally[objectType] ?? 0
            XCTAssertEqual(tallyBefore, 5, "Tally should be 5 after placing 5 anchors")

            // Remove one anchor
            guard let anchorToRemove = viewModel.arAnchors.first else {
                passed = false
                return
            }
            viewModel.removeAnchor(anchorToRemove)

            let tallyAfter = viewModel.globalTally[objectType] ?? 0
            passed = (tallyAfter == tallyBefore - 1)
        }

        semaphore.wait()
        XCTAssertTrue(passed, "Removing an anchor should decrement the tally by exactly 1")
    }

    // MARK: - Unit test: tally is zero when no anchors are placed

    func testTallyIsZeroWithNoAnchors() {
        let semaphore = DispatchSemaphore(value: 0)
        var passed = false

        Task { @MainActor in
            defer { semaphore.signal() }
            let viewModel = ARCountViewModel()
            let objectType = ObjectType(name: "EmptyType", colorHex: "#AAAAAA", iconName: "circle.fill", sortOrder: 0)
            let tally = viewModel.globalTally[objectType] ?? 0
            passed = (tally == 0)
        }

        semaphore.wait()
        XCTAssertTrue(passed, "Tally should be 0 when no anchors have been placed")
    }

    // MARK: - Unit test: removing all anchors of a type gives tally of zero

    func testRemovingAllAnchorsGivesTallyOfZero() {
        let semaphore = DispatchSemaphore(value: 0)
        var passed = false

        Task { @MainActor in
            defer { semaphore.signal() }

            let viewModel = ARCountViewModel()
            let objectType = ObjectType(name: "ClearType", colorHex: "#FF5733", iconName: "leaf.fill", sortOrder: 0)

            viewModel.selectedObjectType = objectType
            for _ in 0..<3 {
                viewModel.placeAnchor(at: matrix_identity_float4x4)
            }

            // Remove all anchors
            let anchorsToRemove = viewModel.arAnchors
            for anchor in anchorsToRemove {
                viewModel.removeAnchor(anchor)
            }

            let tally = viewModel.globalTally[objectType] ?? 0
            passed = (tally == 0)
        }

        semaphore.wait()
        XCTAssertTrue(passed, "Tally should be 0 after removing all anchors of a type")
    }

    // MARK: - Unit test: placing without selectedObjectType does not add anchors

    func testPlaceAnchorWithNoSelectedTypeDoesNothing() {
        let semaphore = DispatchSemaphore(value: 0)
        var passed = false

        Task { @MainActor in
            defer { semaphore.signal() }
            let viewModel = ARCountViewModel()
            // selectedObjectType is nil by default
            viewModel.placeAnchor(at: matrix_identity_float4x4)
            passed = viewModel.arAnchors.isEmpty && viewModel.globalTally.isEmpty
        }

        semaphore.wait()
        XCTAssertTrue(passed, "Placing an anchor without a selected type should be a no-op")
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
