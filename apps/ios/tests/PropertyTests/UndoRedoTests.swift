import XCTest
import SwiftCheck
@testable import OpenCount

// Feature: open-count-ios, Property 2: Undo/redo round-trip restores original state
// Validates: Requirements 3.5, 3.6

// MARK: - Lightweight state model for UndoStack testing
//
// We test UndoStack<[Int]> directly — a list of integers stands in for a
// "list of marker IDs". This keeps the test self-contained and avoids any
// dependency on CountingViewModel (which is not yet implemented).

/// The two operations that can be applied to the marker list.
private enum MarkerOp: CustomStringConvertible {
    case place(Int)   // append a marker with the given ID
    case delete(Int)  // remove the first marker with the given ID (no-op if absent)

    var description: String {
        switch self {
        case .place(let id):  return "place(\(id))"
        case .delete(let id): return "delete(\(id))"
        }
    }
}

/// Apply a single operation to a marker list, returning the new list.
private func apply(_ op: MarkerOp, to state: [Int]) -> [Int] {
    switch op {
    case .place(let id):
        return state + [id]
    case .delete(let id):
        var next = state
        if let idx = next.firstIndex(of: id) { next.remove(at: idx) }
        return next
    }
}

// MARK: - Arbitrary instances

extension MarkerOp: Arbitrary {
    public static var arbitrary: Gen<MarkerOp> {
        // Use a small ID space (0–9) so deletions frequently hit existing markers.
        let idGen = Gen<Int>.choose((0, 9))
        return Gen<Int>.choose((0, 1)).flatMap { choice in
            idGen.map { id in
                choice == 0 ? .place(id) : .delete(id)
            }
        }
    }
}

// MARK: - Tests

final class UndoRedoTests: XCTestCase {

    // MARK: Property 2: Undo/redo round-trip restores original state
    //
    // For any sequence of marker placement and deletion operations, applying
    // undo for each operation in reverse order SHALL restore the session to its
    // exact original state (same markers, same tallies).
    //
    // Validates: Requirements 3.5, 3.6

    func testUndoRedoRoundTripRestoresOriginalState() {
        // SwiftCheck property: for any random sequence of marker operations,
        // undoing all of them in reverse order returns the state to what it was
        // before any operation was applied.
        property("Undo/redo round-trip restores original state") <- forAll(
            Gen<[MarkerOp]>.sized { size in
                // Generate between 1 and max(1, size) operations so we always
                // have at least one operation to undo.
                let count = max(1, size % 20 + 1)
                return sequence(Array(repeating: MarkerOp.arbitrary, count: count))
            }
        ) { (ops: [MarkerOp]) in
            var stack = UndoStack<[Int]>(capacity: 50)
            var state: [Int] = []
            let originalState = state

            // Apply all operations, pushing the pre-mutation state each time.
            for op in ops {
                stack.push(state)
                state = apply(op, to: state)
            }

            // Undo every operation in reverse order.
            for _ in ops {
                guard let previous = stack.undo(currentState: state) else {
                    // If undo returns nil before we've undone all ops, the
                    // capacity was exceeded — that's acceptable; just stop.
                    break
                }
                state = previous
            }

            // After undoing all ops (or as many as the stack retained), the
            // state must equal the original empty list.
            return state == originalState
        }
    }

    // MARK: - Additional property: undo/redo cycle preserves state

    func testUndoThenRedoRestoresStateAfterOperations() {
        // For any sequence of operations, undoing all of them and then redoing
        // all of them must return to the state after all operations were applied.
        property("Undo-all then redo-all returns to post-operation state") <- forAll(
            Gen<[MarkerOp]>.sized { size in
                let count = max(1, size % 15 + 1)
                return sequence(Array(repeating: MarkerOp.arbitrary, count: count))
            }
        ) { (ops: [MarkerOp]) in
            var stack = UndoStack<[Int]>(capacity: 50)
            var state: [Int] = []

            // Apply all operations.
            for op in ops {
                stack.push(state)
                state = apply(op, to: state)
            }
            let stateAfterAllOps = state

            // Undo all.
            while stack.canUndo {
                if let previous = stack.undo(currentState: state) {
                    state = previous
                } else { break }
            }

            // Redo all.
            while stack.canRedo {
                if let next = stack.redo(currentState: state) {
                    state = next
                } else { break }
            }

            return state == stateAfterAllOps
        }
    }

    // MARK: - Unit tests

    /// Undoing a single placement removes the placed marker.
    func testUndoSinglePlacement() {
        var stack = UndoStack<[Int]>(capacity: 50)
        var state: [Int] = []

        stack.push(state)
        state = apply(.place(42), to: state)
        XCTAssertEqual(state, [42])

        state = stack.undo(currentState: state) ?? state
        XCTAssertEqual(state, [], "Undo should remove the placed marker")
    }

    /// Undoing a deletion restores the deleted marker.
    func testUndoSingleDeletion() {
        var stack = UndoStack<[Int]>(capacity: 50)
        var state = [1, 2, 3]

        stack.push(state)
        state = apply(.delete(2), to: state)
        XCTAssertEqual(state, [1, 3])

        state = stack.undo(currentState: state) ?? state
        XCTAssertEqual(state, [1, 2, 3], "Undo should restore the deleted marker")
    }

    /// Undo returns nil on an empty stack.
    func testUndoOnEmptyStackReturnsNil() {
        var stack = UndoStack<[Int]>(capacity: 50)
        let state = [1, 2, 3]
        XCTAssertNil(stack.undo(currentState: state), "Undo on empty stack should return nil")
        XCTAssertFalse(stack.canUndo)
    }

    /// Redo returns nil when there is nothing to redo.
    func testRedoOnEmptyRedoStackReturnsNil() {
        var stack = UndoStack<[Int]>(capacity: 50)
        let state = [1, 2, 3]
        XCTAssertNil(stack.redo(currentState: state), "Redo on empty redo stack should return nil")
        XCTAssertFalse(stack.canRedo)
    }

    /// Pushing a new state after an undo clears the redo stack.
    func testPushAfterUndoClearsRedoStack() {
        var stack = UndoStack<[Int]>(capacity: 50)
        var state: [Int] = []

        stack.push(state)
        state = apply(.place(1), to: state)  // state = [1]

        stack.push(state)
        state = apply(.place(2), to: state)  // state = [1, 2]

        // Undo: back to [1]
        state = stack.undo(currentState: state) ?? state
        XCTAssertEqual(state, [1])
        XCTAssertTrue(stack.canRedo)

        // Push a new operation — redo stack must be cleared
        stack.push(state)
        state = apply(.place(99), to: state)  // state = [1, 99]
        XCTAssertFalse(stack.canRedo, "Redo stack must be cleared after a new push")
    }

    /// The stack respects its capacity limit and drops the oldest entries.
    func testCapacityLimitDropsOldestEntries() {
        let capacity = 3
        var stack = UndoStack<[Int]>(capacity: capacity)
        var state: [Int] = []

        // Push 5 states (exceeds capacity of 3)
        for i in 0..<5 {
            stack.push(state)
            state = apply(.place(i), to: state)
        }
        // state = [0, 1, 2, 3, 4]; only last 3 pushes are retained

        // We should be able to undo exactly `capacity` times.
        var undoCount = 0
        while stack.canUndo {
            state = stack.undo(currentState: state) ?? state
            undoCount += 1
        }
        XCTAssertEqual(undoCount, capacity,
                       "Should be able to undo exactly \(capacity) times (capacity limit)")
    }

    /// canUndo and canRedo reflect the correct state after a sequence of operations.
    func testCanUndoCanRedoFlags() {
        var stack = UndoStack<[Int]>(capacity: 50)
        var state: [Int] = []

        XCTAssertFalse(stack.canUndo)
        XCTAssertFalse(stack.canRedo)

        stack.push(state)
        state = apply(.place(1), to: state)
        XCTAssertTrue(stack.canUndo)
        XCTAssertFalse(stack.canRedo)

        state = stack.undo(currentState: state) ?? state
        XCTAssertFalse(stack.canUndo)
        XCTAssertTrue(stack.canRedo)

        state = stack.redo(currentState: state) ?? state
        XCTAssertTrue(stack.canUndo)
        XCTAssertFalse(stack.canRedo)
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
