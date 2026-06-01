import Foundation
import UIKit
import SwiftUI

// MARK: - BatchJobStatus

enum BatchJobStatus: Equatable {
    case idle
    case running(current: Int, total: Int)
    case completed
    case cancelled
}

// MARK: - BatchImageResult

struct BatchImageResult: Identifiable {
    let id: UUID
    let sessionImage: SessionImage
    var detections: [AIDetection]
    var isProcessed: Bool
    var error: AppError?
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

    // MARK: - Setup

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

    /// Starts sequential AI processing of all queued images.
    /// Requirement 10.2: run AI detection on each image sequentially with progress display.
    func startProcessing(confidenceThreshold: Float = 0.5) {
        guard case .idle = status else { return }
        isCancelled = false

        processingTask = Task {
            for (index, result) in results.enumerated() {
                guard !isCancelled else {
                    status = .cancelled
                    return
                }

                status = .running(current: index + 1, total: results.count)

                // Load image from disk
                guard let image = loadImage(for: result.sessionImage) else {
                    results[index].isProcessed = true
                    results[index].error = .imageFileMissing
                    continue
                }

                do {
                    let detections = try await aiService.detect(
                        in: image,
                        confidenceThreshold: confidenceThreshold
                    )
                    results[index].detections = detections
                    results[index].isProcessed = true
                } catch let appError as AppError {
                    results[index].isProcessed = true
                    results[index].error = appError
                } catch {
                    results[index].isProcessed = true
                    results[index].error = .aiInferenceOutOfMemory
                }
            }

            if !isCancelled {
                status = .completed
            }
        }
    }

    // MARK: - Cancel

    /// Cancels the batch job, preserving already-processed results.
    /// Requirement 10.3: allow the user to cancel a Batch_Job at any time.
    func cancel() {
        isCancelled = true
        processingTask?.cancel()
        status = .cancelled
    }

    // MARK: - Reset

    func reset() {
        processingTask?.cancel()
        results = []
        status = .idle
        isCancelled = false
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
