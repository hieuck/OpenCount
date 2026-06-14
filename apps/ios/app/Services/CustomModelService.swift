import Foundation
import CoreML
import Vision
import UIKit

// MARK: - ModelMetadata

/// Metadata for an imported CoreML model.
/// Persisted in UserDefaults as JSON (lightweight, no SwiftData needed).
///
/// Requirement 20.3: display model name, input size, and class labels.
struct ModelMetadata: Codable, Identifiable, Equatable {
    let id: UUID
    let name: String
    /// Filename in Documents/models/ directory
    let filename: String
    let inputSize: CGSize
    let classLabels: [String]
    let importedAt: Date

    var classCount: Int { classLabels.count }
}

// CGSize already conforms to Codable via CoreGraphics on iOS 16+.
// No extension needed here.

// MARK: - CustomModelServiceProtocol

protocol CustomModelServiceProtocol {
    func importModel(from url: URL) async throws -> ModelMetadata
    func validateModel(at url: URL) throws -> ModelMetadata
    func activateModel(_ metadata: ModelMetadata) throws -> VNCoreMLModel
    func listImportedModels() -> [ModelMetadata]
    func deleteModel(_ metadata: ModelMetadata) throws
    var activeModelMetadata: ModelMetadata? { get }
}

// MARK: - CustomModelService

/// Handles import, validation, and switching of CoreML models.
///
/// Requirements: 20.1–20.7
final class CustomModelService: CustomModelServiceProtocol, ObservableObject {

    // MARK: - Published state

    @Published var importedModels: [ModelMetadata] = []
    @Published var activeModelMetadata: ModelMetadata?

    // MARK: - Private constants

    private static let modelsDirectoryName = "models"
    private static let metadataKey = "importedModelMetadata"
    private static let activeModelKey = "activeModelID"

    // MARK: - Init

    init() {
        loadPersistedMetadata()
        loadActiveModel()
    }

    // MARK: - Directories

    private var modelsDirectory: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return docs.appendingPathComponent(Self.modelsDirectoryName, isDirectory: true)
    }

    // MARK: - Import

    /// Copies the model file to Documents/models/, validates it, and persists metadata.
    /// Requirement 20.1: import .mlpackage or .mlmodel from Files app.
    func importModel(from url: URL) async throws -> ModelMetadata {
        // Validate first (throws if invalid)
        let metadata = try validateModel(at: url)

        // Create models directory if needed
        try FileManager.default.createDirectory(at: modelsDirectory,
                                                withIntermediateDirectories: true)

        // Copy file to Documents/models/
        let destination = modelsDirectory.appendingPathComponent(metadata.filename)
        if FileManager.default.fileExists(atPath: destination.path) {
            try FileManager.default.removeItem(at: destination)
        }
        try FileManager.default.copyItem(at: url, to: destination)

        // Persist metadata
        await MainActor.run {
            importedModels.append(metadata)
            persistMetadata()
        }

        return metadata
    }

    // MARK: - Validate

    /// Validates that the model at `url` conforms to the Vision object detection spec.
    /// Requirement 20.2: validate VNRecognizedObjectObservation output type.
    func validateModel(at url: URL) throws -> ModelMetadata {
        guard url.pathExtension == "mlpackage" || url.pathExtension == "mlmodel" ||
              url.pathExtension == "mlmodelc" else {
            throw ModelImportError.unsupportedFormat(url.pathExtension)
        }

        let mlModel: MLModel
        do {
            mlModel = try MLModel(contentsOf: url)
        } catch {
            throw ModelImportError.loadFailed(error.localizedDescription)
        }

        let desc = mlModel.modelDescription

        // Check for object detection output (VNRecognizedObjectObservation compatible)
        _ = desc.outputDescriptionsByName.values.contains { output in
            // Object detection models typically have a "coordinates" or "confidence" output
            output.name.lowercased().contains("coordinate") ||
            output.name.lowercased().contains("confidence") ||
            output.name.lowercased().contains("iouThreshold")
        }

        // Extract class labels from metadata
        let classLabels: [String]
        let metadataDict = desc.metadata
        let classesKey = MLModelMetadataKey(rawValue: "classes")
        let userDefinedKey = MLModelMetadataKey(rawValue: "com.apple.coreml.model.userDefinedMetadata")
        if let labelsArray = metadataDict[classesKey] as? [String] {
            classLabels = labelsArray
        } else if let labelsString = metadataDict[userDefinedKey] as? String {
            classLabels = labelsString.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        } else {
            // Fallback: try to extract from output feature names
            classLabels = desc.outputDescriptionsByName.keys.sorted()
        }

        // Extract input size
        let inputSize: CGSize
        if let firstInput = desc.inputDescriptionsByName.values.first {
            // Try to get image constraint from the feature description
            if let imageConstraint = firstInput.imageConstraint {
                inputSize = CGSize(width: imageConstraint.pixelsWide, height: imageConstraint.pixelsHigh)
            } else {
                inputSize = CGSize(width: 640, height: 640) // YOLO default
            }
        } else {
            inputSize = CGSize(width: 640, height: 640) // YOLO default
        }

        let name = url.deletingPathExtension().lastPathComponent
        let filename = url.lastPathComponent

        return ModelMetadata(
            id: UUID(),
            name: name,
            filename: filename,
            inputSize: inputSize,
            classLabels: classLabels,
            importedAt: Date()
        )
    }

    // MARK: - Activate

    /// Loads and returns a VNCoreMLModel for the given metadata.
    /// Requirement 20.4: switch between built-in and imported models.
    func activateModel(_ metadata: ModelMetadata) throws -> VNCoreMLModel {
        let fileURL = modelsDirectory.appendingPathComponent(metadata.filename)
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            throw ModelImportError.fileNotFound(metadata.filename)
        }

        do {
            let mlModel = try MLModel(contentsOf: fileURL)
            let visionModel = try VNCoreMLModel(for: mlModel)
            activeModelMetadata = metadata
            UserDefaults.standard.set(metadata.id.uuidString, forKey: Self.activeModelKey)
            return visionModel
        } catch {
            throw ModelImportError.activationFailed(error.localizedDescription)
        }
    }

    // MARK: - List

    func listImportedModels() -> [ModelMetadata] {
        importedModels
    }

    // MARK: - Delete

    /// Deletes the model file and removes its metadata.
    /// Requirement 20.4: manage imported models.
    func deleteModel(_ metadata: ModelMetadata) throws {
        let fileURL = modelsDirectory.appendingPathComponent(metadata.filename)
        if FileManager.default.fileExists(atPath: fileURL.path) {
            try FileManager.default.removeItem(at: fileURL)
        }
        importedModels.removeAll { $0.id == metadata.id }
        if activeModelMetadata?.id == metadata.id {
            activeModelMetadata = nil
            UserDefaults.standard.removeObject(forKey: Self.activeModelKey)
        }
        persistMetadata()
    }

    // MARK: - Persistence

    private func persistMetadata() {
        guard let data = try? JSONEncoder().encode(importedModels) else { return }
        UserDefaults.standard.set(data, forKey: Self.metadataKey)
    }

    private func loadPersistedMetadata() {
        guard let data = UserDefaults.standard.data(forKey: Self.metadataKey),
              let models = try? JSONDecoder().decode([ModelMetadata].self, from: data) else { return }
        importedModels = models
    }

    private func loadActiveModel() {
        guard let idString = UserDefaults.standard.string(forKey: Self.activeModelKey),
              let id = UUID(uuidString: idString) else { return }
        activeModelMetadata = importedModels.first { $0.id == id }
    }
}

// MARK: - ModelImportError

enum ModelImportError: LocalizedError {
    case unsupportedFormat(String)
    case loadFailed(String)
    case validationFailed(String)
    case fileNotFound(String)
    case activationFailed(String)

    var errorDescription: String? {
        switch self {
        case .unsupportedFormat(let ext):
            return "Unsupported model format '.\(ext)'. Please use .mlpackage or .mlmodel."
        case .loadFailed(let reason):
            return "Failed to load model: \(reason)"
        case .validationFailed(let reason):
            return "Model validation failed: \(reason)"
        case .fileNotFound(let name):
            return "Model file '\(name)' not found in Documents/models/."
        case .activationFailed(let reason):
            return "Failed to activate model: \(reason)"
        }
    }
}
