import Foundation
import UIKit
import Vision
import CoreML
import Combine

// MARK: - AIServiceProtocol

/// Protocol for the AI detection service.
/// Requirements: 5.1, 5.2, 5.3, 5.8, 5.9, 5.10, 5.11
protocol AIServiceProtocol: AnyObject {
    /// Progress of the current inference operation, in the range [0.0, 1.0].
    var aiProgress: Double { get }

    /// Runs object detection on the given image and returns all detections above the threshold.
    /// - Parameters:
    ///   - image: The source image to analyse.
    ///   - confidenceThreshold: Minimum confidence score for returned detections.
    /// - Returns: Array of `AIDetection` with normalized bounding boxes.
    func detect(in image: UIImage, confidenceThreshold: Float) async throws -> [AIDetection]

    /// Zero-shot counting: finds objects visually similar to the cropped sample region.
    /// Uses `VNFeaturePrintObservation` to compute feature vectors and ranks candidates.
    /// - Parameters:
    ///   - sample: Normalized bounding box of the sample object in `image`.
    ///   - image: The source image to search.
    /// - Returns: Array of `AIDetection` representing similar objects.
    func detectSimilar(to sample: CGRect, in image: UIImage) async throws -> [AIDetection]
}

// MARK: - ModelActor

/// Background actor that owns the CoreML model and serialises all inference work
/// off the main thread.
///
/// Requirements: 5.1, 5.9 — inference must not block the UI thread.
actor ModelActor {
    static let shared = ModelActor()

    // MARK: - CoreML detection

    /// Runs `VNCoreMLRequest` inference on the background actor.
    ///
    /// Requirements: 5.1, 5.3, 5.8, 5.9, 5.10, 5.11
    func runCoreMLDetection(
        cgImage: CGImage,
        model: VNCoreMLModel,
        confidenceThreshold: Float,
        progressHandler: @escaping (Double) -> Void
    ) throws -> [AIDetection] {

        var result: Result<[AIDetection], Error> = .success([])

        let request = VNCoreMLRequest(model: model) { req, error in
            if let error = error {
                let nsError = error as NSError
                if nsError.domain == VNErrorDomain,
                   nsError.code == VNError.outOfBoundsError.rawValue {
                    result = .failure(AppError.aiInferenceOutOfMemory)
                } else {
                    result = .failure(AppError.coreMLModelLoadFailure)
                }
                return
            }

            let observations = req.results as? [VNRecognizedObjectObservation] ?? []
            let detections = observations
                .filter { $0.confidence >= confidenceThreshold }
                .map { obs -> AIDetection in
                    // Vision bounding boxes have origin at bottom-left; flip Y for UIKit.
                    let flipped = CGRect(
                        x: obs.boundingBox.origin.x,
                        y: 1.0 - obs.boundingBox.origin.y - obs.boundingBox.height,
                        width: obs.boundingBox.width,
                        height: obs.boundingBox.height
                    )
                    let label = obs.labels.first?.identifier ?? "object"
                    return AIDetection(
                        normalizedBoundingBox: flipped,
                        label: label,
                        confidenceScore: obs.confidence
                    )
                }
            result = .success(detections)
        }

        // Progress handler — forwards updates to the caller.
        request.progressHandler = { _, progress, _ in
            progressHandler(progress)
        }

        request.imageCropAndScaleOption = .scaleFit

        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        do {
            try handler.perform([request])
        } catch {
            let nsError = error as NSError
            if nsError.domain == VNErrorDomain {
                throw AppError.aiInferenceOutOfMemory
            } else {
                throw AppError.coreMLModelLoadFailure
            }
        }

        return try result.get()
    }

    // MARK: - Similarity detection

    /// Zero-shot similarity detection using `VNFeaturePrintObservation`.
    ///
    /// Strategy:
    /// 1. Extract a feature print for the sample crop.
    /// 2. Tile the image into overlapping candidate windows.
    /// 3. Compute feature prints for each candidate.
    /// 4. Return candidates whose similarity to the sample exceeds the threshold.
    ///
    /// Requirements: 5.2, 5.8, 5.9
    func runSimilarityDetection(
        cgImage: CGImage,
        sampleRect: CGRect,
        progressHandler: @escaping (Double) -> Void
    ) throws -> [AIDetection] {

        let imageWidth = CGFloat(cgImage.width)
        let imageHeight = CGFloat(cgImage.height)

        // ── Step 1: Crop the sample region ──────────────────────────────────
        let samplePixelRect = CGRect(
            x: sampleRect.origin.x * imageWidth,
            y: sampleRect.origin.y * imageHeight,
            width: sampleRect.width * imageWidth,
            height: sampleRect.height * imageHeight
        ).integral

        guard let sampleCrop = cgImage.cropping(to: samplePixelRect) else {
            return []
        }

        // ── Step 2: Compute feature print for the sample ─────────────────────
        guard let sampleFeaturePrint = computeFeaturePrint(for: sampleCrop) else {
            return []
        }

        // ── Step 3: Generate candidate windows ───────────────────────────────
        let sampleAspect = sampleRect.width / max(sampleRect.height, 0.001)
        let candidates = generateCandidateWindows(
            sampleRect: sampleRect,
            aspectRatio: sampleAspect
        )

        // ── Step 4: Score each candidate ─────────────────────────────────────
        let similarityThreshold: Float = 0.85
        var detections: [AIDetection] = []
        let total = Double(candidates.count)

        for (index, candidateNorm) in candidates.enumerated() {
            progressHandler(Double(index + 1) / max(total, 1.0))

            let candidatePixelRect = CGRect(
                x: candidateNorm.origin.x * imageWidth,
                y: candidateNorm.origin.y * imageHeight,
                width: candidateNorm.width * imageWidth,
                height: candidateNorm.height * imageHeight
            ).integral

            guard let candidateCrop = cgImage.cropping(to: candidatePixelRect),
                  let candidateFeaturePrint = computeFeaturePrint(for: candidateCrop) else {
                continue
            }

            var distance: Float = 0
            do {
                try sampleFeaturePrint.computeDistance(&distance, to: candidateFeaturePrint)
            } catch {
                continue
            }

            // VNFeaturePrintObservation distance: 0 = identical, higher = more different.
            let similarity = max(0.0, 1.0 - distance)
            guard similarity >= similarityThreshold else { continue }

            // Skip the sample window itself (near-perfect overlap).
            let overlap = candidateNorm.intersection(sampleRect)
            let unionArea = candidateNorm.width * candidateNorm.height
                          + sampleRect.width * sampleRect.height
                          - overlap.width * overlap.height
            let iou = (overlap.width * overlap.height) / max(unionArea, 0.0001)
            if iou > 0.9 { continue }

            detections.append(AIDetection(
                normalizedBoundingBox: candidateNorm,
                label: "similar object",
                confidenceScore: similarity
            ))
        }

        progressHandler(1.0)
        return detections
    }

    // MARK: - Private helpers

    /// Computes a `VNFeaturePrintObservation` for the given CGImage.
    private func computeFeaturePrint(for cgImage: CGImage) -> VNFeaturePrintObservation? {
        let request = VNGenerateImageFeaturePrintRequest()
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        do {
            try handler.perform([request])
            return request.results?.first as? VNFeaturePrintObservation
        } catch {
            return nil
        }
    }

    /// Generates normalized candidate windows that tile the image,
    /// sized proportionally to the sample region with 50% overlap.
    private func generateCandidateWindows(
        sampleRect: CGRect,
        aspectRatio: CGFloat
    ) -> [CGRect] {
        var windows: [CGRect] = []

        let winW = min(max(sampleRect.width, 0.05), 0.5)
        let winH = min(max(sampleRect.height, 0.05), 0.5)
        let strideX = winW * 0.5
        let strideY = winH * 0.5

        var y: CGFloat = 0
        while y < 1.0 {
            var x: CGFloat = 0
            while x < 1.0 {
                let clampedX = min(x, 1.0 - winW)
                let clampedY = min(y, 1.0 - winH)
                windows.append(CGRect(x: clampedX, y: clampedY, width: winW, height: winH))
                x += strideX
                if x >= 1.0 { break }
            }
            y += strideY
            if y >= 1.0 { break }
        }

        return windows
    }
}

// MARK: - CoreMLAIService

/// Concrete AI service backed by a YOLOv8-nano CoreML model.
///
/// When the real `YOLOv8n.mlpackage` is not present in the bundle (e.g. during
/// development or CI), the service falls back to a mock implementation that
/// returns plausible synthetic detections so the rest of the app can compile
/// and run without the model file.
///
/// Requirements: 5.1, 5.2, 5.3, 5.8, 5.9, 5.10, 5.11
@MainActor
final class CoreMLAIService: ObservableObject, AIServiceProtocol {

    // MARK: - Published

    /// Progress of the current inference pass, updated via the VNRequest progress handler.
    /// Requirement 5.10: display a progress indicator during AI inference.
    @Published var aiProgress: Double = 0.0

    // MARK: - Private

    /// The loaded Vision CoreML model, or nil when the bundle model is absent.
    private var visionModel: VNCoreMLModel?

    /// Whether the real model was successfully loaded.
    private var isModelLoaded: Bool { visionModel != nil }

    // MARK: - Init

    init() {
        visionModel = Self.loadModel()
        if visionModel == nil {
            print("[CoreMLAIService] Running in mock mode — YOLOv8n.mlpackage not found in bundle.")
        }
    }

    // MARK: - Model loading

    /// Attempts to load `YOLOv8n.mlpackage` (or its compiled `.mlmodelc`) from the main bundle.
    /// Returns `nil` gracefully when the file is not present, enabling mock mode.
    private static func loadModel() -> VNCoreMLModel? {
        guard let modelURL = Bundle.main.url(forResource: "YOLOv8n", withExtension: "mlmodelc")
                ?? Bundle.main.url(forResource: "YOLOv8n", withExtension: "mlpackage") else {
            return nil
        }

        do {
            let mlModel = try MLModel(contentsOf: modelURL)
            return try VNCoreMLModel(for: mlModel)
        } catch {
            print("[CoreMLAIService] Model load failed: \(error.localizedDescription)")
            return nil
        }
    }

    // MARK: - AIServiceProtocol: detect

    /// Runs object detection on `image` and returns detections above `confidenceThreshold`.
    ///
    /// When the real model is loaded, this uses `VNCoreMLRequest` on the `ModelActor`.
    /// When the model is absent, it returns synthetic mock detections for development.
    ///
    /// Requirements: 5.1, 5.3, 5.8, 5.9, 5.10, 5.11
    func detect(in image: UIImage, confidenceThreshold: Float) async throws -> [AIDetection] {
        guard let cgImage = image.cgImage else {
            throw AppError.aiInferenceOutOfMemory
        }

        aiProgress = 0.0

        if let model = visionModel {
            return try await ModelActor.shared.runCoreMLDetection(
                cgImage: cgImage,
                model: model,
                confidenceThreshold: confidenceThreshold,
                progressHandler: { [weak self] progress in
                    Task { @MainActor in
                        self?.aiProgress = progress
                    }
                }
            )
        } else {
            return await runMockDetection(cgImage: cgImage,
                                          confidenceThreshold: confidenceThreshold)
        }
    }

    // MARK: - AIServiceProtocol: detectSimilar

    /// Zero-shot counting via visual feature matching.
    ///
    /// Requirements: 5.2, 5.8, 5.9
    func detectSimilar(to sample: CGRect, in image: UIImage) async throws -> [AIDetection] {
        guard let cgImage = image.cgImage else {
            throw AppError.aiInferenceOutOfMemory
        }

        aiProgress = 0.0

        return try await ModelActor.shared.runSimilarityDetection(
            cgImage: cgImage,
            sampleRect: sample,
            progressHandler: { [weak self] progress in
                Task { @MainActor in
                    self?.aiProgress = progress
                }
            }
        )
    }

    // MARK: - Mock detection (no model bundled)

    /// Returns synthetic detections for development/testing when the real model is absent.
    private func runMockDetection(cgImage: CGImage,
                                  confidenceThreshold: Float) async -> [AIDetection] {
        let mockLabels = ["person", "car", "dog", "bicycle", "chair",
                          "bottle", "cup", "laptop", "phone", "book"]
        var detections: [AIDetection] = []

        let cols = 3
        let rows = 3
        let cellW = 1.0 / Double(cols)
        let cellH = 1.0 / Double(rows)

        for row in 0..<rows {
            for col in 0..<cols {
                // Simulate progress.
                let step = row * cols + col + 1
                let total = rows * cols
                aiProgress = Double(step) / Double(total)

                try? await Task.sleep(nanoseconds: 30_000_000) // 30 ms per cell

                let confidence = Float.random(in: 0.4...0.98)
                guard confidence >= confidenceThreshold else { continue }

                let x = Double(col) * cellW + cellW * 0.1
                let y = Double(row) * cellH + cellH * 0.1
                let w = cellW * 0.8
                let h = cellH * 0.8

                let label = mockLabels[(row * cols + col) % mockLabels.count]
                detections.append(AIDetection(
                    normalizedBoundingBox: CGRect(x: x, y: y, width: w, height: h),
                    label: label,
                    confidenceScore: confidence
                ))
            }
        }

        aiProgress = 1.0
        return detections
    }
}
