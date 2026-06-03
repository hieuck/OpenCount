import SwiftUI
import UIKit
import PencilKit

// MARK: - PencilCanvasView

/// A `UIViewRepresentable` that wraps `PKCanvasView` to provide Apple Pencil drawing
/// support on top of the `ImageCanvas`.
///
/// - Pencil-drawn strokes are converted to normalized polygon points and added as
///   `CountRegion` objects via the `onRegionDrawn` callback.
/// - Apple Pencil double-tap is handled via `UIPencilInteraction` and forwarded to
///   `iPadLayoutCoordinator.handlePencilDoubleTap()`.
/// - Pencil hover preview is implemented via `UIHoverGestureRecognizer` (iPadOS 16.1+)
///   to show a ghost marker before touch-down.
///
/// Requirements: 31.3, 31.4, 31.5
struct PencilCanvasView: UIViewRepresentable {

    // MARK: - Bindings / callbacks

    /// The size of the underlying image canvas, used for coordinate normalization.
    let canvasSize: CGSize

    /// The coordinator that manages the active tool and hover state.
    @ObservedObject var coordinator: iPadLayoutCoordinator

    /// Called when the user finishes drawing a stroke in `.regionDraw` mode.
    /// Receives an array of normalized polygon points (0.0–1.0).
    var onRegionDrawn: ([CGPoint]) -> Void

    // MARK: - UIViewRepresentable

    func makeUIView(context: Context) -> PKCanvasView {
        let canvas = PKCanvasView()
        canvas.backgroundColor = .clear
        canvas.isOpaque = false
        canvas.drawingPolicy = .pencilOnly
        canvas.delegate = context.coordinator

        // Configure the initial tool based on the active annotation tool
        canvas.tool = context.coordinator.pencilTool(for: coordinator.activeTool)

        // Apple Pencil double-tap interaction — Requirement 31.4
        let pencilInteraction = UIPencilInteraction()
        pencilInteraction.delegate = context.coordinator
        canvas.addInteraction(pencilInteraction)

        // Pencil hover preview via UIHoverGestureRecognizer — Requirement 31.5
        // Available on iOS 16.1+
        if #available(iOS 16.1, *) {
            let hoverRecognizer = UIHoverGestureRecognizer(
                target: context.coordinator,
                action: #selector(Coordinator.handleHover(_:))
            )
            canvas.addGestureRecognizer(hoverRecognizer)
        }

        return canvas
    }

    func updateUIView(_ uiView: PKCanvasView, context: Context) {
        // Update the tool when the active annotation tool changes
        uiView.tool = context.coordinator.pencilTool(for: coordinator.activeTool)
        context.coordinator.canvasSize = canvasSize
        context.coordinator.onRegionDrawn = onRegionDrawn
        context.coordinator.layoutCoordinator = coordinator
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(
            canvasSize: canvasSize,
            layoutCoordinator: coordinator,
            onRegionDrawn: onRegionDrawn
        )
    }

    // MARK: - Coordinator

    final class Coordinator: NSObject, PKCanvasViewDelegate, UIPencilInteractionDelegate {

        var canvasSize: CGSize
        var layoutCoordinator: iPadLayoutCoordinator
        var onRegionDrawn: ([CGPoint]) -> Void

        init(
            canvasSize: CGSize,
            layoutCoordinator: iPadLayoutCoordinator,
            onRegionDrawn: @escaping ([CGPoint]) -> Void
        ) {
            self.canvasSize = canvasSize
            self.layoutCoordinator = layoutCoordinator
            self.onRegionDrawn = onRegionDrawn
        }

        // MARK: - PKCanvasViewDelegate

        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            // Only process strokes in regionDraw mode
            guard layoutCoordinator.activeTool == .regionDraw else {
                // Clear any accidental strokes in non-region modes
                canvasView.drawing = PKDrawing()
                return
            }

            let drawing = canvasView.drawing
            guard !drawing.strokes.isEmpty else { return }

            // Convert the last stroke to normalized polygon points
            if let lastStroke = drawing.strokes.last {
                let points = normalizedPoints(from: lastStroke, canvasSize: canvasSize)
                if points.count >= 3 {
                    onRegionDrawn(points)
                }
            }

            // Clear the canvas after extracting the stroke so it doesn't accumulate
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                canvasView.drawing = PKDrawing()
            }
        }

        // MARK: - UIPencilInteractionDelegate (Requirement 31.4)

        func pencilInteractionDidTap(_ interaction: UIPencilInteraction) {
            Task { @MainActor in
                self.layoutCoordinator.handlePencilDoubleTap()
            }
        }

        // MARK: - Hover gesture (Requirement 31.5)

        @objc func handleHover(_ recognizer: UIHoverGestureRecognizer) {
            guard let view = recognizer.view else { return }
            let location = recognizer.location(in: view)

            switch recognizer.state {
            case .began, .changed:
                let normalized = CGPoint(
                    x: location.x / max(canvasSize.width, 1),
                    y: location.y / max(canvasSize.height, 1)
                )
                Task { @MainActor in
                    self.layoutCoordinator.handlePencilHover(
                        at: normalized,
                        in: self.canvasSize
                    )
                }
            case .ended, .cancelled, .failed:
                Task { @MainActor in
                    self.layoutCoordinator.clearHover()
                }
            default:
                break
            }
        }

        // MARK: - Tool helpers

        /// Returns the appropriate `PKTool` for the given `AnnotationTool`.
        func pencilTool(for tool: AnnotationTool) -> PKTool {
            switch tool {
            case .regionDraw:
                // Use a thin ink pen for region drawing
                return PKInkingTool(.pen, color: UIColor.systemBlue.withAlphaComponent(0.6), width: 3)
            case .marker, .textLabel, .measureLine, .arrow:
                // For non-drawing tools, use a lasso so Pencil touches don't draw
                return PKLassoTool()
            }
        }

        // MARK: - Stroke conversion

        /// Converts a `PKStroke` path to an array of normalized polygon points.
        ///
        /// Samples the stroke at regular intervals to produce a polygon with a
        /// manageable number of vertices. Points are normalized to [0, 1] relative
        /// to `canvasSize`.
        ///
        /// Requirement 31.3: convert PKStroke path to normalized polygon points for CountRegion.
        private func normalizedPoints(from stroke: PKStroke, canvasSize: CGSize) -> [CGPoint] {
            guard canvasSize.width > 0, canvasSize.height > 0 else { return [] }

            let path = stroke.path
            guard path.count > 0 else { return [] }

            // Sample at most 64 points to keep the polygon manageable
            let maxPoints = 64
            let stride = max(1, path.count / maxPoints)

            var points: [CGPoint] = []
            var index = 0
            while index < path.count {
                let strokePoint = path[index]
                let normalized = CGPoint(
                    x: strokePoint.location.x / canvasSize.width,
                    y: strokePoint.location.y / canvasSize.height
                )
                // Clamp to [0, 1]
                let clamped = CGPoint(
                    x: min(max(normalized.x, 0), 1),
                    y: min(max(normalized.y, 0), 1)
                )
                points.append(clamped)
                index += stride
            }

            // Ensure the polygon is closed by appending the first point if needed
            if let first = points.first, let last = points.last, first != last {
                points.append(first)
            }

            return points
        }
    }
}

// MARK: - GhostMarkerOverlay

/// A semi-transparent marker shown at the Pencil hover position before touch-down.
///
/// Requirement 31.5: show a ghost marker before touch-down.
struct GhostMarkerOverlay: View {

    /// The hover point in normalized image coordinates (0.0–1.0).
    let hoverPoint: CGPoint
    /// The canvas size used to convert normalized coordinates to screen points.
    let canvasSize: CGSize
    /// The color of the currently selected Object_Type.
    let markerColor: Color

    private var screenPosition: CGPoint {
        CGPoint(
            x: hoverPoint.x * canvasSize.width,
            y: hoverPoint.y * canvasSize.height
        )
    }

    var body: some View {
        Circle()
            .fill(markerColor.opacity(0.35))
            .overlay(
                Circle()
                    .strokeBorder(markerColor.opacity(0.7), lineWidth: 2)
            )
            .frame(width: 24, height: 24)
            .position(screenPosition)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
            .animation(.easeInOut(duration: 0.08), value: hoverPoint)
    }
}
