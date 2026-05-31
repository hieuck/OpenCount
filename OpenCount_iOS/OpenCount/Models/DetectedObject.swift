import Foundation
import SwiftUI

/// Một vật thể được phát hiện trong ảnh.
struct DetectedObject: Identifiable, Equatable {
    let id = UUID()
    /// Nhãn của vật thể (vd: "person", "car", "bottle")
    let label: String
    /// Độ tin cậy (0.0 - 1.0)
    let confidence: Double
    /// Bounding box ở tọa độ normalized (0-1), gốc trên-trái
    let boundingBox: CGRect

    static func == (lhs: DetectedObject, rhs: DetectedObject) -> Bool {
        lhs.id == rhs.id
    }
}

/// Kết quả phát hiện cho một ảnh.
struct DetectionResult: Equatable {
    let image: UIImage
    let objects: [DetectedObject]
    let timestamp: Date

    /// Tổng số vật thể đã đếm
    var totalCount: Int { objects.count }

    /// Thống kê theo nhãn, sắp xếp giảm dần theo số lượng
    var statistics: [(label: String, count: Int)] {
        let grouped = Dictionary(grouping: objects, by: \.label)
        return grouped
            .map { ($0.key, $0.value.count) }
            .sorted { $0.1 > $1.1 }
    }

    static func == (lhs: DetectionResult, rhs: DetectionResult) -> Bool {
        lhs.objects == rhs.objects && lhs.timestamp == rhs.timestamp
    }
}
