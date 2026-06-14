import Foundation
import CoreGraphics

/// An in-memory (non-persistent) object detection result produced by the CoreML/Vision pipeline.
/// Contains a bounding box, class label, confidence score, and acceptance state.
struct AIDetection: Identifiable, Equatable, Codable {
    let id: UUID
    /// Normalized bounding box (0.0–1.0 in both dimensions)
    let normalizedBoundingBox: CGRect
    /// The detected object class label
    let label: String
    /// Confidence score in the range [0.0, 1.0]
    let confidenceScore: Float
    /// Whether the user has accepted this detection and converted it to a CountMarker
    var isAccepted: Bool

    init(
        id: UUID = UUID(),
        normalizedBoundingBox: CGRect,
        label: String,
        confidenceScore: Float,
        isAccepted: Bool = false
    ) {
        self.id = id
        self.normalizedBoundingBox = normalizedBoundingBox
        self.label = label
        self.confidenceScore = confidenceScore
        self.isAccepted = isAccepted
    }

    /// The normalized centroid of the bounding box, used when converting to a CountMarker.
    var normalizedCentroid: CGPoint {
        CGPoint(
            x: normalizedBoundingBox.midX,
            y: normalizedBoundingBox.midY
        )
    }
}
