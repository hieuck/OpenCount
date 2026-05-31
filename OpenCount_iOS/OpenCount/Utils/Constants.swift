import Foundation
import SwiftUI

enum Constants {
    // MARK: - Model
    /// Tên file model trong bundle (không bao gồm đuôi .mlmodelc / .mlpackage)
    static let modelName = "YOLOv3"

    /// Ngưỡng confidence tối thiểu để hiển thị kết quả
    static let minConfidence: Double = 0.4

    /// Số lượng vật thể tối đa hiển thị trên một ảnh
    static let maxDisplayObjects = 300

    // MARK: - UI
    static let cornerRadius: CGFloat = 16
    static let padding: CGFloat = 16
    static let smallPadding: CGFloat = 8

    // MARK: - Detection Colors
    static let boundingBoxColors: [Color] = [
        .blue, .green, .orange, .purple, .red,
        .teal, .pink, .indigo, .mint, .yellow
    ]

    /// Lấy màu cho một nhãn cụ thể
    static func color(for label: String) -> Color {
        let index = abs(label.hashValue) % boundingBoxColors.count
        return boundingBoxColors[index]
    }
}
