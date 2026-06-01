# Implementation Plan: OpenCount iOS

## Overview

Implement OpenCount as a native SwiftUI iOS app using MVVM, SwiftData for persistence, CoreML/Vision for on-device AI counting, and AVFoundation for live camera. Tasks are ordered so each step produces runnable, testable code that builds on the previous step. All code is written in Swift targeting iOS 16.0+.

---

## Tasks

- [x] 1. Project setup and core data models
  - Create a new Xcode project named `OpenCount` with SwiftUI app lifecycle, targeting iOS 16.0+
  - Add SwiftCheck via Swift Package Manager for property-based testing
  - Define all SwiftData `@Model` types: `CountSession`, `ObjectType`, `CountMarker`, `CountRegion`, `SessionImage`, `VideoFrameCount`
  - Define the in-memory `AIDetection` struct and `RegionShapeType` enum
  - Define the `AppError` enum conforming to `LocalizedError` with all error cases from the design
  - Configure `ModelContainer` in the `@main` App struct with the full schema
  - _Requirements: 1.3, 14.1, 18.6_

  - [x] 1.1 Write property test for session persistence round-trip
    - Generate random `CountSession` values with arbitrary markers and regions
    - Save to an in-memory `ModelContainer`, fetch back, assert structural equivalence
    - **Property 8: Session persistence round-trip preserves state**
    - **Validates: Requirements 18.5, 1.3**

- [x] 2. StorageService and SessionListViewModel
  - Implement `StorageService` conforming to `StorageServiceProtocol` using SwiftData `ModelContext`
  - Implement `SessionListViewModel` with `createSession`, `deleteSession`, `duplicateSession`, and debounced `search` (300 ms debounce using `Combine`)
  - Wire `filteredSessions` to update whenever `searchQuery` changes
  - _Requirements: 1.1, 1.2, 1.4, 1.5, 1.6, 1.7, 1.8_

  - [x] 2.1 Write property test for session search filtering
    - Generate a random list of `CountSession` values with random names
    - For any non-empty query, assert that `filteredSessions` contains exactly the sessions whose names contain the query (case-insensitive)
    - **Property 10: Session search returns only matching sessions**
    - **Validates: Requirements 1.6**

- [x] 3. SessionListView and NewSessionSheet
  - Build `SessionListView` with a `List` of sessions sorted by `modifiedAt` descending
  - Add a `SearchBar` bound to `SessionListViewModel.searchQuery`
  - Build `NewSessionSheet` with name (required) and description (optional) text fields and a source picker (Photos, Camera, Files)
  - Add swipe-to-delete with confirmation alert on each session row
  - Add duplicate action in the context menu
  - _Requirements: 1.1, 1.4, 1.5, 1.6, 1.8, 16.6_

- [x] 4. Checkpoint — Core session management working
  - Ensure all tests pass, ask the user if questions arise.

- [x] 5. ObjectType management
  - Implement `ObjectTypeEditorView` for creating and editing an `ObjectType` (name, color picker, icon picker)
  - Build an icon library grid with at least 50 SF Symbol icons organized by theme category
  - Implement drag-to-reorder for `ObjectType` items in the session toolbar
  - Implement the 10 built-in `ObjectType` templates (e.g., "People Count", "Inventory Check", "Wildlife Survey") as seed data
  - Implement `ObjectType` deletion with cascade: remove all associated `CountMarker` records and recompute tallies
  - _Requirements: 14.1, 14.2, 14.3, 14.4, 14.5, 14.6_

  - [x] 5.1 Write property test for Object_Type deletion cascade
    - Generate a random `CountSession` with random markers assigned to random Object_Types
    - Delete one Object_Type, assert zero markers remain for that type and tally is 0
    - **Property 7: Object_Type deletion removes all associated markers**
    - **Validates: Requirements 14.5**

- [x] 6. UndoStack implementation
  - Implement the generic `UndoStack<T>` value type with `push`, `undo`, `redo`, `canUndo`, `canRedo`, and a configurable `capacity` (default 50)
  - Integrate `UndoStack` into `CountingViewModel` to snapshot session state on every marker placement or removal
  - Wire undo/redo to the standard iOS shake-to-undo gesture and toolbar buttons
  - _Requirements: 3.5, 3.6_

  - [x] 6.1 Write property test for undo/redo round-trip
    - Generate a random sequence of marker placements and deletions
    - Apply all operations, then undo each in reverse order, assert the session returns to its original state
    - **Property 2: Undo/redo round-trip restores original state**
    - **Validates: Requirements 3.5, 3.6**

- [x] 7. CountingViewModel — manual counting core
  - Implement `CountingViewModel` with `placeMarker(at:in:)`, `removeMarker(_:)`, `undo()`, `redo()`
  - Implement `globalTally` computed property: count of markers per Object_Type
  - Implement real-time tally display: `@Published var globalTally: [ObjectType: Int]` updated on every mutation
  - Implement haptic feedback (`UIImpactFeedbackGenerator`) on marker placement
  - _Requirements: 3.1, 3.2, 3.3, 3.7, 3.10, 6.1, 6.5_

  - [x] 7.1 Write property test for marker placement tally invariant
    - For any session state and any valid tap location, placing a marker increments the tally for the selected Object_Type by exactly 1 and leaves all other tallies unchanged
    - **Property 1: Marker placement increments tally by exactly one**
    - **Validates: Requirements 3.1, 6.1**

  - [x] 7.2 Write property test for combined tally equals marker count
    - For any session with a mix of manual and AI-derived markers, assert globalTally[type] == markers.filter { $0.objectType == type }.count
    - **Property 9: Combined tally equals manual plus AI-derived marker count**
    - **Validates: Requirements 7.4, 3.7**

- [x] 8. CountingView — image canvas
  - Build `CountingView` with a zoomable/pannable `ImageCanvas` using `MagnificationGesture` and `DragGesture`
  - Support pinch-to-zoom from 0.5× to 10× with correct marker position tracking during zoom/pan
  - Render `CountMarker` dots on the canvas, colored by Object_Type, with correct normalized-to-screen coordinate conversion
  - Implement long-press on a marker to show a delete/reassign context menu
  - Build the horizontal `ObjectTypeToolbar` at the bottom with tally badges
  - _Requirements: 3.2, 3.3, 3.8, 3.9, 6.2, 6.3, 6.4, 10.4_

- [x] 9. Grid overlay
  - Implement `GridOverlayView` as a SwiftUI overlay on `ImageCanvas`
  - Support configurable density from 2×2 to 20×20 via a stepper in the toolbar
  - Render cell indices and highlight tapped cells with a semi-transparent fill
  - Add a toggle button in the counting toolbar to show/hide the grid
  - Display completed-cell count in the toolbar when grid is active
  - _Requirements: 4.1, 4.2, 4.3, 4.4, 4.5, 4.6_

- [x] 10. Checkpoint — Manual counting fully functional
  - Ensure all tests pass, ask the user if questions arise.

- [x] 11. AIService and CoreML integration
  - Add `YOLOv8n.mlpackage` to the Xcode project (download from Ultralytics and convert with `coremltools`)
  - Implement `CoreMLAIService` using `VNCoreMLRequest` on a background `ModelActor`
  - Implement `detect(in:confidenceThreshold:)` returning `[AIDetection]` with normalized bounding boxes
  - Implement `detectSimilar(to:in:)` for zero-shot counting using visual similarity (crop + feature matching via `VNFeaturePrintObservation`)
  - Expose `@Published var aiProgress: Double` updated via `VNRequest` progress handler
  - _Requirements: 5.1, 5.2, 5.3, 5.8, 5.9, 5.10, 5.11_

- [x] 12. AI counting integration in CountingViewModel
  - Implement `runAIDetection(on:)` in `CountingViewModel` calling `AIService.detect`
  - Implement `filteredDetections` computed property: filter `detections` by `confidenceThreshold`
  - Implement `acceptDetection(_:)`, `acceptAllDetections()`, `deleteDetection(_:)` mutating `detections` and updating `markers`
  - Implement `reassignMarker(_:to:)` for changing a marker's Object_Type
  - _Requirements: 5.4, 5.5, 5.6, 5.7, 7.1, 7.2, 7.3, 7.6, 7.7_

  - [x] 12.1 Write property test for confidence threshold filtering monotonicity
    - For any set of AI_Detections and any T1 < T2, assert that detections shown at T2 are a subset of detections shown at T1
    - **Property 3: Confidence threshold filtering is monotone**
    - **Validates: Requirements 5.5, 5.6**

- [x] 13. AI detection overlay in CountingView
  - Render bounding boxes for `filteredDetections` on `ImageCanvas` with label and confidence badge
  - Add a confidence threshold slider in the AI panel (0.1–0.9)
  - Add "Accept All" button that calls `acceptAllDetections()`
  - Visually distinguish AI-derived markers (outlined dot) from manual markers (filled dot)
  - Show progress bar during AI inference using `aiProgress`
  - _Requirements: 5.4, 5.5, 5.7, 7.5_

- [x] 14. Region of Interest (ROI) drawing and counting
  - Implement `RegionDrawingView` supporting rectangle drag, ellipse drag, and freehand polygon tap
  - Implement `CountRegion` geometry helpers: `contains(normalizedPoint:)` for each shape type
  - Implement `CountingViewModel.tally(for:)` computing per-region tallies by testing each marker's coordinates against the region boundary
  - Implement `CountingViewModel.updateRegion(_:)` that recomputes region tallies within 200 ms
  - Render region overlays on `ImageCanvas` with name labels and colored borders
  - Display per-region tally panel alongside global tally
  - _Requirements: 8.1, 8.2, 8.3, 8.4, 8.5, 8.6, 8.7, 8.8_

  - [x] 14.1 Write property test for region tally containment
    - For any region geometry and any set of markers, assert region tally equals count of markers whose normalized coordinates fall within the region boundary
    - **Property 4: Region tally equals contained marker count**
    - **Validates: Requirements 8.5, 8.7**

- [x] 15. Checkpoint — AI counting and ROI working
  - Ensure all tests pass, ask the user if questions arise.

- [x] 16. Live camera counting
  - Implement `LiveCountViewModel` managing `AVCaptureSession` with `AVCaptureVideoDataOutput`
  - Run `CoreMLAIService.detect` on each captured frame on a background queue, throttled to 15 fps
  - Implement `freeze()` to capture the current frame as `UIImage` and set `isFrozen = true`
  - Implement `switchCamera()` toggling between front and rear `AVCaptureDevice`
  - Build `LiveCountView` with camera preview (`AVCaptureVideoPreviewLayer` via `UIViewRepresentable`), bounding box overlay, tally HUD, confidence slider, freeze button, and camera-switch button
  - Handle the case where the device lacks required camera capabilities
  - _Requirements: 9.1, 9.2, 9.3, 9.4, 9.5, 9.6, 9.7, 9.8_

- [x] 17. Batch counting
  - Implement `BatchJobViewModel` with a queue of `SessionImage` items and sequential AI processing
  - Display overall progress ("3 of 10 images processed") and per-image status
  - Implement cancel: stop processing, preserve already-completed results
  - Build `BatchJobView` with image grid, progress bar, and per-image result preview
  - Implement aggregated tally summary across all batch images
  - _Requirements: 10.1, 10.2, 10.3, 10.4, 10.5, 10.6_

- [x] 18. Video frame counting
  - Implement `VideoPlayerViewModel` using `AVPlayer` and `AVAssetImageGenerator` for frame extraction
  - Implement frame-by-frame navigation with swipe gestures and prev/next buttons
  - Store counting results per frame as `VideoFrameCount` with timestamp
  - Implement auto-sampling: run AI detection at a user-configured interval (1s, 5s, etc.)
  - Build `VideoTimelineView` showing a scrubber with markers at counted frames
  - Build a line chart (using Swift Charts) showing count over time per Object_Type
  - _Requirements: 11.1, 11.2, 11.3, 11.4, 11.5, 11.6_

- [x] 19. Checkpoint — Live camera, batch, and video working
  - Ensure all tests pass, ask the user if questions arise.

- [x] 20. ExportService — CSV and JSON
  - Implement `ExportService.exportCSV(session:)` producing RFC 4180-compliant CSV with columns: object_type, tally, marker_x, marker_y, region_name, timestamp
  - Implement `ExportService.exportJSON(session:)` using `JSONEncoder` with a well-defined `Codable` DTO layer
  - Implement `ExportService.plainTextSummary(session:)` for clipboard copy
  - Ensure both exports complete within 2 seconds for 10,000 markers (benchmark in unit test)
  - _Requirements: 12.1, 12.2, 12.6, 12.7_

  - [x] 20.1 Write property test for CSV export round-trip
    - For any valid `CountSession`, serialize to CSV and parse back, assert same Object_Type names, tallies, and marker coordinates
    - **Property 5: CSV export round-trip preserves session data**
    - **Validates: Requirements 12.1**

  - [x] 20.2 Write property test for JSON export round-trip
    - For any valid `CountSession`, encode to JSON and decode back, assert structural equivalence
    - **Property 6: JSON export round-trip preserves session data**
    - **Validates: Requirements 12.2**

- [x] 21. ExportService — Annotated image and PDF
  - Implement `ExportService.exportAnnotatedImage(session:image:)` using `UIGraphicsImageRenderer` to draw markers, bounding boxes, and region outlines on the source image
  - Implement `ExportService.exportPDF(session:image:)` using `UIGraphicsPDFRenderer` with annotated image, tally table, and session metadata
  - _Requirements: 12.3, 12.4_

- [x] 22. Export UI and Share Sheet
  - Build `ExportSheet` with format picker (CSV, JSON, Annotated Image, PDF) and export button
  - Wire each format to the corresponding `ExportService` method
  - Present `UIActivityViewController` (Share Sheet) with the exported file URL
  - Add "Copy to Clipboard" button for plain-text summary
  - Show completion notification for PDF export with "Open" action
  - _Requirements: 12.5, 12.7, 12.8_

- [x] 23. Statistics and history view
  - Build `StatisticsView` with:
    - Total tally summary panel
    - Pie chart (Swift Charts) for Object_Type distribution
    - Bar chart (Swift Charts) for per-Region tally comparison
    - Cross-session comparison picker and chart
    - Object density calculation (count / image area in normalized units)
  - Implement tally change history log stored as timestamped entries in `CountSession`
  - _Requirements: 13.1, 13.2, 13.3, 13.4, 13.5, 13.6_

- [x] 24. iCloud sync with CloudKit
  - Configure `ModelContainer` with `CloudKitDatabase` when iCloud is available and user has opted in
  - Implement `iCloudSyncViewModel` monitoring `NSPersistentCloudKitContainer` sync events
  - Add sync status indicator (spinner/checkmark) in the navigation bar
  - Implement graceful fallback to local-only mode when iCloud is unavailable
  - Implement `.opencount` backup file export/import using `Codable` serialization of the full data graph
  - _Requirements: 15.1, 15.2, 15.3, 15.4, 15.5, 15.6_

- [x] 25. Settings screen
  - Build `SettingsView` with:
    - Default marker size slider (16–48 pt)
    - Default marker color picker
    - Default AI confidence threshold slider (0.1–0.9)
    - Default export format picker
    - "Confirm before delete marker" toggle
    - iCloud sync toggle
    - "Reset to defaults" button with confirmation alert
  - Persist all settings to `UserDefaults` and restore on launch
  - _Requirements: 17.1, 17.2, 17.3, 17.4, 17.5_

- [x] 26. Accessibility and polish
  - Add `accessibilityLabel` and `accessibilityHint` to all interactive elements (buttons, markers, region handles, toolbar items)
  - Verify Dynamic Type scaling for all text elements using `@ScaledMetric`
  - Implement Light/Dark Mode support by using semantic SwiftUI colors throughout
  - Add Portrait/Landscape layout adaptations for both iPhone and iPad
  - Add onboarding flow (max 5 steps) shown on first launch using `AppStorage("hasSeenOnboarding")`
  - _Requirements: 16.1, 16.2, 16.3, 16.4, 10.2, 10.3, 10.5_

- [x] 27. Performance hardening
  - Profile and optimize `ImageCanvas` rendering to maintain 60 fps at 4096×4096 with `drawingGroup()` and lazy marker rendering
  - Implement background state save (within 1 second) using `scenePhase` `.background` handler
  - Implement foreground state restore (within 500 ms) using `scenePhase` `.active` handler
  - Implement crash recovery: save session state to a separate recovery file on every mutation; restore on next launch if recovery file exists
  - Verify RAM usage stays under 200 MB during manual counting using Instruments
  - _Requirements: 18.1, 18.2, 18.3, 18.4, 18.5, 18.8_

- [x] 28. Final checkpoint — Full integration (Phase 1)
  - Ensure all unit tests, property tests, and UI tests pass
  - Run the full XCUITest suite (launch, create session, place markers, run AI, export CSV)
  - Verify VoiceOver traversal on CountingView and SessionListView
  - Ask the user if questions arise before considering the implementation complete.

---

## Phase 2: Differentiator Features (Requirements 19–28)

- [x] 29. AR Counting (ARKit)
  - Add `ARKit` and `RealityKit` frameworks to the Xcode project
  - Implement `ARCountViewModel` managing `ARSession` with `ARWorldTrackingConfiguration`
  - Implement raycasting (`ARRaycastQuery`) to place `ARAnchor` at tapped real-world positions
  - Build `ARCountView` using `ARSCNView` via `UIViewRepresentable` with 3D sphere nodes for each anchor
  - Display distance-to-anchor label using `ARCamera` transform math
  - Implement `captureSnapshot()` using `ARSCNView.snapshot()`
  - Handle LiDAR-enhanced scene reconstruction on supported devices (iPhone 12 Pro+)
  - Graceful fallback message when ARKit world tracking is unavailable
  - _Requirements: 19.1–19.8_

  - [x] 29.1 Write property test for AR anchor tally
    - For any sequence of anchor placements and removals, assert tally equals active anchor count per Object_Type
    - **Property 11: AR anchor tally equals placed anchor count**
    - **Validates: Requirements 19.2**

- [x] 30. Custom CoreML Model Import
  - Implement `CustomModelService` with `importModel(from:)`, `validateModel(at:)`, `activateModel(_:)`
  - Validate imported model: check `MLModel.modelDescription` for VNRecognizedObjectObservation output type
  - Store imported model files in `Documents/models/` directory; persist `ModelMetadata` in SwiftData
  - Build `CustomModelView` in Settings showing active model info (name, input size, class count)
  - Implement model switcher: built-in YOLOv8n vs. any imported model
  - _Requirements: 20.1–20.7_

- [x] 31. ML Training Data Export (COCO + YOLO)
  - Implement `MLExportService.exportCOCO(session:images:)` producing valid COCO JSON with `images`, `annotations`, and `categories` arrays
  - Implement `MLExportService.exportYOLO(session:images:)` producing per-image `.txt` files with `class cx cy w h` format
  - Implement train/val/test split with configurable ratios using `MLExportService.exportTrainingSplit`
  - Package output as a ZIP archive using `ZipFoundation` (add via SPM)
  - Build `MLExportSheet` with class distribution preview and split ratio sliders
  - _Requirements: 21.1–21.6_

  - [x] 31.1 Write property test for COCO export annotation completeness
    - For any session with AI-derived markers, assert COCO JSON annotation count equals AI-derived marker count
    - **Property 13: COCO export contains all accepted detections**
    - **Validates: Requirements 21.1**

- [x] 32. Density Heatmap
  - Implement `HeatmapRenderer` using Metal compute shaders for GPU-accelerated KDE
  - Write a Metal kernel that accumulates Gaussian contributions from each marker position
  - Map density values to a cool-to-warm color gradient (blue → green → yellow → red)
  - Integrate heatmap toggle button in `CountingView` toolbar
  - Implement radius slider (10–100 pt) in the heatmap panel
  - Implement per-Object_Type filter and "all types combined" mode
  - Add heatmap PNG export via `ExportService`
  - _Requirements: 24.1–24.6_

  - [x] 32.1 Write property test for heatmap marker preservation
    - Toggle heatmap on/off N times, assert markers array is unchanged after each toggle
    - **Property 12: Heatmap renders without markers being lost**
    - **Validates: Requirements 24.2**

- [x] 33. Apple Watch Companion App
  - Add a watchOS app target `OpenCountWatch` to the Xcode project
  - Implement `WatchConnectivityService` on both iOS and watchOS sides using `WCSession`
  - Build Watch app UI: scrollable list of Object_Types with large tap targets and tally badges
  - Implement Digital Crown rotation to scroll through Object_Types
  - Implement offline queue: store increments in `UserDefaults` on Watch, flush on reconnect
  - Add a Watch complication (Graphic Circular) showing total session count
  - _Requirements: 22.1–22.6_

- [x] 34. Siri Shortcuts and WidgetKit
  - Implement `App Intents` conforming types: `CreateSessionIntent`, `GetTallyIntent`, `ExportSessionIntent`, `RunAICountingIntent`
  - Donate intents to Siri after relevant user actions using `INInteraction.donate`
  - Build a WidgetKit extension `OpenCountWidget` with small/medium/large widget families
  - Implement `TimelineProvider` that fetches the latest tally from SwiftData and schedules 15-minute refreshes
  - Add deep-link URL scheme `opencount://session/<id>` handled in `OpenCountApp`
  - Create 3 pre-built Shortcut templates and add them to the Shortcuts gallery via `AppShortcutsProvider`
  - _Requirements: 23.1–23.6, 27.1–27.4_

- [x] 35. Panorama / Large Image Counting
  - Implement `PanoramaTiler` that splits images larger than 4096×4096 into overlapping 1280×1280 tiles with 20% overlap
  - Run AI inference on each tile, then apply Non-Maximum Suppression (NMS) across tile boundaries to deduplicate detections
  - Implement a `CATiledLayer`-backed `PanoramaCanvasView` for smooth rendering of images up to 16384×16384
  - Implement full-resolution annotated image export using `UIGraphicsImageRenderer` with tiled drawing
  - _Requirements: 25.1–25.5_

- [x] 36. Template Marketplace (CloudKit Public Database)
  - Configure a CloudKit public database zone `TemplateMarketplace`
  - Implement `TemplateMarketplaceService` with `publishTemplate`, `fetchTemplates(query:)`, `installTemplate`, `rateTemplate`, `reportTemplate`
  - Build `TemplateGalleryView` with search bar, category filter chips, star ratings, and download counts
  - Implement template preview showing Object_Type colors and icons before install
  - Implement report flow: present reason picker, submit to CloudKit with `CKRecord` flag
  - _Requirements: 26.1–26.6_

- [x] 37. Collaborative Session Sharing
  - Configure CloudKit sharing: add `CKShare` capability to the Xcode project
  - Implement `CollaborationService` with `createShare(for:)`, `joinSession(shareURL:)`, `revokeAccess(for:)`
  - Implement real-time marker sync using `NSPersistentCloudKitContainer` change notifications
  - Build `CollaborationView` showing participant list with online/offline indicators and initials avatars
  - Render per-participant marker attribution: show initials badge on each marker placed by a remote participant
  - Implement conflict resolution: last-write-wins for marker position, union for marker sets
  - _Requirements: 28.1–28.7_

  - [x] 37.1 Write property test for collaborative sync marker count
    - Simulate two participants each adding N and M markers, merge, assert total = N + M with no duplicates
    - **Property 14: Collaborative sync preserves total marker count**
    - **Validates: Requirements 28.2, 28.5**

- [x] 38. Final checkpoint — Phase 2 complete
  - Ensure all Phase 2 unit tests and property tests pass
  - Run end-to-end UI tests for AR counting, Watch sync, and collaborative session
  - Verify App Intents work correctly in Shortcuts app
  - Verify WidgetKit timeline updates correctly
  - Performance test: panorama AI inference on 16K×16K image within 30 seconds
  - Ask the user if questions arise before considering Phase 2 complete.

---

## Phase 3: UX Excellence and Market Differentiation (Requirements 29–35)

- [x] 39. Onboarding and coach marks
  - Create `OnboardingCoordinator` with `@AppStorage("hasSeenOnboarding")` gate
  - Build `OnboardingView` as a 5-screen `TabView` with page indicators covering: session creation, manual counting, AI counting, region drawing, and export
  - Implement `CoachMarkOverlay` view modifier that renders a spotlight cutout + tooltip bubble anchored to any view
  - Register coach marks for: AI counting panel, Live Camera button, AR button, Batch button, Region drawing tool
  - Bundle `SampleSession.json` fixture with pre-loaded images and markers; seed it on first launch
  - Add "Replay Tutorial" and "Restore Sample Session" actions in `SettingsView`
  - _Requirements: 29.1–29.7_

- [x] 40. Localization — String Catalog and RTL
  - Migrate all hardcoded strings to `Localizable.xcstrings` (String Catalog format)
  - Add translation files for: `vi`, `ja`, `zh-Hans`, `fr`, `de`, `es`, `pt-BR`, `ko`, `ar`
  - Implement `LocalizationManager` with locale-aware number, date, and density formatters
  - Localize all CSV headers, PDF labels, and JSON field descriptions via `LocalizationManager.localizedExportHeader`
  - Verify RTL layout for Arabic: flip `HStack` leading/trailing, mirror navigation chevrons, test in Simulator with Arabic locale
  - Implement Unicode-aware session search using `String.localizedStandardContains` for CJK and Vietnamese diacritics
  - _Requirements: 30.1–30.7_

- [x] 41. iPad layout and Apple Pencil support
  - Replace `NavigationStack` root with `NavigationSplitView` on iPad (regular horizontal size class): session list in sidebar, `CountingView` in detail column
  - Implement `iPadLayoutCoordinator` managing column visibility and active annotation tool
  - Add `PKCanvasView` (`PencilKit`) overlay on `ImageCanvas` for Pencil-drawn region strokes; convert `PKStroke` path to normalized polygon points for `CountRegion`
  - Implement Apple Pencil double-tap handler via `UIPencilInteraction` to toggle between `.marker` and `.regionDraw` tools
  - Implement Pencil hover preview using `UIHoverGestureRecognizer` (iPadOS 16.1+) to show a ghost marker before touch-down
  - Register keyboard shortcuts: `⌘N`, `⌘Z`, `⌘⇧Z`, `⌘E`, `Space` via `.keyboardShortcut` modifiers
  - Add Stage Manager window scene support with `UIWindowScene.activationConditions`
  - _Requirements: 31.1–31.8_

- [x] 42. In-app feedback and crash reporting
  - Build `FeedbackComposerView` with type picker (Bug / Feature Request / Other), multi-line description editor, and optional screenshot attachment captured via `UIApplication.shared.connectedScenes` window snapshot
  - Implement `FeedbackService` posting to GitHub Issues API via `URLSession` background `URLSessionDataTask`; auto-attach `AppDiagnostics` (iOS version, device model, app version, build number)
  - Implement `MXMetricManager` subscriber (`MXMetricManagerSubscriber`) to receive `MXCrashDiagnosticPayload` on next app launch
  - On launch, if a pending crash report exists in `UserDefaults`, present a consent alert; on user consent, call `FeedbackService.submitCrashReport`; on denial, discard the report
  - Add "Diagnostics & Privacy" section in `SettingsView` with opt-out toggle persisted as `UserDefaults` key `diagnosticsOptIn`; when opt-out is active, skip all MetricKit transmission
  - Add "About" section in `SettingsView` showing app version (`CFBundleShortVersionString`), build number (`CFBundleVersion`), and a tappable GitHub repository link opening in `SFSafariViewController`
  - _Requirements: 32.1–32.7_

- [x] 43. Offline-first UX and network monitoring
  - Implement `NetworkMonitor` using `NWPathMonitor` on a dedicated background `DispatchQueue(label: "network-monitor")`; publish `isConnected: Bool` and `connectionType: ConnectionType` on `@MainActor`
  - Inject `NetworkMonitor` as `@EnvironmentObject` from `OpenCountApp` root; start monitor in `.onAppear`, stop in `.onDisappear`
  - Build `OfflineBanner` view as a `safeAreaInset(edge: .top)` overlay with slide-down animation; auto-dismiss with a 2-second delay after `isConnected` returns `true`
  - Gate Template Marketplace, Collaborative Session, and Feedback submission behind `networkMonitor.isConnected`; show `OfflineFeatureAlert` sheet with feature name and "Retry when online" button
  - Add 30-second timeout to all `URLSession` tasks via `URLSessionConfiguration.timeoutIntervalForRequest = 30`; on timeout, surface `AppError.networkTimeout` with a retry button in the view
  - Cache last-fetched template list in `UserDefaults` key `cachedTemplates` as JSON data; load cache on `TemplateGalleryView` appear when offline
  - _Requirements: 33.1–33.6_

- [x] 44. Advanced annotation layers
  - Implement `AnnotationLayerViewModel` with `@Published var textAnnotations: [TextAnnotation]`, `measureLines: [MeasureLine]`, `arrowAnnotations: [ArrowAnnotation]`, and `visibleLayers: Set<AnnotationLayerType>`
  - Build `TextAnnotationTool`: single tap on canvas places a `TextAnnotation`; inline `TextField` appears immediately for text entry; font size (12–36 pt) and color pickers in a popover
  - Build `MeasureLineTool`: drag gesture draws a `MeasureLine`; display normalized length formatted as `"X.XX units"` in a label at the line midpoint; update label live during drag
  - Build `ArrowAnnotationTool`: drag from tail to head; render a filled arrowhead polygon at the head point; color picker in toolbar
  - Build `LayerPanelView`: a slide-in sheet from the trailing edge listing all `AnnotationLayerType` cases with eye-icon toggles; changes update `visibleLayers` immediately
  - Update `ExportService.exportAnnotatedImage` and `exportPDF` to composite all visible annotation layers using `UIGraphicsImageRenderer` in z-order: image → regions → markers → AI boxes → text → lines → arrows → heatmap
  - Add per-layer export selection checkboxes in `ExportSheet`; unchecked layers are excluded from the rendered output
  - _Requirements: 34.1–34.6_

  - [x] 44.1 Write property test for annotation layer toggle immutability
    - Generate random `[TextAnnotation]`, `[MeasureLine]`, `[ArrowAnnotation]` arrays
    - Toggle each `AnnotationLayerType` on and off N times (N ∈ 1–20)
    - Assert that all three annotation arrays are identical before and after all toggles
    - **Property 16: Annotation layer toggle does not mutate data**
    - **Validates: Requirements 34.5**

  - [x] 44.2 Write property test for localized export headers
    - For every supported locale (`en`, `vi`, `ja`, `zh-Hans`, `fr`, `de`, `es`, `pt-BR`, `ko`, `ar`) and every `ExportColumn` case
    - Assert `LocalizationManager.localizedExportHeader(for:)` returns a non-empty string
    - **Property 17: Localized export headers are non-empty for all supported locales**
    - **Validates: Requirements 30.6**

- [x] 45. Smart count suggestions and duplicate detection
  - Implement `SmartCountService.isDuplicate(newPoint:existingMarkers:objectType:duplicateRadius:)` using Euclidean distance in normalized coordinates; default `duplicateRadius = 0.02`
  - Wire duplicate check into `CountingViewModel.placeMarker`: if `isDuplicate` returns `true`, show a non-blocking `.confirmationDialog("Possible duplicate — are you sure?")` before committing the marker; user can confirm or cancel
  - Implement `SmartCountService.findMissedObjects(in:existingMarkers:aiService:lowThreshold:)`: run AI at `lowThreshold = 0.2`, filter out detections whose bounding box centroid is within `duplicateRadius` of any existing marker of the same type
  - Build "Find Missed Objects" button in the AI panel toolbar; while running, show a progress indicator; on completion, render candidate detections with amber bounding boxes and per-detection Accept / Dismiss buttons
  - Implement counting velocity tracker in `CountingViewModel`: maintain a `var markerTimestamps: [Date]` sliding 60-second window; compute `markersPerMinute`; publish `@Published var isFatigueWarningActive: Bool = false`; set to `true` when velocity > 60/min for > 2 consecutive minutes; show a dismissible banner "You're counting fast — take a moment to verify"
  - Implement "Review Mode": a `ReviewModeSheet` that iterates through all `CountMarker` objects sorted by `createdAt`; each step centers the marker on the canvas with a zoom-to-fit animation; display marker index, Object_Type name, and coordinates; provide Prev / Next / Delete buttons; close button exits review mode
  - _Requirements: 35.1–35.5_

  - [x] 45.1 Write property test for duplicate detection symmetry
    - Generate random pairs of `CGPoint` values (A, B) with the same `ObjectType`
    - Assert: `isDuplicate(A, [B])` == `isDuplicate(B, [A])` for all inputs (distance is commutative)
    - **Property 15: Duplicate detection radius is symmetric**
    - **Validates: Requirements 35.1**

- [x] 46. Final checkpoint — Phase 3 complete
  - Ensure all Phase 3 unit tests and property tests pass (Properties 15, 16, 17)
  - Verify onboarding flow on a fresh simulator install: delete app, reinstall, confirm 5-screen flow appears, complete it, relaunch and confirm it does not appear again
  - Verify RTL layout with Arabic locale in Simulator: session list, counting toolbar, export sheet all mirror correctly
  - Verify iPad Split View and Pencil drawing on iPad Simulator (iPadOS 16.1+)
  - Verify offline banner appears and auto-dismisses when toggling network in Simulator
  - Verify "Find Missed Objects" surfaces amber detections and Accept/Dismiss controls
  - Verify Review Mode steps through all markers with correct canvas centering
  - Ask the user if questions arise before considering Phase 3 complete.

---

## Phase 4: Market Leadership (Requirements 36–47)

> **Product Owner Rationale:** Phase 4 targets the features that no competitor — paid or free — currently offers. These are the capabilities that turn OpenCount from "a good free alternative" into "the definitive counting tool." Each feature was chosen because it either (a) solves a real pain point that ZapCount/CountThings users complain about publicly, or (b) opens a new user segment (researchers, field workers, enterprise teams) that neither competitor serves.

- [x] 47. Count History Timeline and Audit Log
  - Add `CountHistoryEntry` SwiftData model: `id`, `sessionID`, `objectTypeID`, `operation` (`.add` / `.remove` / `.accept` / `.reassign`), `markerID`, `timestamp`, `source` (`.manual` / `.ai` / `.watch` / `.shortcut`)
  - Record every tally-changing operation in `CountingViewModel` as a `CountHistoryEntry` persisted to SwiftData
  - Build `CountHistoryView`: a chronological list of all history entries for a session, grouped by date, with undo-to-point capability (restore session state to any historical entry)
  - Add "Export Audit Log" action in `ExportSheet` producing a CSV with columns: timestamp, operation, object_type, marker_id, source
  - Display a sparkline chart in `SessionRowView` showing counting activity over the last 7 days for each session
  - _Requirements: 13.6, Requirement 36_

- [x] 48. On-Device AI Fine-Tuning with Create ML
  - Implement `ModelFineTuningService` using `CreateML` framework (`MLObjectDetector`) to fine-tune the bundled YOLOv8n model on user-annotated data from any session
  - Build `FineTuningView`: select a session as training data, configure epochs (5–50) and learning rate, display live training loss chart using Swift Charts
  - Run training on a background `Task` using `MLJob`; publish `@Published var trainingProgress: Double` and `trainingLoss: [Double]`
  - On training completion, export the fine-tuned model as `.mlpackage` to `Documents/models/` and register it via `CustomModelService`
  - Add "Fine-tune from this session" button in `CustomModelView`
  - _Requirements: 20.1–20.7, Requirement 37_

- [x] 49. Multi-Device Handoff and Universal Clipboard
  - Implement `NSUserActivity` with `activityType = "com.opencount.counting"` carrying `sessionID` and `imageIndex` in `userInfo`
  - Set `isEligibleForHandoff = true` and update the activity on every session navigation change
  - Handle incoming `NSUserActivity` in `OpenCountApp.onContinueUserActivity` to deep-link directly to the correct session and image
  - Implement Universal Clipboard: when the user copies a tally summary on iPhone, it is available on nearby Mac/iPad via `UIPasteboard.general` with `localOnly = false`
  - Add "Continue on Mac" button in `ExportSheet` that uses `NSUserActivity` to hand off the export operation to macOS Catalyst
  - _Requirements: Requirement 38_

- [x] 50. Accessibility Deep Audit and WCAG 2.1 AA Compliance
  - Audit every interactive element in `CountingView`, `SessionListView`, `LiveCountView`, `ARCountView`, and `BatchJobView` for VoiceOver label completeness and correctness
  - Add `accessibilityValue` to all tally badges (e.g., "3 people counted") and `accessibilityHint` to all gesture-driven controls (e.g., "Double-tap to place marker")
  - Implement `accessibilityAdjustableAction` on the confidence threshold slider for VoiceOver swipe-up/down adjustment
  - Add `accessibilityChartDescriptor` (iOS 16+) to all Swift Charts charts in `StatisticsView` for VoiceOver audio graph support
  - Implement Switch Control scanning order for `CountingView` toolbar and canvas
  - Add "Reduce Motion" support: disable all spring animations and replace with opacity transitions when `UIAccessibility.isReduceMotionEnabled`
  - Write XCUITest accessibility audit using `XCUIElement.performAccessibilityAudit()` (Xcode 15+) for all major screens
  - _Requirements: 16.1–16.5, Requirement 39_

- [x] 51. Performance Dashboard and Diagnostics
  - Build `PerformanceDashboardView` (developer/beta mode only, toggled by a hidden Settings tap sequence: tap version label 7 times) showing:
    - Live FPS counter for `ImageCanvas` using `CADisplayLink`
    - Current RAM usage via `task_info` mach call
    - AI inference latency histogram (last 20 runs) using Swift Charts
    - SwiftData query times for last 10 fetch operations
    - Active `URLSession` tasks and their states
  - Implement `PerformanceMonitor` actor that samples FPS and RAM every 500 ms and publishes to `@Published` properties
  - Add "Export Diagnostics" action that produces a JSON report of all performance metrics for the current session, shareable via the iOS Share Sheet
  - _Requirements: 18.1–18.8, Requirement 40_

- [x] 52. Count Verification QR Code
  - Implement `QRCodeService` using `CIFilter(name: "CIQRCodeGenerator")` to encode a session's tally summary as a QR code
  - The QR payload is a compact JSON: `{"session": "<name>", "date": "<ISO8601>", "counts": {"<type>": <n>, ...}, "hash": "<SHA256 of payload>"}`
  - Build `QRCodeView`: displays the generated QR code with the session name and date below; "Share" button presents the QR as a PNG via the Share Sheet
  - Implement QR scanner in `SessionListView`: a camera button that scans an OpenCount QR code and navigates to the matching session or displays the tally summary if the session is not local
  - Add "Attach QR to PDF" option in `ExportSheet` that embeds the QR code in the PDF report footer
  - _Requirements: 12.4, Requirement 41_

- [x] 53. Configurable Count Targets and Progress Tracking
  - Add `targetCount: Int?` field to `ObjectType` SwiftData model (optional; nil means no target)
  - Build target-setting UI in `ObjectTypeEditorView`: a stepper or text field for "Count Target (optional)"
  - In `CountingView` Object_Type toolbar, display a progress ring around each type's tally badge when a target is set; ring fills as count approaches target; turns green at 100%, red if exceeded
  - Add `@Published var completedObjectTypes: Set<UUID>` to `CountingViewModel`; trigger a success haptic and a brief confetti animation (using `CAEmitterLayer`) when a target is first reached
  - Display target progress in `StatisticsView` as a horizontal progress bar per Object_Type
  - Export target and progress data in CSV and JSON exports
  - _Requirements: Requirement 42_

- [x] 54. Session Templates — Private Library and Full Session Templates
  - Extend `ObjectType` template system to support full `CountSession` templates (Object_Types + default regions + target counts)
  - Build `PrivateTemplateLibrary`: user can save any session as a private template stored in SwiftData; templates are listed in `NewSessionSheet` for one-tap session creation
  - Extend `TemplateMarketplaceService` to support full session templates (not just Object_Type sets); update `TemplateGalleryView` with a "Session Templates" tab
  - Implement template versioning: each published template has a `version: Int`; installed templates show an "Update available" badge when a newer version is published
  - Add "Import from URL" action in `TemplateGalleryView` to install a template from a direct CloudKit share URL
  - _Requirements: 14.3, 14.4, 26.1–26.6, Requirement 43_

- [x] 55. Local REST API and Extended URL Scheme
  - Implement a local HTTP server using `Network.framework` (`NWListener`) on `localhost:47200` exposing:
    - `GET /sessions` — list all sessions as JSON
    - `GET /sessions/{id}/tally` — return current tally for a session
    - `POST /sessions/{id}/markers` — add a marker programmatically (body: `{objectType, x, y}`)
    - `GET /sessions/{id}/export?format=csv|json` — stream export file
  - The server is opt-in, toggled in Settings under "Developer Tools"; disabled by default; binds only to `localhost`
  - Extend the `opencount://` URL scheme with: `opencount://session/<id>`, `opencount://new-session?name=<n>`, `opencount://tally/<sessionID>/<objectType>`
  - Write `README-API.md` to the app's Documents directory when the server is first enabled
  - _Requirements: 27.1–27.4, Requirement 44_

- [x] 56. App Clip for Quick Count
  - Create an App Clip target `OpenCountClip` with a single-screen UI: camera viewfinder with live AI counting overlay and a large tally display
  - The App Clip is invoked via an NFC tag or QR code encoding `https://opencount.app/clip?session=<id>`; it opens directly to live counting for the specified session
  - On App Clip close, prompt the user to install the full app via `SKOverlay`
  - App Clip binary must remain under 15 MB; use a quantized INT8 YOLOv8n-nano CoreML model for the clip target
  - _Requirements: Requirement 45_

- [x] 57. macOS Catalyst Support
  - Enable macOS Catalyst target in Xcode project settings (Mac Idiom: Scaled), targeting macOS 13.0+
  - Adapt `CountingView` for mouse input: click to place marker, right-click for context menu, scroll wheel for zoom
  - Replace `UIActivityViewController` with `NSSharingServicePicker` on macOS using `#if targetEnvironment(macCatalyst)`
  - Add drag-and-drop image import from Finder using `onDrop(of: [.image])` modifier
  - Implement macOS menu bar items: File > New Session, Edit > Undo/Redo, Session > Run AI Counting, Session > Export
  - _Requirements: Requirement 46_

- [x] 58. Final checkpoint — Phase 4 complete
  - Ensure all Phase 4 unit tests and property tests pass (Properties 18, 19, 20, 21)
  - Verify Handoff: start counting on iPhone, pick up on iPad — session opens at correct image
  - Verify QR code generation and scanning round-trip: generate QR, scan it, verify tally matches
  - Verify count target progress ring fills correctly and confetti fires on first completion
  - Verify local REST API returns correct tally JSON at `localhost:47200/sessions/{id}/tally`
  - Verify App Clip binary is under 15 MB and opens live counting within 3 seconds
  - Performance test: fine-tuning 100 annotations completes within 5 minutes on iPhone 14
  - Ask the user if questions arise before considering Phase 4 complete.

## Task Dependency Graph

## Task Dependency Graph

```json
{
  "waves": [
    { "wave": 1, "tasks": ["1"] },
    { "wave": 2, "tasks": ["2"] },
    { "wave": 3, "tasks": ["3"] },
    { "wave": 4, "tasks": ["4"] },
    { "wave": 5, "tasks": ["5", "6"] },
    { "wave": 6, "tasks": ["7"] },
    { "wave": 7, "tasks": ["8", "9"] },
    { "wave": 8, "tasks": ["10"] },
    { "wave": 9, "tasks": ["11"] },
    { "wave": 10, "tasks": ["12"] },
    { "wave": 11, "tasks": ["13", "14"] },
    { "wave": 12, "tasks": ["15"] },
    { "wave": 13, "tasks": ["16", "17", "18"] },
    { "wave": 14, "tasks": ["19"] },
    { "wave": 15, "tasks": ["20", "21", "23"] },
    { "wave": 16, "tasks": ["22"] },
    { "wave": 17, "tasks": ["24"] },
    { "wave": 18, "tasks": ["25", "26"] },
    { "wave": 19, "tasks": ["27"] },
    { "wave": 20, "tasks": ["28"] },
    { "wave": 21, "tasks": ["29", "30", "31", "32"] },
    { "wave": 22, "tasks": ["33", "34", "35"] },
    { "wave": 23, "tasks": ["36", "37"] },
    { "wave": 24, "tasks": ["38"] },
    { "wave": 25, "tasks": ["39", "40", "41"] },
    { "wave": 26, "tasks": ["42", "43"] },
    { "wave": 27, "tasks": ["44", "45"] },
    { "wave": 28, "tasks": ["46"] },
    { "wave": 29, "tasks": ["47", "48", "49"] },
    { "wave": 30, "tasks": ["50", "51", "52"] },
    { "wave": 31, "tasks": ["53", "54", "55"] },
    { "wave": 32, "tasks": ["56", "57"] },
    { "wave": 33, "tasks": ["58"] }
  ]
}
```

## Notes

- Tasks marked with `*` are optional and can be skipped for a faster MVP build
- Each task references specific requirements for traceability
- Property tests use SwiftCheck with a minimum of 100 iterations per property
- All property tests are tagged with `// Feature: open-count-ios, Property N: <text>`
- The YOLOv8n CoreML model must be converted from ONNX using `coremltools` before task 11
- CloudKit entitlements must be added to the Xcode project before task 24
- ARKit entitlement (`NSCameraUsageDescription` + `ARWorldTrackingConfiguration`) required before task 29
- WatchConnectivity framework and watchOS target required before task 33
- WidgetKit extension target required before task 34
- ZipFoundation SPM package required before task 31: `https://github.com/weichsel/ZIPFoundation`
- Metal framework (already included in iOS SDK) used for GPU heatmap in task 32
- CloudKit public database zone `TemplateMarketplace` must be created in CloudKit Dashboard before task 36
- CKShare capability must be enabled in Xcode project entitlements before task 37
- CreateML framework (included in iOS 15+ SDK) required for task 48; training only runs on device, not Simulator
- `NSUserActivity` Handoff requires `com.apple.developer.associated-domains` entitlement for task 49
- App Clip target requires `Associated Domains` entitlement with `appclip:` prefix for task 56
- macOS Catalyst target requires `Mac` destination enabled in Xcode project for task 57
- `Network.framework` local HTTP server (task 55) must bind only to `127.0.0.1`; never expose to external network

## Phase Summary

| Phase | Tasks | Status | Key Deliverable |
|---|---|---|---|
| Phase 1 — Core | 1–28 | ✅ Complete | Manual + AI counting, ROI, live camera, batch, video, iCloud, stats, export |
| Phase 2 — Differentiators | 29–38 | ✅ Complete | AR, Watch, Shortcuts, heatmap, collaboration, panorama, templates, ML export |
| Phase 3 — UX Excellence | 39–46 | ✅ Complete | Onboarding, i18n, iPad/Pencil, offline UX, smart counting, annotation layers |
| Phase 4 — Market Leadership | 47–58 | ✅ Complete | Audit log, AI fine-tuning, Handoff, WCAG audit, QR verification, count targets, App Clip, macOS |
| Infrastructure | 59 | ✅ Complete | GitHub Actions CI + IPA build workflow, XcodeGen project generation |
