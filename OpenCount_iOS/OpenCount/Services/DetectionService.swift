import UIKit
import Vision
import CoreML

/// Service xử lý object detection sử dụng Core ML + Vision framework.
/// Mặc định dùng YOLOv3, có thể cấu hình model khác qua `modelName`.
final class DetectionService {

    // MARK: - Errors
    enum DetectionError: LocalizedError {
        case modelNotFound(name: String)
        case modelLoadFailed(name: String, reason: String)
        case imageProcessingFailed
        case noResults

        var errorDescription: String? {
            switch self {
            case .modelNotFound(let name):
                return "Không tìm thấy model \"\(name)\". Vui lòng xem hướng dẫn trong README."
            case .modelLoadFailed(let name, let reason):
                return "Không thể tải model \(name): \(reason)"
            case .imageProcessingFailed:
                return "Không thể xử lý ảnh. Vui lòng thử ảnh khác."
            case .noResults:
                return "AI không phát hiện vật thể nào. Thử ảnh khác hoặc điều chỉnh độ nhạy."
            }
        }
    }

    // MARK: - Properties
    private let modelName: String
    private let minConfidence: Double
    private var model: VNCoreMLModel?

    // MARK: - Init
    init(modelName: String = Constants.modelName,
         minConfidence: Double = Constants.minConfidence) {
        self.modelName = modelName
        self.minConfidence = minConfidence
    }

    // MARK: - Model Management

    /// Kiểm tra model đã có trong bundle chưa
    func isModelAvailable() -> Bool {
        loadModel() != nil
    }

    /// Load model từ bundle
    private func loadModel() -> VNCoreMLModel? {
        if let cached = model { return cached }

        guard let mlModelURL = Bundle.main.url(forResource: modelName,
                                                withExtension: "mlmodelc")
                ?? Bundle.main.url(forResource: modelName,
                                   withExtension: "mlpackage") else {
            return nil
        }

        do {
            let compiledModel = try MLModel(contentsOf: mlModelURL)
            let visionModel = try VNCoreMLModel(for: compiledModel)
            model = visionModel
            return visionModel
        } catch {
            return nil
        }
    }

    // MARK: - Detection

    /// Phát hiện và đếm vật thể trong ảnh.
    /// - Parameter image: UIImage đầu vào
    /// - Returns: DetectionResult chứa danh sách vật thể
    func detectObjects(in image: UIImage) async throws -> DetectionResult {
        guard let visionModel = loadModel() else {
            throw DetectionError.modelNotFound(name: modelName)
        }

        guard let cgImage = image.cgImage else {
            throw DetectionError.imageProcessingFailed
        }

        let request = VNCoreMLRequest(model: visionModel)
        request.imageCropAndScaleOption = .scaleFill

        let handler = VNImageRequestHandler(
            cgImage: cgImage,
            orientation: image.cgImageOrientation,
            options: [:]
        )

        try handler.perform([request])

        guard let observations = request.results as? [VNRecognizedObjectObservation] else {
            throw DetectionError.noResults
        }

        let objects = parseObservations(observations)

        return DetectionResult(
            image: image,
            objects: objects,
            timestamp: Date()
        )
    }

    // MARK: - Parsing

    /// Parse kết quả từ Vision observations
    private func parseObservations(
        _ observations: [VNRecognizedObjectObservation]
    ) -> [DetectedObject] {
        var results: [DetectedObject] = []

        for observation in observations {
            guard let topLabel = observation.labels
                .max(by: { $0.confidence < $1.confidence }),
                  topLabel.confidence >= Float(minConfidence) else {
                continue
            }

            let label = topLabel.identifier
                .replacingOccurrences(of: "_", with: " ")
                .capitalized

            let detected = DetectedObject(
                label: label,
                confidence: Double(topLabel.confidence),
                boundingBox: observation.boundingBox
            )
            results.append(detected)

            if results.count >= Constants.maxDisplayObjects {
                break
            }
        }

        return results
    }
}

// MARK: - UIImage Helpers
extension UIImage {
    /// Lấy orientation tương thích với Vision framework
    var cgImageOrientation: CGImagePropertyOrientation {
        switch imageOrientation {
        case .up: return .up
        case .down: return .down
        case .left: return .left
        case .right: return .right
        case .upMirrored: return .upMirrored
        case .downMirrored: return .downMirrored
        case .leftMirrored: return .leftMirrored
        case .rightMirrored: return .rightMirrored
        @unknown default: return .up
        }
    }
}
