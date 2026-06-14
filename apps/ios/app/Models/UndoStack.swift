import Foundation

/// A generic, value-type undo/redo stack.
///
/// `UndoStack<T>` stores snapshots of state. Calling `push` saves the current
/// state before a mutation. `undo` reverts to the previous snapshot; `redo`
/// re-applies a reverted snapshot. The stack is bounded by `capacity` (default 50)
/// to limit memory usage — the oldest entries are discarded when the limit is
/// exceeded.
struct UndoStack<T> {
    private var undoHistory: [T] = []
    private var redoHistory: [T] = []

    /// Maximum number of undo steps retained. Oldest entries are dropped when
    /// the limit is exceeded.
    let capacity: Int

    init(capacity: Int = 50) {
        self.capacity = capacity
    }

    // MARK: - Mutations

    /// Saves `state` onto the undo stack and clears the redo stack.
    ///
    /// Call this *before* applying a mutation so that `state` represents the
    /// value the user would want to return to on undo.
    mutating func push(_ state: T) {
        undoHistory.append(state)
        if undoHistory.count > capacity {
            undoHistory.removeFirst()
        }
        redoHistory.removeAll()
    }

    /// Reverts to the most recently pushed state.
    ///
    /// - Parameter currentState: The state *before* the undo is applied. This
    ///   is pushed onto the redo stack so the operation can be re-applied.
    /// - Returns: The previous state, or `nil` if there is nothing to undo.
    mutating func undo(currentState: T) -> T? {
        guard let previous = undoHistory.popLast() else { return nil }
        redoHistory.append(currentState)
        return previous
    }

    /// Re-applies the most recently undone state.
    ///
    /// - Parameter currentState: The state *before* the redo is applied. This
    ///   is pushed back onto the undo stack.
    /// - Returns: The re-applied state, or `nil` if there is nothing to redo.
    mutating func redo(currentState: T) -> T? {
        guard let next = redoHistory.popLast() else { return nil }
        undoHistory.append(currentState)
        return next
    }

    // MARK: - Queries

    /// `true` when there is at least one state available to undo.
    var canUndo: Bool { !undoHistory.isEmpty }

    /// `true` when there is at least one state available to redo.
    var canRedo: Bool { !redoHistory.isEmpty }
}
