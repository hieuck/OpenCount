import Foundation
import SwiftUI
import UIKit
import Combine
import PhotosUI
import UniformTypeIdentifiers

// MARK: - CountingViewModel

/// Central ViewModel for an active counting session.
///
/// Coordinates manual counting, AI detection results, region management,
/// undo/redo, and real-time tally computation.
///
/// Requirements: 3.1, 3.2, 3.3, 3.5, 3.6, 3.7, 3.8, 3.9, 3.10,
///               6.1, 6.2, 6.3, 6.4, 6.5, 7.1, 7.2, 7.3, 7.4
@MainActor
final class CountingViewModel: ObservableObject {

    // MARK: - Published state

    @Published var session: CountSession
    @Published var selectedObjectType: ObjectType?
    @Published var markers: [CountMarker] = []
    @Published var detections: [AIDetection] = []
    @Published var regions: [CountRegion] = []
    @Published var confidenceThreshold: Float = 0.5
    @Published var isGridOverlayEnabled: Bool = false
    @Published var isHeatmapEnabled: Bool = false
    @Published var gridDensity: Int = 5 {
        didSet {
            // Reset completed cells whenever the grid density changes,
            // because the cell indices no longer correspond to the same areas.
            completedCells = []
        }
    }
    /// The set of 0-based, row-major cell indices that the user has marked as counted.
    /// Requirement 4.4: toggle cell "counted" state.
    @Published var completedCells: Set<Int> = []
    @Published var isAIRunning: Bool = false
    @Published var aiProgress: Double = 0.0
    @Published var error: AppError?

    // MARK: - Computed: tallies

    /// Global tally: count of markers per ObjectType across the entire session.
    /// Requirement 3.7, 6.5: display tally in real time.
    var globalTally: [ObjectType: Int] {
        var tally: [ObjectType: Int] = [:]
        for marker in markers {
            tally[marker.objectType, default: 0] += 1
        }
        return tally
    }

    /// AI detections filtered by the current confidence threshold.
    /// Requirement 5.5, 5.6: update displayed detections when threshold changes.
    var filteredDetections: [AIDetection] {
        detections.filter { $0.confidenceScore >= confidenceThreshold }
    }

    // MARK: - Private

    private var undoStack = UndoStack<[CountMarker]>(capacity: 50)
    private let haptic = UIImpactFeedbackGenerator(style: .medium)
    private let smartCountService = SmartCountService()
    private var velocityTracker = CountingVelocityTracker()

    /// Watch connectivity service — sends session updates to the paired Watch.
    /// Requirement 22.1, 22.2
    private let watchService = WatchConnectivityService.shared

    /// Collaboration service for real-time multi-device sync.
    /// Requirement 28.1–28.6
    private let collaborationService = CollaborationService.shared

    // MARK: - Collaboration state

    @Published var isCollaborating: Bool = false

    // MARK: - Smart count state

    /// Whether a duplicate warning should be shown for the pending marker placement.
    @Published var isDuplicateWarningActive: Bool = false
    /// The pending normalized point waiting for duplicate confirmation.
    @Published var pendingDuplicatePoint: CGPoint?
    /// Whether the fatigue warning banner should be shown.
    @Published var isFatigueWarningActive: Bool = false
    /// Candidate "missed objects" detections from the secondary AI pass.
    @Published var missedObjectCandidates: [AIDetection] = []
    /// Whether the "Find Missed Objects" AI pass is running.
    @Published var isFindingMissedObjects: Bool = false

    // MARK: - Count target state (Requirement 53 / Req 42)

    /// Set of ObjectType IDs whose count target has been reached (used to fire confetti once).
    @Published var completedObjectTypes: Set<UUID> = []
    /// Whether the confetti animation should fire (set to true when a target is first reached).
    @Published var shouldFireConfetti: Bool = false

    // MARK: - Init

    init(session: CountSession) {
        self.session = session
        self.markers = session.markers
        self.regions = session.regions
        self.selectedObjectType = session.objectTypes.sorted { $0.sortOrder < $1.sortOrder }.first
        haptic.prepare()

        // Wire Watch connectivity: receive increments from Watch and apply them.
        // Requirement 22.2
        watchService.onCountIncrement = { [weak self] objectTypeID, sessionID in
            guard let self = self, self.session.id == sessionID else { return }
            if let objectType = self.session.objectTypes.first(where: { $0.id == objectTypeID }) {
                let marker = CountMarker(
                    normalizedX: 0.5,
                    normalizedY: 0.5,
                    objectType: objectType,
                    session: self.session
                )
                self.markers.append(marker)
                self.session.markers.append(marker)
                self.session.modifiedAt = Date()
                CrashRecoveryService.saveRecovery(session: self.session)
            }
        }

        // Send initial session state to Watch when session opens.
        // Requirement 22.1
        watchService.sendSessionUpdate(session)

        // Load the most recent image for this session from disk
        loadCurrentImage()
    }

    // MARK: - Watch sync helper

    /// Sends the current session state to the paired Watch.
    /// Called after every mutation that changes tallies.
    /// Requirement 22.1
    private func syncToWatch() {
        watchService.sendSessionUpdate(session)
    }

    // MARK: - Manual counting

    /// Places a marker at the given point (in image-coordinate space, normalized 0–1).
    ///
    /// If the point is within `duplicateRadius` of an existing marker of the same type,
    /// sets `isDuplicateWarningActive = true` and stores the point in `pendingDuplicatePoint`
    /// instead of placing immediately. The view layer must call `confirmPendingMarker()` or
    /// `cancelPendingMarker()` in response to the user's choice.
    ///
    /// Requirement 3.1: place a Count_Marker and increment tally.
    /// Requirement 3.10: haptic feedback on placement.
    /// Requirement 35.1: warn when a new marker is placed within 20 normalized pixels of an
    ///                    existing marker of the same type.
    func placeMarker(at normalizedPoint: CGPoint) {
        guard let objectType = selectedObjectType else { return }

        // Requirement 35.1: duplicate detection — warn before committing.
        if smartCountService.isDuplicate(
            newPoint: normalizedPoint,
            existingMarkers: markers,
            objectType: objectType
        ) {
            pendingDuplicatePoint = normalizedPoint
            isDuplicateWarningActive = true
            return
        }

        commitMarker(at: normalizedPoint, objectType: objectType)
    }

    /// Commits the pending duplicate marker after the user confirms.
    /// Requirement 35.1
    func confirmPendingMarker() {
        guard let point = pendingDuplicatePoint,
              let objectType = selectedObjectType else { return }
        pendingDuplicatePoint = nil
        isDuplicateWarningActive = false
        commitMarker(at: point, objectType: objectType)
    }

    /// Cancels the pending duplicate marker placement.
    /// Requirement 35.1
    func cancelPendingMarker() {
        pendingDuplicatePoint = nil
        isDuplicateWarningActive = false
    }

    /// Internal: unconditionally places a marker and updates all derived state.
    private func commitMarker(at normalizedPoint: CGPoint, objectType: ObjectType) {
        // Snapshot current state for undo before mutation.
        undoStack.push(markers)

        let marker = CountMarker(
            normalizedX: Double(normalizedPoint.x),
            normalizedY: Double(normalizedPoint.y),
            objectType: objectType,
            session: session
        )
        markers.append(marker)
        session.markers.append(marker)
        session.modifiedAt = Date()

        // Record tally history entry for this marker placement (delta = +1).
        let historyEntry = TallyHistoryEntry(
            timestamp: Date(),
            objectTypeName: objectType.name,
            delta: 1
        )
        session.tallyHistory.append(historyEntry)

        // Requirement 18.5: persist session state to recovery file after every mutation.
        CrashRecoveryService.saveRecovery(session: session)

        haptic.impactOccurred()

        // Requirement 35.4: track counting velocity for fatigue warning.
        velocityTracker.recordPlacement()
        isFatigueWarningActive = velocityTracker.updateFatigueState()

        // Requirement 53 (Req 42): check if a count target has been reached for the first time.
        if let target = objectType.targetCount, target > 0 {
            let newCount = markers.filter { $0.objectType.id == objectType.id }.count
            if newCount >= target && !completedObjectTypes.contains(objectType.id) {
                completedObjectTypes.insert(objectType.id)
                shouldFireConfetti = true
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                // Reset confetti flag after a short delay so it can fire again if needed
                Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 500_000_000)
                    shouldFireConfetti = false
                }
            }
        }

        // Requirement 22.1: sync updated tallies to paired Watch.
        syncToWatch()

        // Requirement 28.2: push marker to CloudKit for collaborative sync.
        if isCollaborating {
            let capturedMarker = marker
            let capturedSessionID = session.id
            Task {
                await collaborationService.pushMarker(capturedMarker, sessionID: capturedSessionID)
            }
        }
    }

    /// Dismisses the fatigue warning banner.
    /// Requirement 35.4
    func dismissFatigueWarning() {
        isFatigueWarningActive = false
    }

    // MARK: - Find Missed Objects

    /// Runs a secondary AI pass at low confidence and surfaces detections not already
    /// covered by existing markers.
    ///
    /// Requirement 35.2, 35.3
    func findMissedObjects(in image: UIImage, aiService: AIServiceProtocol) async {
        isFindingMissedObjects = true
        defer { isFindingMissedObjects = false }
        do {
            let candidates = try await smartCountService.findMissedObjects(
                in: image,
                existingMarkers: markers,
                aiService: aiService
            )
            missedObjectCandidates = candidates
        } catch {
            self.error = .aiInferenceFailed(reason: error.localizedDescription)
        }
    }

    /// Accepts a missed-object candidate by converting it to a marker.
    /// Requirement 35.3
    func acceptMissedCandidate(_ detection: AIDetection) {
        guard let objectType = selectedObjectType else { return }
        let centroid = detection.normalizedCentroid
        commitMarker(at: centroid, objectType: objectType)
        missedObjectCandidates.removeAll { $0.id == detection.id }
    }

    /// Dismisses a missed-object candidate without placing a marker.
    /// Requirement 35.3
    func dismissMissedCandidate(_ detection: AIDetection) {
        missedObjectCandidates.removeAll { $0.id == detection.id }
    }

    /// Removes the given marker and decrements the corresponding tally.
    ///
    /// Requirement 3.3: delete a Count_Marker and decrement tally.
    func removeMarker(_ marker: CountMarker) {
        undoStack.push(markers)
        markers.removeAll { $0.id == marker.id }
        session.markers.removeAll { $0.id == marker.id }
        session.modifiedAt = Date()

        // Record tally history entry for this marker removal (delta = -1).
        let historyEntry = TallyHistoryEntry(
            timestamp: Date(),
            objectTypeName: marker.objectType.name,
            delta: -1
        )
        session.tallyHistory.append(historyEntry)

        // Requirement 18.5: persist session state to recovery file after every mutation.
        CrashRecoveryService.saveRecovery(session: session)

        // Requirement 22.1: sync updated tallies to paired Watch.
        syncToWatch()
    }

    /// Reassigns a marker to a different ObjectType.
    ///
    /// Requirement 7.3: reassign a Count_Marker from one Object_Type to another.
    func reassignMarker(_ marker: CountMarker, to objectType: ObjectType) {
        undoStack.push(markers)
        if let index = markers.firstIndex(where: { $0.id == marker.id }) {
            markers[index].objectType = objectType
        }
        if let index = session.markers.firstIndex(where: { $0.id == marker.id }) {
            session.markers[index].objectType = objectType
        }
        session.modifiedAt = Date()
        syncToWatch()
    }

    // MARK: - Undo / Redo

    /// Undoes the last marker placement or removal.
    ///
    /// Requirement 3.5, 3.6: undo within 100 ms.
    func undo() {
        guard let previous = undoStack.undo(currentState: markers) else { return }
        markers = previous
        session.markers = previous
        session.modifiedAt = Date()
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        syncToWatch()
    }

    /// Redoes the last undone operation.
    func redo() {
        guard let next = undoStack.redo(currentState: markers) else { return }
        markers = next
        session.markers = next
        session.modifiedAt = Date()
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        syncToWatch()
    }

    var canUndo: Bool { undoStack.canUndo }
    var canRedo: Bool { undoStack.canRedo }

    // MARK: - Grid overlay

    /// Toggles the "completed" state of the given 0-based cell index.
    ///
    /// Requirement 4.4: tapping a grid cell toggles its counted state.
    func toggleCell(_ index: Int) {
        if completedCells.contains(index) {
            completedCells.remove(index)
        } else {
            completedCells.insert(index)
        }
    }

    /// The total number of cells in the current grid (density × density).
    ///
    /// Requirement 4.6: display completed-cell count and total cells.
    var totalCells: Int {
        let d = gridDensity.clamped(to: 2...20)
        return d * d
    }

    /// The number of cells the user has marked as completed.
    ///
    /// Requirement 4.6: display completed-cell count in the toolbar.
    var completedCellCount: Int {
        completedCells.count
    }

    // MARK: - Image import

    /// Saves an imported image to disk, creates a SessionImage record, and sets it as current.
    ///
    /// Images are stored in Documents/images/<sessionID>/<uuid>.jpg
    func importImage(_ image: UIImage, session: CountSession) async {
        let imagesDir = FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("images")
            .appendingPathComponent(session.id.uuidString)

        try? FileManager.default.createDirectory(at: imagesDir,
                                                  withIntermediateDirectories: true)

        let filename = "\(UUID().uuidString).jpg"
        let fileURL = imagesDir.appendingPathComponent(filename)

        // Compress to JPEG at 0.85 quality to balance size and fidelity
        if let data = image.jpegData(compressionQuality: 0.85) {
            try? data.write(to: fileURL)
        }

        // Generate thumbnail (256×256 max)
        let thumbFilename = "thumb_\(filename)"
        let thumbURL = imagesDir.appendingPathComponent(thumbFilename)
        if let thumb = image.preparingThumbnail(of: CGSize(width: 256, height: 256)),
           let thumbData = thumb.jpegData(compressionQuality: 0.7) {
            try? thumbData.write(to: thumbURL)
        }

        let sessionImage = SessionImage(
            filename: filename,
            thumbnailFilename: thumbFilename,
            session: session
        )
        session.images.append(sessionImage)
        session.modifiedAt = Date()
        CrashRecoveryService.saveRecovery(session: session)

        // Set as the active canvas image
        currentImage = image
    }

    /// Loads the most recent SessionImage from disk for the current session.
    func loadCurrentImage() {
        guard let sessionImage = session.images.sorted(by: { $0.importedAt > $1.importedAt }).first else {
            return
        }
        let imagesDir = FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("images")
            .appendingPathComponent(session.id.uuidString)
        let fileURL = imagesDir.appendingPathComponent(sessionImage.filename)
        if let image = UIImage(contentsOfFile: fileURL.path) {
            currentImage = image
        }
    }

    // MARK: - Current image

    /// The currently displayed image in the canvas. Set by CountingView after import.
    @Published var currentImage: UIImage?

    /// Zero-based index of the currently displayed image within the session's
    /// sorted image list.  Used by MultiImageNavigatorView to highlight the
    /// active thumbnail.
    @Published var currentImageIndex: Int = 0

    /// Loads the image at `index` from `session.images` (sorted by importedAt)
    /// and sets it as the active canvas image.
    ///
    /// Called by MultiImageNavigatorView when the user taps a thumbnail.
    func selectImage(at index: Int, session: CountSession) {
        let sorted = session.images.sorted { $0.importedAt < $1.importedAt }
        guard sorted.indices.contains(index) else { return }
        let sessionImage = sorted[index]
        let imagesDir = FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("images")
            .appendingPathComponent(session.id.uuidString)
        let fileURL = imagesDir.appendingPathComponent(sessionImage.filename)
        if let image = UIImage(contentsOfFile: fileURL.path) {
            currentImage = image
            currentImageIndex = index
        }
    }

    // MARK: - AI counting

    /// Runs AI object detection on the given image and populates `detections`.
    ///
    /// Requirements: 5.1, 5.3, 5.7, 5.8, 5.9, 5.10, 5.11
    func runAIDetection(on image: UIImage) async throws {
        guard !isAIRunning else { return }
        isAIRunning = true
        aiProgress = 0.0
        defer {
            isAIRunning = false
            aiProgress = 1.0
        }

        let aiService = CoreMLAIService()
        let results = try await aiService.detect(
            in: image,
            confidenceThreshold: confidenceThreshold
        )

        // Merge with existing detections (avoid duplicates by bounding-box overlap)
        let newDetections = results.filter { newDet in
            !detections.contains { existing in
                existing.normalizedBoundingBox.intersection(newDet.normalizedBoundingBox).area
                    / max(newDet.normalizedBoundingBox.area, 0.0001) > 0.5
            }
        }
        detections.append(contentsOf: newDetections)
    }

    /// Runs zero-shot similarity detection using a sample crop.
    ///
    /// Requirement 5.2
    func runSimilarityDetection(sampleRect: CGRect, in image: UIImage) async throws {
        guard !isAIRunning else { return }
        isAIRunning = true
        aiProgress = 0.0
        defer {
            isAIRunning = false
            aiProgress = 1.0
        }

        let aiService = CoreMLAIService()
        let results = try await aiService.detectSimilar(to: sampleRect, in: image)
        detections.append(contentsOf: results)
    }

    func acceptDetection(_ detection: AIDetection) {
        guard let objectType = selectedObjectType else { return }
        undoStack.push(markers)
        let centroid = detection.normalizedCentroid
        let marker = CountMarker(
            normalizedX: Double(centroid.x),
            normalizedY: Double(centroid.y),
            objectType: objectType,
            isAIDerived: true,
            session: session
        )
        markers.append(marker)
        session.markers.append(marker)
        if let idx = detections.firstIndex(where: { $0.id == detection.id }) {
            detections[idx].isAccepted = true
        }
        session.modifiedAt = Date()
        syncToWatch()
    }

    func acceptAllDetections() {
        for detection in filteredDetections where !detection.isAccepted {
            acceptDetection(detection)
        }
        // syncToWatch is called per-detection inside acceptDetection;
        // send one final consolidated update after all are accepted.
        syncToWatch()
    }

    func deleteDetection(_ detection: AIDetection) {
        detections.removeAll { $0.id == detection.id }
    }

    // MARK: - Region management (implemented in Task 14)

    func addRegion(_ region: CountRegion) {
        regions.append(region)
        session.regions.append(region)
    }

    func updateRegion(_ region: CountRegion) {
        if let idx = regions.firstIndex(where: { $0.id == region.id }) {
            regions[idx] = region
        }
    }

    func deleteRegion(_ region: CountRegion) {
        regions.removeAll { $0.id == region.id }
        session.regions.removeAll { $0.id == region.id }
    }

    /// Per-region tally: count of markers per ObjectType whose normalized coordinates
    /// fall within the region boundary.
    ///
    /// Requirement 8.5, 8.6: region-specific tally.
    func tally(for region: CountRegion) -> [ObjectType: Int] {
        var tally: [ObjectType: Int] = [:]
        for marker in markers {
            let point = CGPoint(x: marker.normalizedX, y: marker.normalizedY)
            if region.contains(normalizedPoint: point) {
                tally[marker.objectType, default: 0] += 1
            }
        }
        return tally
    }
}

// MARK: - CGRect area helper

private extension CGRect {
    var area: CGFloat { width * height }
}
