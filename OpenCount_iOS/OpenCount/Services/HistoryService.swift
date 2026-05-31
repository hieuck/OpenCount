import Foundation

/// Model lưu trữ một kết quả đếm trong lịch sử
struct CountHistory: Identifiable, Codable {
    let id: UUID
    let timestamp: Date
    let totalCount: Int
    let statistics: [(label: String, count: Int)]
    let imageData: Data? // Ảnh thumbnail (optional)

    init(from result: DetectionResult) {
        self.id = UUID()
        self.timestamp = result.timestamp
        self.totalCount = result.totalCount
        self.statistics = result.statistics
        // Compress image để lưu trữ
        self.imageData = result.image.jpegData(compressionQuality: 0.3)
    }

    enum CodingKeys: String, CodingKey {
        case id, timestamp, totalCount, statistics, imageData
    }
}

/// Service quản lý lịch sử đếm
@MainActor
final class HistoryService: ObservableObject {
    @Published private(set) var items: [CountHistory] = []

    private let userDefaults = UserDefaults.standard
    private let historyKey = "opencount_history"
    private let detectionResultsKey = "opencount_detection_results"
    private let maxItems = 100

    init() {
        loadHistory()
    }

    /// Thêm kết quả mới vào lịch sử
    func add(_ result: DetectionResult) {
        let history = CountHistory(from: result)
        items.insert(history, at: 0)

        if items.count > maxItems {
            items.removeLast(items.count - maxItems)
        }

        saveHistory()
    }

    /// Lưu DetectionResult (cho Statistics/Export)
    func saveResult(_ result: DetectionResult) async throws {
        var results = try loadDetectionResults()
        results.insert(result, at: 0)

        if results.count > maxItems {
            results.removeLast(results.count - maxItems)
        }

        let data = try JSONEncoder().encode(results)
        userDefaults.set(data, forKey: detectionResultsKey)
    }

    /// Load tất cả DetectionResults
    func loadResults() async throws -> [DetectionResult] {
        try loadDetectionResults()
    }

    /// Xóa một DetectionResult
    func deleteResult(_ id: UUID) async throws {
        var results = try loadDetectionResults()
        results.removeAll { $0.id == id }

        let data = try JSONEncoder().encode(results)
        userDefaults.set(data, forKey: detectionResultsKey)
    }

    /// Xóa toàn bộ
    func clearAll() async throws {
        items.removeAll()
        userDefaults.removeObject(forKey: detectionResultsKey)
        saveHistory()
    }

    // MARK: - Private

    private func loadDetectionResults() throws -> [DetectionResult] {
        guard let data = userDefaults.data(forKey: detectionResultsKey) else {
            return []
        }
        return try JSONDecoder().decode([DetectionResult].self, from: data)
    }

    /// Xóa một mục từ lịch sử
    func delete(_ history: CountHistory) {
        items.removeAll { $0.id == history.id }
        saveHistory()
    }

    /// Xóa toàn bộ lịch sử
    func deleteAll() {
        items.removeAll()
        saveHistory()
    }

    /// Lưu lịch sử vào UserDefaults
    private func saveHistory() {
        do {
            let data = try JSONEncoder().encode(items)
            userDefaults.set(data, forKey: historyKey)
        } catch {
            print("❌ Lỗi lưu lịch sử: \(error)")
        }
    }

    /// Tải lịch sử từ UserDefaults
    private func loadHistory() {
        guard let data = userDefaults.data(forKey: historyKey) else {
            items = []
            return
        }

        do {
            items = try JSONDecoder().decode([CountHistory].self, from: data)
        } catch {
            print("❌ Lỗi tải lịch sử: \(error)")
            items = []
        }
    }
}
