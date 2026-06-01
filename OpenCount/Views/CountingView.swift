import SwiftUI
import UIKit
import PencilKit

// MARK: - CountingView

/// The main counting screen for a session.
///
/// Displays a zoomable/pannable image canvas with tap-to-place markers,
/// a long-press context menu on markers for delete/reassign, and a
/// horizontal ObjectTypeToolbar at the bottom.
///
/// On iPad (regular horizontal size class), also shows a `PencilCanvasView` overlay
/// for Apple Pencil region drawing, and registers keyboard shortcuts.
///
/// Requirements: 3.2, 3.3, 3.8, 3.9, 6.2, 6.3, 6.4, 10.4, 31.3, 31.4, 31.5, 31.6
struct CountingView: View {

    // MARK: - ViewModel

    @StateObject private var viewModel: CountingViewModel

    // MARK: - iPad layout coordinator

    /// Manages column visibility and active annotation tool on iPad.
    /// Requirement 31.2: iPadLayoutCoordinator managing column visibility.
    /// A local fallback is used on iPhone where the coordinator is not injected.
    @StateObject private var localIPadCoordinator = iPadLayoutCoordinator()

    // MARK: - Environment

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    // MARK: - Local UI state

    /// Whether the AI control panel is expanded.
    @State private var isAIPanelExpanded: Bool = false

    /// Whether the live camera counting sheet is presented.
    /// Requirement 9.1: present live camera counting from the counting screen.
    @State private var isLiveCameraPresented: Bool = false

    /// Whether the batch job sheet is presented.
    /// Requirement 10.1: allow the user to start a Batch_Job from the counting screen.
    @State private var isBatchJobPresented: Bool = false

    /// Whether the video counting sheet is presented.
    /// Requirement 11.1: allow the user to count objects in video frames.
    @State private var isVideoCountPresented: Bool = false

    /// Whether the export sheet is presented.
    /// Requirement 12.5: present the export sheet from the counting screen.
    @State private var isExportSheetPresented: Bool = false

    /// Whether the statistics view is presented.
    /// Requirement 13.1–13.6: present statistics and history from the counting screen.
    @State private var isStatisticsPresented: Bool = false

    /// Whether the AR counting view is presented.
    /// Requirement 19.1: present AR counting from the counting screen.
    @State private var isARCountPresented: Bool = false

    /// Whether the layer panel is presented.
    /// Requirement 34.5: show/hide annotation layers.
    @State private var isLayerPanelPresented: Bool = false

    /// Whether the new session sheet is presented (keyboard shortcut ⌘N).
    /// Requirement 31.6: ⌘N keyboard shortcut.
    @State private var isNewSessionSheetPresented: Bool = false

    /// Whether the Review Mode sheet is presented.
    /// Requirement 35.5: step through all markers one by one.
    @State private var isReviewModePresented: Bool = false

    /// Whether the Count History view is presented.
    /// Requirement 47 (Req 36): audit log of all tally changes.
    @State private var isCountHistoryPresented: Bool = false

    /// Annotation layer view model for advanced annotation tools.
    @StateObject private var annotationViewModel = AnnotationLayerViewModel()

    // MARK: - Init

    init(session: CountSession) {
        _viewModel = StateObject(wrappedValue: CountingViewModel(session: session))
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            // Image canvas fills available space, with optional grid overlay
            ZStack {
                ImageCanvas(viewModel: viewModel)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                // Grid overlay — rendered on top of the canvas when enabled
                if viewModel.isGridOverlayEnabled {
                    GeometryReader { geometry in
                        GridOverlayView(
                            density: viewModel.gridDensity,
                            completedCells: viewModel.completedCells,
                            lineColor: .blue,
                            lineOpacity: 0.7,
                            onCellTapped: { index in
                                viewModel.toggleCell(index)
                            }
                        )
                        .frame(width: geometry.size.width, height: geometry.size.height)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .allowsHitTesting(true)
                }

                // Apple Pencil canvas overlay — iPad only (Requirement 31.3)
                // Renders a PKCanvasView on top of the image canvas for Pencil-drawn
                // region strokes. Only active in .regionDraw mode.
                if horizontalSizeClass == .regular {
                    GeometryReader { geometry in
                        PencilCanvasView(
                            canvasSize: geometry.size,
                            coordinator: localIPadCoordinator,
                            onRegionDrawn: { points in
                                // Convert drawn polygon to a CountRegion
                                let region = CountRegion(
                                    name: "Pencil Region \(viewModel.regions.count + 1)",
                                    colorHex: "#3399FF",
                                    shapeType: .polygon,
                                    normalizedPoints: points,
                                    session: viewModel.session
                                )
                                viewModel.addRegion(region)
                            }
                        )
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        // Only intercept touches in regionDraw mode; pass through otherwise
                        .allowsHitTesting(localIPadCoordinator.activeTool == .regionDraw)

                        // Ghost marker hover preview — Requirement 31.5
                        if let hoverPoint = localIPadCoordinator.hoverPoint,
                           localIPadCoordinator.activeTool == .marker {
                            let markerColor: Color = {
                                if let type = viewModel.selectedObjectType {
                                    return Color(hex: type.colorHex) ?? .accentColor
                                }
                                return .accentColor
                            }()
                            GhostMarkerOverlay(
                                hoverPoint: hoverPoint,
                                canvasSize: geometry.size,
                                markerColor: markerColor
                            )
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }

                // AI inference progress bar — floats at the top of the canvas
                // Requirement 5.7: show progress during AI inference
                if viewModel.isAIRunning {
                    VStack {
                        AIProgressBar(progress: viewModel.aiProgress)
                            .padding(.horizontal, 16)
                            .padding(.top, 8)
                        Spacer()
                    }
                }

                // Confetti burst when a count target is first reached
                // Requirement 53 (Req 42)
                if viewModel.shouldFireConfetti {
                    ConfettiView(isActive: viewModel.shouldFireConfetti)
                        .allowsHitTesting(false)
                        .ignoresSafeArea()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            // AI control panel — shown when expanded or when AI is running
            if isAIPanelExpanded || viewModel.isAIRunning {
                AIControlPanel(viewModel: viewModel)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            // Horizontal object-type toolbar at the bottom
            ObjectTypeToolbar(viewModel: viewModel)
        }
        .navigationTitle(viewModel.session.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                // Export button
                // Requirement 12.5: open export sheet to share session data
                Button {
                    isExportSheetPresented = true
                } label: {
                    Image(systemName: "square.and.arrow.up")
                }
                .accessibilityLabel("Export session")
                .accessibilityHint("Tap to export this session as CSV, JSON, annotated image, or PDF.")
                // Keyboard shortcut ⌘E — Requirement 31.6
                .keyboardShortcut("e", modifiers: .command)

                // Statistics button
                // Requirements 13.1–13.6: open statistics and history view
                Button {
                    isStatisticsPresented = true
                } label: {
                    Image(systemName: "chart.bar.xaxis")
                }
                .accessibilityLabel("Statistics")
                .accessibilityHint("Tap to view tally statistics, charts, and counting history for this session.")

                // Count History button — Requirement 47 (Req 36)
                Button {
                    isCountHistoryPresented = true
                } label: {
                    Image(systemName: "clock.arrow.circlepath")
                }
                .accessibilityLabel("Count history")
                .accessibilityHint("Tap to view the audit log of all tally changes for this session.")

                // Batch processing button
                // Requirement 10.1: open batch job view for processing multiple images
                Button {
                    isBatchJobPresented = true
                } label: {
                    Image(systemName: "photo.stack")
                }
                .accessibilityLabel("Batch processing")
                .accessibilityHint("Tap to open batch AI processing for all images in this session.")

                // Video counting button
                // Requirement 11.1: open video frame counting view
                Button {
                    isVideoCountPresented = true
                } label: {
                    Image(systemName: "film")
                }
                .accessibilityLabel("Video counting")
                .accessibilityHint("Tap to open video frame-by-frame counting.")

                // AR counting button
                // Requirement 19.1: open AR counting view
                Button {
                    isARCountPresented = true
                } label: {
                    Image(systemName: "arkit")
                }
                .accessibilityLabel("AR counting")
                .accessibilityHint("Tap to open augmented reality counting.")

                // Annotation layers button
                // Requirement 34.5: show/hide annotation layers
                Button {
                    isLayerPanelPresented = true
                } label: {
                    Image(systemName: "square.3.layers.3d")
                }
                .accessibilityLabel("Annotation layers")
                .accessibilityHint("Tap to manage annotation layers and tools.")

                // Live camera counting button
                // Requirement 9.1: open live camera counting view
                Button {
                    isLiveCameraPresented = true
                } label: {
                    Image(systemName: "camera.viewfinder")
                }
                .accessibilityLabel("Live camera counting")
                .accessibilityHint("Tap to open the live camera for real-time AI counting.")

                // AI panel toggle button
                // Requirement 5.4: show AI detection controls
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isAIPanelExpanded.toggle()
                    }
                } label: {
                    Image(systemName: isAIPanelExpanded
                          ? "brain.head.profile.fill"
                          : "brain.head.profile")
                }
                .accessibilityLabel(isAIPanelExpanded ? "Hide AI panel" : "Show AI panel")
                .accessibilityHint(
                    isAIPanelExpanded
                        ? "Tap to hide the AI detection controls."
                        : "Tap to show AI detection controls including confidence threshold."
                )

                // Grid toggle button
                Button {
                    viewModel.isGridOverlayEnabled.toggle()
                } label: {
                    Image(systemName: viewModel.isGridOverlayEnabled
                          ? "grid.circle.fill"
                          : "grid.circle")
                }
                .accessibilityLabel(
                    viewModel.isGridOverlayEnabled ? "Hide grid overlay" : "Show grid overlay"
                )
                .accessibilityHint(
                    viewModel.isGridOverlayEnabled
                        ? "Tap to hide the counting grid."
                        : "Tap to show a grid over the image for systematic counting."
                )

                // Redo
                Button {
                    viewModel.redo()
                } label: {
                    Image(systemName: "arrow.uturn.forward")
                }
                .disabled(!viewModel.canRedo)
                .accessibilityLabel("Redo")
                .accessibilityHint("Redo the last undone counting action.")
                // Keyboard shortcut ⌘⇧Z — Requirement 31.6
                .keyboardShortcut("z", modifiers: [.command, .shift])

                // Undo
                Button {
                    viewModel.undo()
                } label: {
                    Image(systemName: "arrow.uturn.backward")
                }
                .disabled(!viewModel.canUndo)
                .accessibilityLabel("Undo")
                .accessibilityHint("Undo the last counting action.")
                // Keyboard shortcut ⌘Z — Requirement 31.6
                .keyboardShortcut("z", modifiers: .command)
            }
        }
        // Shake-to-undo via onShake (iOS 16+ motion notification)
        .onReceive(NotificationCenter.default.publisher(for: .deviceDidShake)) { _ in
            viewModel.undo()
        }
        // Keyboard shortcut: Space — place a marker at the canvas center (Requirement 31.6)
        // This is registered as a hidden button so it participates in the responder chain.
        .background(
            Button("") {
                // Place a marker at the normalized center of the image
                viewModel.placeMarker(at: CGPoint(x: 0.5, y: 0.5))
            }
            .keyboardShortcut(.space, modifiers: [])
            .opacity(0)
            .accessibilityHidden(true)
        )
        .alert(
            "Error",
            isPresented: Binding(
                get: { viewModel.error != nil },
                set: { if !$0 { viewModel.error = nil } }
            ),
            presenting: viewModel.error
        ) { _ in
            Button("OK", role: .cancel) { viewModel.error = nil }
        } message: { error in
            Text(error.localizedDescription)
        }
        // Handoff — Requirement 49 (Req 38)
        // Advertises the current session to nearby devices via NSUserActivity.
        // The receiving device handles this in OpenCountApp.onContinueUserActivity.
        .userActivity("com.opencount.counting") { activity in
            activity.title = viewModel.session.name
            activity.userInfo = [
                "sessionID": viewModel.session.id.uuidString,
                "imageIndex": 0
            ]
            activity.isEligibleForHandoff = true
            activity.isEligibleForSearch = true
            activity.becomeCurrent()
        }
        // Live camera counting — presented as a full-screen cover.
        // Requirement 9.1: activate the device camera for live counting.
        .fullScreenCover(isPresented: $isLiveCameraPresented) {
            LiveCountView(session: viewModel.session)
        }
        // Batch job — presented as a sheet.
        // Requirement 10.1: allow the user to process multiple images in a Batch_Job.
        .sheet(isPresented: $isBatchJobPresented) {
            BatchJobView(session: viewModel.session)
        }
        // Video counting — presented as a sheet.
        // Requirement 11.1: allow the user to count objects in video frames.
        .sheet(isPresented: $isVideoCountPresented) {
            VideoCountView(session: viewModel.session)
        }
        // Export sheet — presented as a sheet.
        // Requirement 12.5: allow the user to export session data in multiple formats.
        .sheet(isPresented: $isExportSheetPresented) {
            ExportSheet(session: viewModel.session, annotationViewModel: annotationViewModel)
        }
        // Statistics view — presented as a sheet.
        // Requirements 13.1–13.6: allow the user to view statistics and tally history.
        .sheet(isPresented: $isStatisticsPresented) {
            StatisticsView(session: viewModel.session, allSessions: [])
        }
        // AR counting — presented as a full-screen cover.
        // Requirement 19.1: activate ARKit for real-world counting.
        .fullScreenCover(isPresented: $isARCountPresented) {
            ARCountView(session: viewModel.session)
        }
        // Annotation layer panel — presented as a sheet.
        // Requirement 34.5: manage annotation layers and tools.
        .sheet(isPresented: $isLayerPanelPresented) {
            LayerPanelView(viewModel: annotationViewModel)
        }
        // Review Mode — step through all markers one by one.
        // Requirement 35.5
        .sheet(isPresented: $isReviewModePresented) {
            ReviewModeSheet(viewModel: viewModel)
        }
        // Count History — audit log of all tally changes.
        // Requirement 47 (Req 36)
        .sheet(isPresented: $isCountHistoryPresented) {
            CountHistoryView(session: viewModel.session)
        }
        // Fatigue warning banner — shown when counting velocity is too high.
        // Requirement 35.4
        .safeAreaInset(edge: .top, spacing: 0) {
            if viewModel.isFatigueWarningActive {
                FatigueWarningBanner {
                    viewModel.dismissFatigueWarning()
                }
                .transition(.move(edge: .top).combined(with: .opacity))
                .animation(.spring(response: 0.4, dampingFraction: 0.8),
                           value: viewModel.isFatigueWarningActive)
            }
        }
        // Duplicate marker confirmation dialog — Requirement 35.1
        .confirmationDialog(
            "Possible Duplicate",
            isPresented: $viewModel.isDuplicateWarningActive,
            titleVisibility: .visible
        ) {
            Button("Place Anyway") { viewModel.confirmPendingMarker() }
            Button("Cancel", role: .cancel) { viewModel.cancelPendingMarker() }
        } message: {
            Text("A marker of the same type is already nearby. Are you sure you want to place another?")
        }
    }
}

// MARK: - ImageCanvas

/// A zoomable and pannable canvas that renders the session image and all CountMarkers.
///
/// - Pinch-to-zoom: 0.5× – 10× (Requirement 3.9)
/// - Pan: free drag within zoom bounds (Requirement 3.8)
/// - Tap: places a marker at the tapped normalized coordinate (Requirement 3.1)
/// - Marker positions track correctly during zoom/pan (Requirement 3.8)
struct ImageCanvas: View {

    @ObservedObject var viewModel: CountingViewModel

    // MARK: - Zoom / pan state

    /// The committed scale factor (applied after a gesture ends).
    @State private var scale: CGFloat = 1.0
    /// The in-progress magnification delta from the current gesture.
    @State private var gestureScale: CGFloat = 1.0

    /// The committed offset (applied after a gesture ends).
    @State private var offset: CGSize = .zero
    /// The in-progress drag delta from the current gesture.
    @State private var gestureDrag: CGSize = .zero

    // MARK: - Zoom constants

    private let minScale: CGFloat = 0.5
    private let maxScale: CGFloat = 10.0

    // MARK: - Computed

    /// The effective scale combining committed and in-progress gesture values.
    private var effectiveScale: CGFloat {
        (scale * gestureScale).clamped(to: minScale...maxScale)
    }

    /// The effective offset combining committed and in-progress drag values.
    private var effectiveOffset: CGSize {
        CGSize(
            width: offset.width + gestureDrag.width,
            height: offset.height + gestureDrag.height
        )
    }

    // MARK: - Body

    var body: some View {
        GeometryReader { geometry in
            let canvasSize = geometry.size

            ZStack {
                // Background
                Color(.systemBackground)
                    .ignoresSafeArea()

                // Canvas content: image + markers
                canvasContent(canvasSize: canvasSize)
                    .scaleEffect(effectiveScale)
                    .offset(effectiveOffset)
                    // Tap to place marker
                    .gesture(tapGesture(canvasSize: canvasSize))
                    // Pinch to zoom
                    .gesture(magnificationGesture())
                    // Pan
                    .gesture(dragGesture())
            }
            .clipped()
        }
    }

    // MARK: - Canvas content

    @ViewBuilder
    private func canvasContent(canvasSize: CGSize) -> some View {
        ZStack {
            // Placeholder when no image is loaded yet
            imagePlaceholder(canvasSize: canvasSize)

            // AI bounding box overlay — rendered below markers
            // Requirement 5.4: render bounding boxes for filteredDetections
            ForEach(viewModel.filteredDetections) { detection in
                AIBoundingBoxView(
                    detection: detection,
                    canvasSize: canvasSize,
                    scale: effectiveScale,
                    viewModel: viewModel
                )
            }

            // Marker layer — composited into a single Metal-backed layer via drawingGroup()
            // to reduce per-marker draw calls and maintain 60 fps at high zoom/pan speeds.
            // Requirement 18.8: render counting canvas at 60 fps on images up to 4096×4096.
            ZStack {
                ForEach(viewModel.markers) { marker in
                    CountMarkerView(
                        marker: marker,
                        canvasSize: canvasSize,
                        scale: effectiveScale,
                        viewModel: viewModel
                    )
                }
            }
            .drawingGroup()

            // Advanced annotation layers — text labels, measure lines, arrows.
            // Rendered above markers so annotations are always visible.
            // Requirement 34.1–34.4: render all annotation types on the canvas.
            AnnotationLayerView(viewModel: annotationViewModel, canvasSize: canvasSize)
        }
        .frame(width: canvasSize.width, height: canvasSize.height)
    }

    @ViewBuilder
    private func imagePlaceholder(canvasSize: CGSize) -> some View {
        // When a real image is available (Task 2 / SessionImage), it would be
        // loaded here. For now we show a placeholder that fills the canvas.
        Rectangle()
            .fill(Color(.secondarySystemBackground))
            .frame(width: canvasSize.width, height: canvasSize.height)
            .overlay(
                VStack(spacing: 8) {
                    Image(systemName: "photo")
                        .font(.system(size: 48))
                        .foregroundStyle(.tertiary)
                        .accessibilityHidden(true)
                    Text("No image loaded")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            )
            .accessibilityLabel("Image canvas. No image loaded.")
    }

    // MARK: - Gestures

    /// Single-tap gesture: converts the tap location to normalized image coordinates
    /// and places a marker. Requires a selected ObjectType.
    private func tapGesture(canvasSize: CGSize) -> some Gesture {
        SpatialTapGesture()
            .onEnded { value in
                guard viewModel.selectedObjectType != nil else { return }
                let normalized = screenToNormalized(
                    point: value.location,
                    canvasSize: canvasSize
                )
                // Only place if within image bounds
                guard (0.0...1.0).contains(normalized.x),
                      (0.0...1.0).contains(normalized.y) else { return }
                viewModel.placeMarker(at: normalized)
            }
    }

    /// Pinch-to-zoom gesture. Clamps to [minScale, maxScale].
    /// Requirement 3.9: support pinch-to-zoom from 0.5× to 10×.
    private func magnificationGesture() -> some Gesture {
        MagnificationGesture()
            .onChanged { value in
                gestureScale = value
            }
            .onEnded { value in
                scale = (scale * value).clamped(to: minScale...maxScale)
                gestureScale = 1.0
            }
    }

    /// Pan gesture. Allows free dragging of the canvas.
    /// Requirement 3.8: maintain correct marker positions during zoom/pan.
    private func dragGesture() -> some Gesture {
        DragGesture()
            .onChanged { value in
                gestureDrag = value.translation
            }
            .onEnded { value in
                offset = CGSize(
                    width: offset.width + value.translation.width,
                    height: offset.height + value.translation.height
                )
                gestureDrag = .zero
            }
    }

    // MARK: - Coordinate conversion

    /// Converts a screen-space tap location to normalized image coordinates (0.0–1.0).
    ///
    /// The canvas is centered in the GeometryReader frame. The tap location is
    /// relative to the GeometryReader origin, so we must account for the current
    /// scale and offset to map back to the unscaled image space.
    ///
    /// Requirement 3.8: correct marker position tracking during zoom/pan.
    private func screenToNormalized(point: CGPoint, canvasSize: CGSize) -> CGPoint {
        // The canvas content is centered and then transformed by scaleEffect + offset.
        // scaleEffect scales around the center of the view.
        let centerX = canvasSize.width / 2
        let centerY = canvasSize.height / 2

        // Reverse the offset
        let unOffsetX = point.x - effectiveOffset.width
        let unOffsetY = point.y - effectiveOffset.height

        // Reverse the scale (scale is applied around center)
        let unscaledX = (unOffsetX - centerX) / effectiveScale + centerX
        let unscaledY = (unOffsetY - centerY) / effectiveScale + centerY

        // Normalize to [0, 1]
        return CGPoint(
            x: unscaledX / canvasSize.width,
            y: unscaledY / canvasSize.height
        )
    }
}

// MARK: - CountMarkerView

/// Renders a single CountMarker as a colored dot on the canvas.
///
/// - Filled dot for manually placed markers.
/// - Outlined dot for AI-derived markers (Requirement 7.5).
/// - Long-press shows a context menu with delete and reassign options (Requirement 3.3).
/// - Position tracks correctly during zoom/pan (Requirement 3.8).
struct CountMarkerView: View {

    let marker: CountMarker
    let canvasSize: CGSize
    let scale: CGFloat
    @ObservedObject var viewModel: CountingViewModel

    // MARK: - Marker appearance constants

    /// Base diameter of the marker dot in points (unscaled).
    /// Uses `@ScaledMetric` so the marker scales with the user's preferred text size
    /// (Dynamic Type / accessibility text size). Requirement 16.2.
    @ScaledMetric private var baseDiameter: CGFloat = 20

    /// Diameter scales inversely with zoom so markers stay a consistent visual size.
    private var markerDiameter: CGFloat {
        // Keep markers at a comfortable tap size regardless of zoom level.
        // Clamp between 12 and 32 pt.
        (baseDiameter / scale).clamped(to: 12...32)
    }

    // MARK: - Computed position

    /// The screen position of this marker within the canvas frame.
    /// Converts normalized coordinates to canvas-space points.
    private var position: CGPoint {
        CGPoint(
            x: CGFloat(marker.normalizedX) * canvasSize.width,
            y: CGFloat(marker.normalizedY) * canvasSize.height
        )
    }

    // MARK: - Color

    private var markerColor: Color {
        Color(hex: marker.objectType.colorHex) ?? .accentColor
    }

    // MARK: - Body

    var body: some View {
        markerShape
            .position(position)
            .accessibilityLabel(accessibilityLabel)
            .accessibilityHint("Long press to delete or reassign this marker.")
            .accessibilityAddTraits(.isButton)
            .contextMenu {
                // Delete action
                Button(role: .destructive) {
                    viewModel.removeMarker(marker)
                } label: {
                    Label("Delete Marker", systemImage: "trash")
                }
                .accessibilityLabel("Delete this marker")

                // Reassign submenu — one button per ObjectType
                let otherTypes = viewModel.session.objectTypes.filter {
                    $0.id != marker.objectType.id
                }
                if !otherTypes.isEmpty {
                    Menu("Reassign to…") {
                        ForEach(otherTypes.sorted { $0.sortOrder < $1.sortOrder }) { type in
                            Button {
                                viewModel.reassignMarker(marker, to: type)
                            } label: {
                                Label(type.name, systemImage: type.iconName)
                            }
                            .accessibilityLabel("Reassign to \(type.name)")
                        }
                    }
                }
            }
    }

    // MARK: - Shape

    @ViewBuilder
    private var markerShape: some View {
        if marker.isAIDerived {
            // Outlined dot for AI-derived markers (Requirement 7.5)
            Circle()
                .strokeBorder(markerColor, lineWidth: 2.5)
                .frame(width: markerDiameter, height: markerDiameter)
                .background(
                    Circle()
                        .fill(markerColor.opacity(0.25))
                        .frame(width: markerDiameter, height: markerDiameter)
                )
        } else {
            // Filled dot for manually placed markers (Requirement 3.2)
            Circle()
                .fill(markerColor)
                .frame(width: markerDiameter, height: markerDiameter)
                .overlay(
                    Circle()
                        .strokeBorder(Color.white.opacity(0.6), lineWidth: 1.5)
                        .frame(width: markerDiameter, height: markerDiameter)
                )
        }
    }

    // MARK: - Accessibility

    private var accessibilityLabel: String {
        let typeLabel = marker.objectType.name
        let source = marker.isAIDerived ? "AI-detected" : "manually placed"
        return "\(typeLabel) marker, \(source)"
    }
}

// MARK: - AIBoundingBoxView

/// Renders a single AI detection bounding box on the canvas with a label and confidence badge.
///
/// The box is drawn using the detection's `normalizedBoundingBox` converted to canvas-space
/// coordinates. A badge showing the label and confidence score is anchored to the top-left
/// corner of the box.
///
/// Requirement 5.4: render bounding boxes for filteredDetections with label and confidence badge.
struct AIBoundingBoxView: View {

    let detection: AIDetection
    let canvasSize: CGSize
    let scale: CGFloat
    @ObservedObject var viewModel: CountingViewModel

    // MARK: - Computed geometry

    /// The bounding box rect in canvas-space points.
    private var boxRect: CGRect {
        CGRect(
            x: detection.normalizedBoundingBox.minX * canvasSize.width,
            y: detection.normalizedBoundingBox.minY * canvasSize.height,
            width: detection.normalizedBoundingBox.width * canvasSize.width,
            height: detection.normalizedBoundingBox.height * canvasSize.height
        )
    }

    /// Stroke width scales inversely with zoom to stay visually consistent.
    private var strokeWidth: CGFloat {
        (2.0 / scale).clamped(to: 1.0...4.0)
    }

    // MARK: - Body

    var body: some View {
        ZStack(alignment: .topLeading) {
            // Bounding box rectangle
            Rectangle()
                .strokeBorder(boxColor, lineWidth: strokeWidth)
                .background(Rectangle().fill(boxColor.opacity(0.08)))
                .frame(width: boxRect.width, height: boxRect.height)
                .position(
                    x: boxRect.midX,
                    y: boxRect.midY
                )

            // Label + confidence badge anchored to top-left of the box
            confidenceBadge
                .position(
                    x: boxRect.minX + badgeWidth / 2,
                    y: boxRect.minY - badgeHeight / 2
                )
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            "\(detection.label) detected, \(Int(detection.confidenceScore * 100)) percent confidence"
        )
        .accessibilityHint("Long press to accept or dismiss this detection.")
        .contextMenu {
            Button {
                viewModel.acceptDetection(detection)
            } label: {
                Label("Accept Detection", systemImage: "checkmark.circle")
            }
            .accessibilityLabel("Accept this AI detection")

            Button(role: .destructive) {
                viewModel.deleteDetection(detection)
            } label: {
                Label("Dismiss Detection", systemImage: "xmark.circle")
            }
            .accessibilityLabel("Dismiss this AI detection")
        }
    }

    // MARK: - Badge

    /// Approximate badge dimensions for positioning (actual size is dynamic).
    private let badgeHeight: CGFloat = 20
    private var badgeWidth: CGFloat {
        // Rough estimate: label text + confidence text + padding
        CGFloat(detection.label.count) * 7 + 60
    }

    @ViewBuilder
    private var confidenceBadge: some View {
        HStack(spacing: 4) {
            Text(detection.label)
                .font(.system(size: 10, weight: .semibold))
                .lineLimit(1)
            Text("\(Int(detection.confidenceScore * 100))%")
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .monospacedDigit()
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(
            Capsule()
                .fill(boxColor)
        )
    }

    // MARK: - Color

    /// Accepted detections use green; pending detections use orange.
    private var boxColor: Color {
        detection.isAccepted ? .green : .orange
    }
}

// MARK: - AIControlPanel

/// A bottom panel providing AI detection controls:
/// - Confidence threshold slider (0.1–0.9)
/// - "Accept All" button
/// - Detection count summary
///
/// Requirements: 5.4, 5.5, 5.7
struct AIControlPanel: View {

    @ObservedObject var viewModel: CountingViewModel

    var body: some View {
        VStack(spacing: 0) {
            // Progress bar — visible during AI inference
            // Requirement 5.7: show progress bar during AI inference
            if viewModel.isAIRunning {
                AIProgressBar(progress: viewModel.aiProgress)
                    .padding(.horizontal, 16)
                    .padding(.top, 10)
            }

            HStack(spacing: 12) {
                // Confidence threshold label + value
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Image(systemName: "slider.horizontal.3")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .accessibilityHidden(true)
                        Text("Confidence")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Text("\(Int(viewModel.confidenceThreshold * 100))%")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.primary)
                }
                .frame(minWidth: 72, alignment: .leading)

                // Confidence threshold slider (0.1–0.9)
                // Requirement 5.5: filter detections by confidence threshold
                Slider(
                    value: Binding(
                        get: { Double(viewModel.confidenceThreshold) },
                        set: { viewModel.confidenceThreshold = Float($0) }
                    ),
                    in: 0.1...0.9,
                    step: 0.05
                )
                .accessibilityLabel("Confidence threshold")
                .accessibilityValue("\(Int(viewModel.confidenceThreshold * 100)) percent")
                .accessibilityHint(
                    "Adjust the minimum confidence score for displaying AI detections. Range: 10 to 90 percent."
                )

                // Detection count badge
                detectionCountBadge
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)

            Divider()

            // Accept All button
            // Requirement 5.4: Accept All converts all filtered detections to markers
            Button {
                viewModel.acceptAllDetections()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 15, weight: .semibold))
                        .accessibilityHidden(true)
                    Text("Accept All")
                        .font(.system(size: 15, weight: .semibold))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(acceptAllButtonColor)
                )
                .foregroundStyle(.white)
            }
            .buttonStyle(.plain)
            .disabled(viewModel.filteredDetections.filter { !$0.isAccepted }.isEmpty)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .accessibilityLabel("Accept all detections")
            .accessibilityHint(
                "Converts all \(viewModel.filteredDetections.filter { !$0.isAccepted }.count) pending AI detections into count markers."
            )

            // Find Missed Objects button — Requirement 35.2, 35.3
            Button {
                // Caller must supply an image; for now we trigger via ViewModel
                // The actual image is passed from CountingView when available.
                // This button is wired in CountingView via the viewModel action.
                NotificationCenter.default.post(name: .findMissedObjectsRequested, object: nil)
            } label: {
                HStack(spacing: 6) {
                    if viewModel.isFindingMissedObjects {
                        ProgressView()
                            .scaleEffect(0.8)
                            .accessibilityLabel("Searching for missed objects…")
                    } else {
                        Image(systemName: "magnifyingglass.circle")
                            .font(.system(size: 15, weight: .semibold))
                            .accessibilityHidden(true)
                    }
                    Text(viewModel.isFindingMissedObjects ? "Searching…" : "Find Missed Objects")
                        .font(.system(size: 15, weight: .semibold))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.orange.opacity(0.85))
                )
                .foregroundStyle(.white)
            }
            .buttonStyle(.plain)
            .disabled(viewModel.isFindingMissedObjects)
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
            .accessibilityLabel("Find missed objects")
            .accessibilityHint("Runs a secondary AI pass at low confidence to find objects not yet counted.")

            // Missed object candidates — amber bounding boxes with Accept/Dismiss
            // Requirement 35.3
            if !viewModel.missedObjectCandidates.isEmpty {
                Divider()
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(viewModel.missedObjectCandidates) { candidate in
                            MissedCandidateChip(
                                candidate: candidate,
                                onAccept: { viewModel.acceptMissedCandidate(candidate) },
                                onDismiss: { viewModel.dismissMissedCandidate(candidate) }
                            )
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                }
                .accessibilityLabel("\(viewModel.missedObjectCandidates.count) missed object candidates")
            }
        }
        .background(.regularMaterial)
        .animation(.easeInOut(duration: 0.2), value: viewModel.isAIRunning)
    }

    // MARK: - Helpers

    private var pendingCount: Int {
        viewModel.filteredDetections.filter { !$0.isAccepted }.count
    }

    private var acceptAllButtonColor: Color {
        pendingCount == 0 ? Color(.systemGray3) : .green
    }

    @ViewBuilder
    private var detectionCountBadge: some View {
        VStack(alignment: .trailing, spacing: 2) {
            Text("\(viewModel.filteredDetections.count)")
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.primary)
            Text("detected")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(minWidth: 44, alignment: .trailing)
        .accessibilityLabel("\(viewModel.filteredDetections.count) detections")
    }
}

// MARK: - AIProgressBar

/// A thin, animated progress bar shown during AI inference.
///
/// Requirement 5.7: show progress bar during AI inference using `aiProgress`.
struct AIProgressBar: View {

    let progress: Double

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Track
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(Color(.systemGray5))
                    .frame(height: 6)

                // Fill
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [.blue, .cyan],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(
                        width: geometry.size.width * CGFloat(progress.clamped(to: 0.0...1.0)),
                        height: 6
                    )
                    .animation(.easeInOut(duration: 0.15), value: progress)
            }
        }
        .frame(height: 6)
        .accessibilityLabel("AI inference progress")
        .accessibilityValue("\(Int(progress * 100)) percent complete")
    }
}

// MARK: - ObjectTypeToolbar

/// Horizontal scrollable toolbar at the bottom of CountingView.
///
/// Displays one chip per ObjectType with its icon, name, and current tally badge.
/// Tapping a chip selects that ObjectType as the active counting type.
///
/// When the grid overlay is active, also shows:
/// - A density stepper (2×2 – 20×20)
/// - A completed-cell counter (e.g. "3 / 25 cells")
///
/// Requirements: 4.2, 4.6, 6.2, 6.3, 6.4
struct ObjectTypeToolbar: View {

    @ObservedObject var viewModel: CountingViewModel

    var body: some View {
        VStack(spacing: 0) {
            // Grid controls row — only visible when grid overlay is enabled
            if viewModel.isGridOverlayEnabled {
                gridControlsRow
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            // Object-type chips row
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(
                        viewModel.session.objectTypes.sorted { $0.sortOrder < $1.sortOrder }
                    ) { objectType in
                        ObjectTypeChip(
                            objectType: objectType,
                            tally: viewModel.globalTally[objectType] ?? 0,
                            isSelected: viewModel.selectedObjectType?.id == objectType.id
                        ) {
                            viewModel.selectedObjectType = objectType
                        }
                    }

                    // Placeholder when no object types exist
                    if viewModel.session.objectTypes.isEmpty {
                        Text("No object types defined")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 16)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
            }
        }
        .background(.regularMaterial)
        .animation(.easeInOut(duration: 0.2), value: viewModel.isGridOverlayEnabled)
        .accessibilityLabel("Object type toolbar")
        .accessibilityHint("Select an object type to count. Swipe horizontally to see all types.")
    }

    // MARK: - Grid controls row

    /// Shows the density stepper and completed-cell count when the grid is active.
    ///
    /// Requirements: 4.2 (density stepper), 4.6 (completed-cell count).
    private var gridControlsRow: some View {
        HStack(spacing: 16) {
            // Density stepper label
            Label("Grid", systemImage: "grid")
                .font(.caption)
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)

            // Density stepper: 2×2 to 20×20
            Stepper(
                value: $viewModel.gridDensity,
                in: 2...20,
                step: 1
            ) {
                Text("\(viewModel.gridDensity)×\(viewModel.gridDensity)")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .frame(minWidth: 44)
            }
            .accessibilityLabel("Grid density")
            .accessibilityValue("\(viewModel.gridDensity) by \(viewModel.gridDensity)")
            .accessibilityHint(
                "Adjust the number of grid rows and columns. Range: 2 to 20."
            )

            Spacer()

            // Completed-cell count badge
            // Requirement 4.6: display count of completed cells and total cells.
            HStack(spacing: 4) {
                Image(systemName: "checkmark.square.fill")
                    .font(.caption)
                    .foregroundStyle(.green)
                    .accessibilityHidden(true)
                Text("\(viewModel.completedCellCount) / \(viewModel.totalCells) cells")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.primary)
            }
            .accessibilityLabel(
                "\(viewModel.completedCellCount) of \(viewModel.totalCells) cells completed"
            )
            .accessibilityHint("Number of grid cells you have marked as counted.")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color(.tertiarySystemBackground))
    }
}

// MARK: - ObjectTypeChip

/// A single selectable chip in the ObjectTypeToolbar.
///
/// Shows the ObjectType icon, name, and a tally badge.
/// When a count target is set, wraps the chip in a `CountTargetProgressView` ring.
/// Highlighted when selected (Requirement 6.3).
/// Requirement 53 (Req 42): progress ring around tally badge when target is set.
struct ObjectTypeChip: View {

    let objectType: ObjectType
    let tally: Int
    let isSelected: Bool
    let onTap: () -> Void

    private var chipColor: Color {
        Color(hex: objectType.colorHex) ?? .accentColor
    }

    var body: some View {
        ZStack {
            Button(action: onTap) {
                HStack(spacing: 6) {
                    // Icon
                    Image(systemName: objectType.iconName)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(isSelected ? .white : chipColor)
                        .accessibilityHidden(true)

                    // Name
                    Text(objectType.name)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(isSelected ? .white : .primary)
                        .lineLimit(1)

                    // Tally badge with optional progress ring
                    ZStack {
                        TallyBadge(count: tally, isSelected: isSelected, color: chipColor)

                        // Progress ring — only shown when a target is set
                        // Requirement 53 (Req 42): ring fills as count approaches target
                        if let target = objectType.targetCount, target > 0 {
                            CountTargetProgressView(
                                count: tally,
                                target: target,
                                color: chipColor
                            )
                            .frame(width: 28, height: 28)
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(isSelected ? chipColor : Color(.secondarySystemBackground))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .strokeBorder(
                            isSelected ? Color.clear : chipColor.opacity(0.4),
                            lineWidth: 1.5
                        )
                )
            }
            .buttonStyle(.plain)
        }
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint(isSelected
            ? "Currently selected. Tap to keep selected."
            : "Tap to select \(objectType.name) as the active counting type.")
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }

    private var accessibilityLabel: String {
        var label = "\(objectType.name), \(tally) counted"
        if let target = objectType.targetCount {
            label += ", target \(target)"
            if tally >= target {
                label += ", target reached"
            }
        }
        return label
    }
}

// MARK: - TallyBadge

/// A small pill badge showing the current tally count for an ObjectType.
struct TallyBadge: View {

    let count: Int
    let isSelected: Bool
    let color: Color

    var body: some View {
        Text("\(count)")
            .font(.system(size: 12, weight: .bold, design: .rounded))
            .foregroundStyle(isSelected ? color : .white)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(
                Capsule()
                    .fill(isSelected ? Color.white : color)
            )
            .accessibilityLabel("\(count) counted")
    }
}

// MARK: - Shake gesture notification

// Note: deviceDidShake and clamped are defined in Models/Extensions.swift

// MARK: - UIWindow shake detection

/// Extends UIWindow to detect shake gestures and post a notification.
extension UIWindow {
    open override func motionEnded(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
        super.motionEnded(motion, with: event)
        if motion == .motionShake {
            NotificationCenter.default.post(name: .deviceDidShake, object: nil)
        }
    }
}

// MARK: - Preview

#Preview {
    let session: CountSession = {
        let s = CountSession(name: "Bird Survey")
        let t1 = ObjectType(name: "Robin", colorHex: "#E74C3C", iconName: "bird", sortOrder: 0, session: s)
        let t2 = ObjectType(name: "Sparrow", colorHex: "#3498DB", iconName: "bird.fill", sortOrder: 1, session: s)
        s.objectTypes = [t1, t2]
        s.markers = [
            CountMarker(normalizedX: 0.3, normalizedY: 0.4, objectType: t1, session: s),
            CountMarker(normalizedX: 0.6, normalizedY: 0.6, objectType: t2, session: s),
            CountMarker(normalizedX: 0.5, normalizedY: 0.3, objectType: t1, isAIDerived: true, session: s),
        ]
        return s
    }()

    // Wrap in a helper view so we can inject AI detections into the ViewModel for preview
    struct PreviewWrapper: View {
        let session: CountSession
        @StateObject private var vm: CountingViewModel

        init(session: CountSession) {
            self.session = session
            _vm = StateObject(wrappedValue: CountingViewModel(session: session))
        }

        var body: some View {
            NavigationStack {
                CountingView(session: session)
            }
            .onAppear {
                vm.detections = [
                    AIDetection(
                        normalizedBoundingBox: CGRect(x: 0.1, y: 0.1, width: 0.2, height: 0.15),
                        label: "Robin",
                        confidenceScore: 0.87
                    ),
                    AIDetection(
                        normalizedBoundingBox: CGRect(x: 0.55, y: 0.5, width: 0.18, height: 0.2),
                        label: "Sparrow",
                        confidenceScore: 0.62
                    ),
                ]
            }
        }
    }

    return PreviewWrapper(session: session)
        .modelContainer(
            for: [CountSession.self, ObjectType.self, CountMarker.self,
                  CountRegion.self, SessionImage.self, VideoFrameCount.self],
            inMemory: true
        )
}

// MARK: - FatigueWarningBanner

/// A dismissible banner shown when counting velocity exceeds the fatigue threshold.
///
/// Requirement 35.4: display a fatigue warning if the user places more than 60 markers
/// per minute for more than 2 consecutive minutes.
struct FatigueWarningBanner: View {

    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text("You're counting fast")
                    .font(.caption.bold())
                Text("Take a moment to verify your counts.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                onDismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Dismiss fatigue warning")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.regularMaterial)
        .overlay(alignment: .bottom) {
            Divider()
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Fatigue warning: you are counting very fast. Take a moment to verify your counts.")
    }
}

// MARK: - MissedCandidateChip

/// A compact chip representing a single "Find Missed Objects" candidate detection.
/// Shown in a horizontal scroll view in the AI panel.
///
/// Requirement 35.3: render candidate detections with individual Accept/Dismiss controls.
struct MissedCandidateChip: View {

    let candidate: AIDetection
    let onAccept: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 6) {
            // Amber indicator dot
            Circle()
                .fill(Color.orange)
                .frame(width: 8, height: 8)
                .accessibilityHidden(true)

            Text(candidate.label)
                .font(.caption.bold())
                .lineLimit(1)

            Text(String(format: "%.0f%%", candidate.confidenceScore * 100))
                .font(.caption2)
                .foregroundStyle(.secondary)
                .monospacedDigit()

            // Accept
            Button {
                onAccept()
            } label: {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .font(.system(size: 16))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Accept \(candidate.label) as a missed object")

            // Dismiss
            Button {
                onDismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.secondary)
                    .font(.system(size: 16))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Dismiss \(candidate.label) candidate")
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.orange.opacity(0.12))
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(Color.orange.opacity(0.4), lineWidth: 1)
                )
        )
    }
}

// MARK: - ReviewModeSheet

/// Steps through all CountMarkers one by one, centering each on the canvas.
/// Allows the user to verify each counted object and delete incorrect markers.
///
/// Requirement 35.5: provide a "Review Mode" that steps through all Count_Markers.
struct ReviewModeSheet: View {

    @ObservedObject var viewModel: CountingViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var currentIndex: Int = 0

    private var markers: [CountMarker] {
        viewModel.markers.sorted { $0.createdAt < $1.createdAt }
    }

    private var currentMarker: CountMarker? {
        guard !markers.isEmpty, currentIndex < markers.count else { return nil }
        return markers[currentIndex]
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if markers.isEmpty {
                    emptyState
                } else {
                    markerDetail
                    Divider()
                    navigationControls
                }
            }
            .navigationTitle("Review Mode")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .accessibilityLabel("Exit review mode")
                }
            }
        }
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            Text("No markers to review")
                .font(.title3)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Marker detail

    private var markerDetail: some View {
        VStack(spacing: 20) {
            // Progress indicator
            Text("Marker \(currentIndex + 1) of \(markers.count)")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .monospacedDigit()
                .accessibilityLabel("Reviewing marker \(currentIndex + 1) of \(markers.count)")

            if let marker = currentMarker {
                // Marker info card
                VStack(spacing: 12) {
                    HStack(spacing: 12) {
                        // Color swatch
                        Circle()
                            .fill(Color(hex: marker.objectType.colorHex) ?? .accentColor)
                            .frame(width: 20, height: 20)
                            .accessibilityHidden(true)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(marker.objectType.name)
                                .font(.headline)
                            Text(marker.isAIDerived ? "AI-detected" : "Manually placed")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        // Source badge
                        Text(marker.isAIDerived ? "AI" : "Manual")
                            .font(.caption.bold())
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                Capsule()
                                    .fill(marker.isAIDerived
                                          ? Color.blue.opacity(0.15)
                                          : Color.green.opacity(0.15))
                            )
                            .foregroundStyle(marker.isAIDerived ? .blue : .green)
                    }

                    // Coordinates
                    HStack {
                        Label(
                            String(format: "X: %.3f  Y: %.3f",
                                   marker.normalizedX, marker.normalizedY),
                            systemImage: "mappin.and.ellipse"
                        )
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        Spacer()
                        Text(marker.createdAt.formatted(date: .omitted, time: .shortened))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color(.secondarySystemBackground))
                )
                .padding(.horizontal, 20)

                // Delete button
                Button(role: .destructive) {
                    viewModel.removeMarker(marker)
                    // Stay at same index (next marker slides in), or go back if at end
                    if currentIndex >= viewModel.markers.count {
                        currentIndex = max(0, viewModel.markers.count - 1)
                    }
                } label: {
                    Label("Delete This Marker", systemImage: "trash")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(Color.red.opacity(0.1))
                        )
                        .foregroundStyle(.red)
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 20)
                .accessibilityLabel("Delete this marker")
                .accessibilityHint("Removes the current marker from the session.")
            }
        }
        .padding(.vertical, 20)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Navigation controls

    private var navigationControls: some View {
        HStack(spacing: 20) {
            // Previous
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    currentIndex = max(0, currentIndex - 1)
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "chevron.left")
                    Text("Previous")
                }
                .font(.system(size: 15, weight: .semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color(.secondarySystemBackground))
                )
            }
            .buttonStyle(.plain)
            .disabled(currentIndex == 0)
            .accessibilityLabel("Previous marker")

            // Next
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    currentIndex = min(markers.count - 1, currentIndex + 1)
                }
            } label: {
                HStack(spacing: 6) {
                    Text("Next")
                    Image(systemName: "chevron.right")
                }
                .font(.system(size: 15, weight: .semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color(.secondarySystemBackground))
                )
            }
            .buttonStyle(.plain)
            .disabled(currentIndex >= markers.count - 1)
            .accessibilityLabel("Next marker")
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }
}

// MARK: - Color hex extension (local)

private extension Color {
    init?(hex: String) {
        var str = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if str.hasPrefix("#") { str.removeFirst() }
        guard str.count == 6, let value = UInt64(str, radix: 16) else { return nil }
        let r = Double((value >> 16) & 0xFF) / 255
        let g = Double((value >> 8) & 0xFF) / 255
        let b = Double(value & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }
}
