import Foundation
import SwiftUI
import UIKit
import Combine
import PhotosUI
import UniformTypeIdentifiers

// MARK: - Image Cache Manager

/// Lightweight in-memory cache for session images with automatic eviction.
final class ImageCacheManager {
    private var cache: [String: UIImage] = [:]
    private let maxBytes: Int = 50 * 1024 * 1024 // 50 MB
    private var currentBytes: Int = 0
    private let lock = NSLock()

    func set(_ image: UIImage, for key: String) {
        lock.lock()
        defer { lock.unlock() }

        let estimatedBytes = Int(image.size.width * image.size.height * 4)

        // Evict oldest entries if needed
        while currentBytes + estimatedBytes > maxBytes && !cache.isEmpty {
            if let firstKey = cache.keys.first {
                let removed = cache.removeValue(forKey: firstKey)
                currentBytes -= Int(removed?.size.width ?? 0) * Int(removed?.size.height ?? 0) * 4
            }
        }

        if let existing = cache[key] {
            currentBytes -= Int(existing.size.width * existing.size.height * 4)
        }

        cache[key] = image
        currentBytes += estimatedBytes
    }

    func get(_ key: String) -> UIImage? {
        lock.lock()
        defer { lock.unlock() }
        return cache[key]
    }

    func remove(_ key: String) {
        lock.lock()
        defer { lock.unlock() }
        if let image = cache.removeValue(forKey: key) {
            currentBytes -= Int(image.size.width * image.size.height * 4)
        }
    }

    func clearAll() {
        lock.lock()
        defer { lock.unlock() }
        cache.removeAll()
        currentBytes = 0
    }
}

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
            completedCells = []
        }
    }
    @Published var completedCells: Set<Int> = []
    @Published var isAIRunning: Bool = false
    @Published var aiProgress: Double = 0.0
    @Published var error: AppError?

    // MARK: - Computed: tallies

    var globalTally: [ObjectType: Int] {
        var tally: [ObjectType: Int] = [:]
        for marker in markers {
            tally[marker.objectType, default: 0] += 1
        }
        return tally
    }

    var filteredDetections: [AIDetection] {
        detections.filter { $0.confidenceScore >= confidenceThreshold }
    }

    // MARK: - Private: memory management

    private var undoStack = UndoStack<[CountMarker]>(capacity: 50)
    private let haptic = UIImpactFeedbackGenerator(style: .medium)
    private let imageCache = ImageCacheManager()
    private var aiService: CoreMLAIService?
    private var velocityTracker = CountingVelocityTracker()
    private weak var watchService: WatchConnectivityService? = WatchConnectivityService.shared
    private weak var collaborationService: CollaborationService? = CollaborationService.shared
    private var memoryWarningObserver: NSObjectProtocol?
    private var detectionCleanupTimer: Timer?

    // MARK: - Collaboration state

    @Published var isCollaborating: Bool = false

    // MARK: - Smart count state

    @Published var isDuplicateWarningActive: Bool = false
    @Published var pendingDuplicatePoint: CGPoint?
    @Published var isFatigueWarningActive: Bool = false
    @Published var missedObjectCandidates: [AIDetection] = []
    @Published var isFindingMissedObjects: Bool = false

    // MARK: - Count target state (Requirement 53 / Req 42)

    @Published var completedObjectTypes: Set<UUID> = []
    @Published var shouldFireConfetti: Bool = false

    // MARK: - Init

    init(session: CountSession) {
        self.session = session
        self.markers = session.markers
        self.regions = session.regions
        self.selectedObjectType = session.objectTypes.sorted { $0.sortOrder < $1.sortOrder }.first
        haptic.prepare()

        setupMemoryWarningObserver()
        setupDetectionCleanupTimer()

        if let watchService = watchService {
            watchService.onCountIncrement = { [weak self] objectTypeID, sessionID in
                Task { @MainActor in
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
            }
            watchService.sendSessionUpdate(session)
        }

        loadCurrentImage()
    }

    deinit {
        cleanup()
    }

    // MARK: - Memory management

    private func setupMemoryWarningObserver() {
        memoryWarningObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleMemoryWarning()
        }
    }

    private func setupDetectionCleanupTimer() {
        detectionCleanupTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            self?.cleanupOldDetections()
        }
    }

    private func handleMemoryWarning() {
        imageCache.clearAll()
        currentImage = nil
        detections.removeAll()
        missedObjectCandidates.removeAll()
        aiService = nil
    }

    private func cleanupOldDetections() {
        let maxDetections = 500
        if detections.count > maxDetections {
            let toRemove = detections.count - maxDetections
            detections.removeFirst(toRemove)
        }
    }

    private func cleanup() {
        if let observer = memoryWarningObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        detectionCleanupTimer?.invalidate()
        imageCache.clearAll()
        aiService = nil
    }

    // MARK: - Watch sync helper

    private func syncToWatch() {
        watchService?.sendSessionUpdate(session)
    }

    // MARK: - Manual counting

    func placeMarker(at normalizedPoint: CGPoint) {
        guard let objectType = selectedObjectType else { return }

        let smartCountService = SmartCountService()
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

    func confirmPendingMarker() {
        guard let point = pendingDuplicatePoint,
              let objectType = selectedObjectType else { return }
        pendingDuplicatePoint = nil
        isDuplicateWarningActive = false
        commitMarker(at: point, objectType: objectType)
    }

    func cancelPendingMarker() {
        pendingDuplicatePoint = nil
        isDuplicateWarningActive = false
    }

    private func commitMarker(at normalizedPoint: CGPoint, objectType: ObjectType) {
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

        let historyEntry = TallyHistoryEntry(
            timestamp: Date(),
            objectTypeName: objectType.name,
            delta: 1
        )
        session.tallyHistory.append(historyEntry)

        CrashRecoveryService.saveRecovery(session: session)
        haptic.impactOccurred()

        velocityTracker.recordPlacement()
        isFatigueWarningActive = velocityTracker.updateFatigueState()

        if let target = objectType.targetCount, target > 0 {
            let newCount = markers.filter { $0.objectType.id == objectType.id }.count
            if newCount >= target && !completedObjectTypes.contains(objectType.id) {
                completedObjectTypes.insert(objectType.id)
                shouldFireConfetti = true
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 500_000_000)
                    shouldFireConfetti = false
                }
            }
        }

        syncToWatch()

        if isCollaborating {
            let capturedMarker = marker
            let capturedSessionID = session.id
            Task {
                await self.collaborationService?.pushMarker(capturedMarker, sessionID: capturedSessionID)
            }
        }
    }

    func dismissFatigueWarning() {
        isFatigueWarningActive = false
    }

    // MARK: - Find Missed Objects

    func findMissedObjects(in image: UIImage, aiService: AIServiceProtocol) async {
        isFindingMissedObjects = true
        defer { isFindingMissedObjects = false }
        do {
            let smartCountService = SmartCountService()
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

    func acceptMissedCandidate(_ detection: AIDetection) {
        guard let objectType = selectedObjectType else { return }
        let centroid = detection.normalizedCentroid
        commitMarker(at: centroid, objectType: objectType)
        missedObjectCandidates.removeAll { $0.id == detection.id }
    }

    func dismissMissedCandidate(_ detection: AIDetection) {
        missedObjectCandidates.removeAll { $0.id == detection.id }
    }

    func removeMarker(_ marker: CountMarker) {
        undoStack.push(markers)
        markers.removeAll { $0.id == marker.id }
        session.markers.removeAll { $0.id == marker.id }
        session.modifiedAt = Date()

        let historyEntry = TallyHistoryEntry(
            timestamp: Date(),
            objectTypeName: marker.objectType.name,
            delta: -1
        )
        session.tallyHistory.append(historyEntry)

        CrashRecoveryService.saveRecovery(session: session)
        syncToWatch()
    }

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

    func undo() {
        guard let previous = undoStack.undo(currentState: markers) else { return }
        markers = previous
        session.markers = previous
        session.modifiedAt = Date()
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        syncToWatch()
    }

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

    func toggleCell(_ index: Int) {
        if completedCells.contains(index) {
            completedCells.remove(index)
        } else {
            completedCells.insert(index)
        }
    }

    var totalCells: Int {
        let d = gridDensity.clamped(to: 2...20)
        return d * d
    }

    var completedCellCount: Int {
        completedCells.count
    }

    // MARK: - Image import

    func importImage(_ image: UIImage, session: CountSession) async {
        let imagesDir = FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("images")
            .appendingPathComponent(session.id.uuidString)

        try? FileManager.default.createDirectory(at: imagesDir,
                                                  withIntermediateDirectories: true)

        let filename = "\(UUID().uuidString).jpg"
        let fileURL = imagesDir.appendingPathComponent(filename)

        if let data = image.jpegData(compressionQuality: 0.85) {
            try? data.write(to: fileURL)
        }

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

        currentImage = image
        imageCache.set(image, for: filename)
    }

    func loadCurrentImage() {
        guard let sessionImage = session.images.sorted(by: { $0.importedAt > $1.importedAt }).first else {
            return
        }

        if let cached = imageCache.get(sessionImage.filename) {
            currentImage = cached
            return
        }

        let imagesDir = FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("images")
            .appendingPathComponent(session.id.uuidString)
        let fileURL = imagesDir.appendingPathComponent(sessionImage.filename)
        if let image = UIImage(contentsOfFile: fileURL.path) {
            currentImage = image
            imageCache.set(image, for: sessionImage.filename)
        }
    }

    // MARK: - Current image

    @Published var currentImage: UIImage?
    @Published var currentImageIndex: Int = 0

    func selectImage(at index: Int, session: CountSession) {
        let sorted = session.images.sorted { $0.importedAt < $1.importedAt }
        guard sorted.indices.contains(index) else { return }
        let sessionImage = sorted[index]

        if let cached = imageCache.get(sessionImage.filename) {
            currentImage = cached
            currentImageIndex = index
            return
        }

        let imagesDir = FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("images")
            .appendingPathComponent(session.id.uuidString)
        let fileURL = imagesDir.appendingPathComponent(sessionImage.filename)
        if let image = UIImage(contentsOfFile: fileURL.path) {
            currentImage = image
            currentImageIndex = index
            imageCache.set(image, for: sessionImage.filename)
        }
    }

    // MARK: - AI counting

    func runAIDetection(on image: UIImage) async throws {
        guard !isAIRunning else { return }
        isAIRunning = true
        aiProgress = 0.0
        defer {
            isAIRunning = false
            aiProgress = 1.0
        }

        if aiService == nil {
            aiService = CoreMLAIService()
        }
        guard let aiService = aiService else { throw NSError(domain: "AIService", code: -1) }

        let results = try await aiService.detect(
            in: image,
            confidenceThreshold: confidenceThreshold
        )

        let newDetections = results.filter { newDet in
            !detections.contains { existing in
                existing.normalizedBoundingBox.intersection(newDet.normalizedBoundingBox).area
                    / max(newDet.normalizedBoundingBox.area, 0.0001) > 0.5
            }
        }
        detections.append(contentsOf: newDetections)
        cleanupOldDetections()
    }

    func runSimilarityDetection(sampleRect: CGRect, in image: UIImage) async throws {
        guard !isAIRunning else { return }
        isAIRunning = true
        aiProgress = 0.0
        defer {
            isAIRunning = false
            aiProgress = 1.0
        }

        if aiService == nil {
            aiService = CoreMLAIService()
        }
        guard let aiService = aiService else { throw NSError(domain: "AIService", code: -1) }

        let results = try await aiService.detectSimilar(to: sampleRect, in: image)
        detections.append(contentsOf: results)
        cleanupOldDetections()
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
        syncToWatch()
    }

    func deleteDetection(_ detection: AIDetection) {
        detections.removeAll { $0.id == detection.id }
    }

    // MARK: - Region management

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
