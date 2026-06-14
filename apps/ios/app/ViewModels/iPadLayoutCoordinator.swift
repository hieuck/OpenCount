import SwiftUI
import UIKit

// MARK: - AnnotationTool

/// The active annotation tool on the counting canvas.
///
/// Used by `iPadLayoutCoordinator` to track which tool is currently selected,
/// and toggled via Apple Pencil double-tap (Requirement 31.4).
enum AnnotationTool: String, CaseIterable {
    case marker
    case regionDraw
    case textLabel
    case measureLine
    case arrow
}

// MARK: - iPadLayoutCoordinator

/// Manages adaptive layout state for iPad, including `NavigationSplitView` column
/// visibility, Apple Pencil connection state, and the active annotation tool.
///
/// Requirements: 31.1, 31.2, 31.4, 31.5
@MainActor
final class iPadLayoutCoordinator: ObservableObject {

    // MARK: - Published state

    /// Controls which columns are visible in the `NavigationSplitView`.
    /// Requirement 31.1: session list in sidebar, CountingView in detail column.
    @Published var columnVisibility: NavigationSplitViewVisibility = .automatic

    /// Whether an Apple Pencil is currently connected to the device.
    /// Requirement 31.4: respond to Pencil double-tap.
    @Published var isPencilConnected: Bool = false

    /// The currently active annotation tool.
    /// Requirement 31.4: toggle between .marker and .regionDraw on Pencil double-tap.
    @Published var activeTool: AnnotationTool = .marker

    /// The current hover point (in image-normalized coordinates) for the ghost marker preview.
    /// Requirement 31.5: show ghost marker before touch-down.
    @Published var hoverPoint: CGPoint? = nil

    // MARK: - Init

    init() {}

    // MARK: - Pencil double-tap

    /// Toggles the active tool between `.marker` and `.regionDraw` when the user
    /// double-taps the flat side of Apple Pencil (2nd generation or Pencil Pro).
    ///
    /// Requirement 31.4: Apple Pencil double-tap toggles between .marker and .regionDraw.
    func handlePencilDoubleTap() {
        switch activeTool {
        case .marker:
            activeTool = .regionDraw
        case .regionDraw:
            activeTool = .marker
        default:
            // For any other tool, double-tap returns to .marker
            activeTool = .marker
        }
        // Provide haptic feedback to confirm the tool switch
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    // MARK: - Pencil hover

    /// Updates the hover point for the ghost marker preview.
    ///
    /// Called by `UIHoverGestureRecognizer` as the Pencil approaches the screen.
    /// The point is in normalized image coordinates (0.0–1.0).
    ///
    /// Requirement 31.5: show ghost marker before touch-down.
    func handlePencilHover(at point: CGPoint, in imageSize: CGSize) {
        guard imageSize.width > 0, imageSize.height > 0 else {
            hoverPoint = nil
            return
        }
        // point is already expected in normalized coordinates from the caller
        hoverPoint = point
    }

    /// Clears the hover point (called when the Pencil lifts away from hover range).
    func clearHover() {
        hoverPoint = nil
    }
}
