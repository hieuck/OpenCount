import Foundation
import SwiftUI
import PhotosUI

/// Các trạng thái của ứng dụng
enum AppState: Equatable {
    /// Chưa chọn ảnh — màn hình chào
    case idle
    /// Đang xử lý ảnh với AI
    case processing
    /// Đã có kết quả
    case result(DetectionResult)
    /// Có lỗi xảy ra
    case error(String)

    static func == (lhs: AppState, rhs: AppState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle), (.processing, .processing):
            return true
        case (.result(let a), .result(let b)):
            return a == b
        case (.error(let a), .error(let b)):
            return a == b
        default:
            return false
        }
    }
}

@MainActor
final class CountViewModel: ObservableObject {

    // MARK: - Published
    @Published private(set) var state: AppState = .idle
    @Published var selectedImage: UIImage?
    @Published var showingCamera = false
    @Published var showingPhotoPicker = false
    @Published var showingModelGuide = false
    @Published private(set) var history: [DetectionResult] = []

    // MARK: - Settings
    @AppStorage("min_confidence") var minConfidence: Double = Constants.minConfidence

    // MARK: - Services
    private var detectionService: DetectionService {
        DetectionService(minConfidence: minConfidence)
    }
    private let historyService = HistoryService()

    // MARK: - Init
    init() {
        loadHistory()
    }

    // MARK: - Computed
    var isIdle: Bool {
        if case .idle = state { return true }
        return false
    }

    var isProcessing: Bool {
        if case .processing = state { return true }
        return false
    }

    var currentResult: DetectionResult? {
        if case .result(let result) = state { return result }
        return nil
    }

    var errorMessage: String? {
        if case .error(let msg) = state { return msg }
        return nil
    }

    // MARK: - Intents

    /// Chọn ảnh từ thư viện
    func selectPhoto(_ item: PhotosPickerItem?) {
        guard let item else { return }
        state = .processing

        Task {
            do {
                guard let data = try await item.loadTransferable(type: Data.self),
                      let image = UIImage(data: data) else {
                    state = .error("Không thể tải ảnh. Vui lòng thử lại.")
                    return
                }
                selectedImage = image
                try await processImage(image)
            } catch {
                handleError(error)
            }
        }
    }

    /// Chụp ảnh từ camera
    func capturedPhoto(_ image: UIImage) {
        state = .processing
        selectedImage = image

        Task {
            do {
                try await processImage(image)
            } catch {
                handleError(error)
            }
        }
    }

    /// Xử lý ảnh với AI
    private func processImage(_ image: UIImage) async throws {
        let service = detectionService

        guard await service.isModelAvailable() else {
            state = .error("Model AI chưa được cài đặt. Vui lòng xem hướng dẫn.")
            showingModelGuide = true
            return
        }

        let result = try await service.detectObjects(in: image)
        state = .result(result)

        // Lưu vào history
        await saveToHistory(result)
    }

    /// Lưu kết quả vào history
    private func saveToHistory(_ result: DetectionResult) {
        history.insert(result, at: 0)
        Task {
            try? await historyService.saveResult(result)
        }
    }

    /// Load history từ disk
    private func loadHistory() {
        Task {
            if let loaded = try? await historyService.loadResults() {
                self.history = loaded
            }
        }
    }

    /// Xóa một item từ history
    func deleteFromHistory(_ result: DetectionResult) {
        history.removeAll { $0.id == result.id }
        Task {
            try? await historyService.deleteResult(result.id)
        }
    }

    /// Xóa toàn bộ history
    func clearHistory() {
        history.removeAll()
        Task {
            try? await historyService.clearAll()
        }
    }

    /// Xử lý lỗi
    private func handleError(_ error: Error) {
        if let detectionError = error as? DetectionService.DetectionError {
            state = .error(detectionError.localizedDescription)
        } else {
            state = .error(error.localizedDescription)
        }
    }

    /// Reset về màn hình chính
    func reset() {
        state = .idle
        selectedImage = nil
    }

    /// Chụp ảnh mới
    func takePhoto() {
        showingCamera = true
    }

    /// Chọn ảnh từ thư viện
    func pickPhoto() {
        showingPhotoPicker = true
    }
}
