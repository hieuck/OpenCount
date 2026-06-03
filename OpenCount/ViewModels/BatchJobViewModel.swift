import Foundation
import UIKit
import SwiftUI

// MARK: - BatchJobStatus

enum BatchJobStatus: Equatable, Codable {
    case idle
    case running(current: Int, total: Int)
    case completed
    case cancelled

    enum CodingKeys: String, CodingKey {
        case idle, running, completed, cancelled
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
    var error: AppError?
    var retryCount: Int = 0
}

// MARK: - BatchJobViewModel

/// Manages sequential AI processing of multiple images.
///
/// Requirements: 10.1, 10.2, 10.3, 10.4, 10.5, 10.6
@MainActor
final class BatchJobViewModel: ObservableObject {

    // MARK: - Published state

    @Published var results: [BatchImageResult] = []
    @Published var status: BatchJobStatus = .idle
    @Published var error: AppError?

    // MARK: - Private

    private let aiService = CoreMLAIService()
    private var isCancelled = false
    private var processingTask: Task<Void, Never>?

    // Persistence & configuration
    private let persistenceKey = "BatchJobViewModel.state"
    private let maxConcurrentTasks: Int = ProcessInfo.processInfo.activeProcessorCount > 4 ? 3 : 2
    private let maxRetries: Int = 3
    private var imageCache: [UUID: UIImage] = [:]

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

    // MARK: - Persistence

    /// Saves the current batch state to disk for recovery after interruption.
    func saveBatchState() {
        let state = (results: results, status: status)
        if let encoded = try? JSONEncoder().encode(state) {
            UserDefaults.standard.set(encoded, forKey: persistenceKey)
        }
    }

    /// Loads a previously saved batch state if available.
    func loadBatchState() {
        guard let encoded = UserDefaults.standard.data(forKey: persistenceKey),
              let state = try? JSONDecoder().decode((results: [BatchImageResult], status: BatchJobStatus).self, from: encoded) else {
            return
        }
        results = state.results
        status = state.status
    }

    /// Clears persisted batch state from disk.
    func clearBatchState() {
        UserDefaults.standard.removeObject(forKey: persistenceKey)
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
                error: nil
            )
        }
        results.append(contentsOf: newResults)
    }

    // MARK: - Start

    /// Starts sequential or parallel AI processing based on device capability.
    /// Requirement 10.2: run AI detection on each image with progress display.
    /// - Parameter confidenceThreshold: Detection confidence threshold (0.0-1.0)
    /// - Parameter useParallel: Enable concurrent processing on capable devices
    func startProcessing(confidenceThreshold: Float = 0.5, useParallel: Bool = true) {
        guard case .idle = status else { return }
        isCancelled = false
        saveBatchState()

        processingTask = Task {
            if useParallel && maxConcurrentTasks > 1 {
                await processParallel(confidenceThreshold: confidenceThreshold)
            } else {
                await processSequential(confidenceThreshold: confidenceThreshold)
            }

            if !isCancelled {
                status = .completed
                saveBatchState()
            }
            clearImageCache()
        }
    }

    /// Sequential processing fallback for older devices.
    private func processSequential(confidenceThreshold: Float) async {
        for (index, result) in results.enumerated() {
            guard !isCancelled else {
                status = .cancelled
                return
            }

            status = .running(current: index + 1, total: results.count)
            await processImage(at: index, confidenceThreshold: confidenceThreshold)
        }
    }

    /// Parallel processing using Task groups for capable devices.
    private func processParallel(confidenceThreshold: Float) async {
        let unprocessedIndices = results.enumerated()
            .filter { !$0.element.isProcessed }
            .map { $0.offset }

        await withTaskGroup(of: Int.self) { group in
            var activeCount = 0

            for (i, index) in unprocessedIndices.enumerated() {
                if isCancelled { break }

                // Add task to group
                group.addTask { [weak self] in
                    await self?.processImage(at: index, confidenceThreshold: confidenceThreshold)
                    return index
                }
                activeCount += 1

                // Limit concurrent tasks
                if activeCount >= maxConcurrentTasks {
                    _ = await group.next()
                    activeCount -= 1
                    self.updateRunningStatus()
                }
            }

            // Wait for remaining tasks
            for await _ in group {
                updateRunningStatus()
            }
        }
    }

    /// Processes a single image with retry logic and memory management.
    private func processImage(at index: Int, confidenceThreshold: Float) async {
        guard index < results.count else { return }

        var lastError: AppError?

        for attempt in 0..<maxRetries {
            guard !isCancelled else { return }

            // Load image
            guard let image = loadImage(for: results[index].sessionImage) else {
                results[index].isProcessed = true
                results[index].error = .imageFileMissing
                return
            }

            do {
                // Cache image for retry
                imageCache[results[index].id] = image

                let detections = try await aiService.detect(
                    in: image,
                    confidenceThreshold: confidenceThreshold
                )
                results[index].detections = detections
                results[index].isProcessed = true
                results[index].retryCount = attempt
                lastError = nil
                return

            } catch let appError as AppError {
                lastError = appError
                if attempt == maxRetries - 1 {
                    results[index].isProcessed = true
                    results[index].error = appError
                    results[index].retryCount = attempt + 1
                }
            } catch {
                lastError = .aiInferenceOutOfMemory
                if attempt == maxRetries - 1 {
                    results[index].isProcessed = true
                    results[index].error = .aiInferenceOutOfMemory
                    results[index].retryCount = attempt + 1
                }
            }

            // Brief delay before retry
            if attempt < maxRetries - 1 {
                try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
            }
        }
    }

    private func updateRunningStatus() {
        let processed = results.filter(\.isProcessed).count
        status = .running(current: processed, total: results.count)
    }

    // MARK: - Cancel

    /// Cancels the batch job, preserving already-processed results.
    /// Requirement 10.3: allow the user to cancel a Batch_Job at any time.
    func cancel() {
        isCancelled = true
        processingTask?.cancel()
        status = .cancelled
        saveBatchState()
        clearImageCache()
    }

    // MARK: - Reset

    func reset() {
        processingTask?.cancel()
        results = []
        status = .idle
        isCancelled = false
        clearImageCache()
        clearBatchState()
    }

    // MARK: - Memory Management

    /// Clears the image cache to free memory.
    private func clearImageCache() {
        imageCache.removeAll()
    }

    /// Retries all failed images in the batch.
    func retryFailedImages(confidenceThreshold: Float = 0.5) {
        let failedIndices = results.enumerated()
            .filter { $0.element.error != nil && !$0.element.isProcessed }
            .map { $0.offset }

        guard !failedIndices.isEmpty else { return }

        Task {
            for index in failedIndices {
                guard !isCancelled else { break }
                results[index].error = nil
                results[index].retryCount = 0
                await processImage(at: index, confidenceThreshold: confidenceThreshold)
            }
        }
    }

    // MARK: - Private helpers

    private func loadImage(for sessionImage: SessionImage) -> UIImage? {
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let fileURL = documentsURL
            .appendingPathComponent("images")
            .appendingPathComponent(sessionImage.filename)
        return UIImage(contentsOfFile: fileURL.path)
    }
}
