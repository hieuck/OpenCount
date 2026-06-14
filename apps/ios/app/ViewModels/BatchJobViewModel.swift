import Foundation
import UIKit
import SwiftUI

// MARK: - BatchJobStatus

enum BatchJobStatus: Equatable, Codable {
    case idle
    case running(current: Int, total: Int)
    case paused(current: Int, total: Int)
    case completed
    case cancelled

    enum CodingKeys: String, CodingKey {
        case idle, running, paused, completed, cancelled
        case current, total
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .idle:
            try container.encode(true, forKey: .idle)
        case let .running(current, total):
            var nested = container.nestedContainer(keyedBy: CodingKeys.self, forKey: .running)
            try nested.encode(current, forKey: .current)
            try nested.encode(total, forKey: .total)
        case let .paused(current, total):
            var nested = container.nestedContainer(keyedBy: CodingKeys.self, forKey: .paused)
            try nested.encode(current, forKey: .current)
            try nested.encode(total, forKey: .total)
        case .completed:
            try container.encode(true, forKey: .completed)
        case .cancelled:
            try container.encode(true, forKey: .cancelled)
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if container.contains(.idle) {
            self = .idle
        } else if container.contains(.running) {
            let nested = try container.nestedContainer(keyedBy: CodingKeys.self, forKey: .running)
            let current = try nested.decode(Int.self, forKey: .current)
            let total = try nested.decode(Int.self, forKey: .total)
            self = .running(current: current, total: total)
        } else if container.contains(.paused) {
            let nested = try container.nestedContainer(keyedBy: CodingKeys.self, forKey: .paused)
            let current = try nested.decode(Int.self, forKey: .current)
            let total = try nested.decode(Int.self, forKey: .total)
            self = .paused(current: current, total: total)
        } else if container.contains(.completed) {
            self = .completed
        } else if container.contains(.cancelled) {
            self = .cancelled
        } else {
            self = .idle
        }
    }
}

// MARK: - BatchImageResult

struct BatchImageResult: Identifiable, Codable {
    let id: UUID
    let sessionImage: SessionImage
    var detections: [AIDetection]
    var isProcessed: Bool
    var errorDescription: String?     // AppError can't be Codable due to associated values
    var retryCount: Int = 0
    var processedAt: Date?

    // Computed property for backwards compatibility
    var hasError: Bool { errorDescription != nil }
}

// MARK: - BatchJobViewModel

/// Manages efficient batch AI processing of multiple images with progress persistence.
///
/// Features:
/// - Optimized parallel batch inference with configurable concurrency
/// - Progress persistence for interrupted batch recovery
/// - Pause/resume capability with state reconstruction
/// - Batch-level cancellation with partial result preservation
/// - Memory-efficient image caching with automatic cleanup
///
/// Requirements: 10.1, 10.2, 10.3, 10.4, 10.5, 10.6
@MainActor
final class BatchJobViewModel: ObservableObject {

    // MARK: - Published state

    @Published var results: [BatchImageResult] = []
    @Published var status: BatchJobStatus = .idle
    @Published var error: AppError?
    @Published var estimatedTimeRemaining: TimeInterval = 0

    // MARK: - Private state

    private let aiService = CoreMLAIService()
    private var isCancelled = false
    private var isPaused = false
    private var processingTask: Task<Void, Never>?
    private var batchStartTime: Date?
    private var processedCountAtBatchStart: Int = 0

    // Persistence & configuration
    private let persistenceKey = "BatchJobViewModel.state"
    private let timeEstimateKey = "BatchJobViewModel.timeEstimate"
    private let maxConcurrentTasks: Int
    private let maxRetries: Int = 3
    private let batchSize: Int = 10
    private var imageCache: [UUID: UIImage] = [:]
    private var imageCacheOrder: [UUID] = []
    private let maxCacheSize: Int = 50

    // MARK: - Init

    init() {
        let processorCount = ProcessInfo.processInfo.activeProcessorCount
        self.maxConcurrentTasks = processorCount > 4 ? 4 : (processorCount > 2 ? 2 : 1)
    }

    // MARK: - Computed

    /// Aggregated tally across all processed images, per label.
    var aggregatedTally: [String: Int] {
        var tally: [String: Int] = [:]
        for result in results where result.isProcessed {
            for detection in result.detections {
                tally[detection.label, default: 0] += 1
            }
        }
        return tally
    }

    var processedCount: Int {
        results.filter(\.isProcessed).count
    }

    var totalCount: Int {
        results.count
    }

    var canResume: Bool {
        if case let .paused(current, total) = status, current < total {
            return true
        }
        return false
    }

    var canCancel: Bool {
        if case .running = status {
            return true
        }
        if case .paused = status {
            return true
        }
        return false
    }

    // MARK: - Persistence

    /// Codable container for batch state persistence.
    private struct BatchState: Codable {
        var results: [BatchImageResult]
        var status: BatchJobStatus
    }

    /// Saves the current batch state including progress and results.
    func saveBatchState() {
        let state = BatchState(results: results, status: status)
        if let encoded = try? JSONEncoder().encode(state) {
            UserDefaults.standard.set(encoded, forKey: persistenceKey)
            UserDefaults.standard.set(Date(), forKey: "\(persistenceKey).timestamp")
        }
    }

    /// Loads a previously saved batch state if available (within 24 hours).
    func loadBatchState() {
        guard let timestamp = UserDefaults.standard.object(forKey: "\(persistenceKey).timestamp") as? Date,
              Date().timeIntervalSince(timestamp) < 86400 else {
            clearBatchState()
            return
        }

        guard let encoded = UserDefaults.standard.data(forKey: persistenceKey),
              let state = try? JSONDecoder().decode(BatchState.self, from: encoded) else {
            return
        }
        results = state.results
        status = state.status
    }

    /// Clears persisted batch state.
    func clearBatchState() {
        UserDefaults.standard.removeObject(forKey: persistenceKey)
        UserDefaults.standard.removeObject(forKey: "\(persistenceKey).timestamp")
        UserDefaults.standard.removeObject(forKey: timeEstimateKey)
    }

    /// Adds session images to the batch queue.
    /// Requirement 10.1: select multiple images and add them to a Batch_Job.
    func addImages(_ images: [SessionImage]) {
        let newResults = images.map { img in
            BatchImageResult(
                id: UUID(),
                sessionImage: img,
                detections: [],
                isProcessed: false,
                errorDescription: nil,
                retryCount: 0,
                processedAt: nil
            )
        }
        results.append(contentsOf: newResults)
        saveBatchState()
    }

    // MARK: - Start Processing

    /// Starts batch processing with optimized parallel inference.
    /// Requirement 10.2: run AI detection on each image with progress display.
    func startProcessing(confidenceThreshold: Float = 0.5) {
        guard case .idle = status else { return }
        isCancelled = false
        isPaused = false
        batchStartTime = Date()
        processedCountAtBatchStart = processedCount

        processingTask = Task {
            await processBatchOptimized(confidenceThreshold: confidenceThreshold)

            if !isCancelled {
                status = .completed
                saveBatchState()
            }
            clearImageCache()
        }
    }

    /// Resumes processing from a paused state.
    func resume(confidenceThreshold: Float = 0.5) {
        guard case let .paused(_, total) = status, processedCount < total else { return }
        isPaused = false
        isCancelled = false
        batchStartTime = Date()
        processedCountAtBatchStart = processedCount

        processingTask = Task {
            await processBatchOptimized(confidenceThreshold: confidenceThreshold)

            if !isCancelled {
                status = .completed
                saveBatchState()
            }
            clearImageCache()
        }
    }

    // MARK: - Optimized Batch Processing

    /// Processes images in optimized batches with memory and concurrency management.
    private func processBatchOptimized(confidenceThreshold: Float) async {
        let unprocessedIndices = results.enumerated()
            .filter { !$0.element.isProcessed }
            .map { $0.offset }

        guard !unprocessedIndices.isEmpty else {
            status = .completed
            return
        }

        // Process in batches to optimize memory and I/O
        let batches = stride(from: 0, to: unprocessedIndices.count, by: batchSize)
            .map { start in
                Array(unprocessedIndices[start..<min(start + batchSize, unprocessedIndices.count)])
            }

        for (batchIndex, batch) in batches.enumerated() {
            guard !isCancelled else {
                status = .cancelled
                saveBatchState()
                return
            }

            // Check pause state
            while isPaused {
                updatePausedStatus()
                saveBatchState()
                try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
            }

            await processBatch(batch, confidenceThreshold: confidenceThreshold)
            updateEstimatedTimeRemaining(totalProcessed: processedCount, totalCount: totalCount)

            // Clear cache between batches
            if batchIndex % 3 == 0 {
                pruneImageCache()
            }
        }
    }

    /// Processes a single batch of images with concurrent task management.
    private func processBatch(_ indices: [Int], confidenceThreshold: Float) async {
        await withTaskGroup(of: Void.self) { group in
            var activeCount = 0

            for index in indices {
                if isCancelled { break }

                group.addTask { [weak self] in
                    await self?.processImage(at: index, confidenceThreshold: confidenceThreshold)
                }
                activeCount += 1

                if activeCount >= maxConcurrentTasks {
                    _ = await group.next()
                    activeCount -= 1
                    updateRunningStatus()
                }
            }

            for await _ in group {
                updateRunningStatus()
            }
        }
    }

    /// Processes a single image with retry logic and memory management.
    private func processImage(at index: Int, confidenceThreshold: Float) async {
        guard index < results.count, !results[index].isProcessed else { return }

        for attempt in 0..<maxRetries {
            guard !isCancelled else { return }

            guard let image = loadImage(for: results[index].sessionImage) else {
                results[index].isProcessed = true
                results[index].errorDescription = AppError.imageFileMissing.localizedDescription
                results[index].processedAt = Date()
                return
            }

            do {
                cacheImage(image, for: results[index].id)

                let detections = try await aiService.detect(
                    in: image,
                    confidenceThreshold: confidenceThreshold
                )
                results[index].detections = detections
                results[index].isProcessed = true
                results[index].retryCount = attempt
                results[index].processedAt = Date()
                return

            } catch let appError as AppError {
                if attempt == maxRetries - 1 {
                    results[index].isProcessed = true
                    results[index].errorDescription = appError.localizedDescription
                    results[index].retryCount = attempt + 1
                    results[index].processedAt = Date()
                }
            } catch {
                if attempt == maxRetries - 1 {
                    results[index].isProcessed = true
                    results[index].errorDescription = AppError.aiInferenceOutOfMemory.localizedDescription
                    results[index].retryCount = attempt + 1
                    results[index].processedAt = Date()
                }
            }

            if attempt < maxRetries - 1 {
                try? await Task.sleep(nanoseconds: 500_000_000)
            }
        }
    }

    // MARK: - Pause/Cancel/Resume

    /// Pauses the batch job, preserving state for later resume.
    func pause() {
        guard case let .running(current, total) = status else { return }
        isPaused = true
        status = .paused(current: current, total: total)
        saveBatchState()
    }

    /// Cancels the batch job entirely.
    /// Requirement 10.3: allow the user to cancel a Batch_Job at any time.
    func cancel() {
        isCancelled = true
        isPaused = false
        processingTask?.cancel()
        status = .cancelled
        saveBatchState()
        clearImageCache()
    }

    /// Resets the batch job to initial state.
    func reset() {
        processingTask?.cancel()
        results = []
        status = .idle
        isCancelled = false
        isPaused = false
        batchStartTime = nil
        processedCountAtBatchStart = 0
        clearImageCache()
        clearBatchState()
    }

    // MARK: - Status Updates

    private func updateRunningStatus() {
        let processed = processedCount
        status = .running(current: processed, total: totalCount)
    }

    private func updatePausedStatus() {
        let processed = processedCount
        status = .paused(current: processed, total: totalCount)
    }

    private func updateEstimatedTimeRemaining(totalProcessed: Int, totalCount: Int) {
        guard let startTime = batchStartTime, totalProcessed > processedCountAtBatchStart else {
            estimatedTimeRemaining = 0
            return
        }

        let elapsed = Date().timeIntervalSince(startTime)
        let processedInBatch = totalProcessed - processedCountAtBatchStart
        guard processedInBatch > 0 else { return }

        let avgTimePerImage = elapsed / Double(processedInBatch)
        let remaining = totalCount - totalProcessed
        estimatedTimeRemaining = avgTimePerImage * Double(remaining)

        UserDefaults.standard.set(estimatedTimeRemaining, forKey: timeEstimateKey)
    }

    // MARK: - Retry

    /// Retries all failed images in the batch.
    func retryFailedImages(confidenceThreshold: Float = 0.5) {
        let failedIndices = results.enumerated()
            .filter { $0.element.hasError && $0.element.isProcessed }
            .map { $0.offset }

        guard !failedIndices.isEmpty else { return }

        Task {
            for index in failedIndices {
                guard !isCancelled else { break }
                results[index].errorDescription = nil
                results[index].isProcessed = false
                results[index].retryCount = 0
                results[index].processedAt = nil
                await processImage(at: index, confidenceThreshold: confidenceThreshold)
            }
            saveBatchState()
        }
    }

    // MARK: - Memory Management

    /// Loads image with memory efficiency.
    private func loadImage(for sessionImage: SessionImage) -> UIImage? {
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let fileURL = documentsURL
            .appendingPathComponent("images")
            .appendingPathComponent(sessionImage.filename)
        return UIImage(contentsOfFile: fileURL.path)
    }

    /// Caches image with LRU eviction policy.
    private func cacheImage(_ image: UIImage, for id: UUID) {
        if imageCache.count >= maxCacheSize {
            if let oldestId = imageCacheOrder.first {
                imageCache.removeValue(forKey: oldestId)
                imageCacheOrder.removeFirst()
            }
        }
        imageCache[id] = image
        imageCacheOrder.append(id)
    }

    /// Prunes image cache to reclaim memory.
    private func pruneImageCache() {
        let targetSize = maxCacheSize / 2
        while imageCache.count > targetSize {
            if let oldestId = imageCacheOrder.first {
                imageCache.removeValue(forKey: oldestId)
                imageCacheOrder.removeFirst()
            }
        }
    }

    /// Clears the entire image cache.
    private func clearImageCache() {
        imageCache.removeAll()
        imageCacheOrder.removeAll()
    }
}
