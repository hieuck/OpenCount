import Foundation
import CoreGraphics

// MARK: - AnnotationLayerType

/// The types of annotation layers that can be shown or hidden independently.
///
/// Requirement 34.5
enum AnnotationLayerType: String, CaseIterable, Codable, Identifiable {
    case markers = "Markers"
    case regions = "Regions"
    case aiDetections = "AI Detections"
    case textLabels = "Text Labels"
    case measureLines = "Measure Lines"
    case arrows = "Arrows"
    case heatmap = "Heatmap"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .markers: return "mappin.circle.fill"
        case .regions: return "rectangle.dashed"
        case .aiDetections: return "brain.head.profile"
        case .textLabels: return "textformat"
        case .measureLines: return "ruler"
        case .arrows: return "arrow.up.right"
        case .heatmap: return "flame.fill"
        }
    }
}

// MARK: - TextAnnotation

/// A text label placed at a normalized position on the image canvas.
///
/// Requirement 34.1
struct TextAnnotation: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    /// Normalized position (0.0–1.0) on the image canvas.
    var normalizedPosition: CGPoint
    var text: String
    /// Font size in points (12–36 pt).
    var fontSize: CGFloat = 16
    var colorHex: String = "#FFFFFF"
}

// MARK: - MeasureLine

/// A straight measurement line between two normalized points on the image canvas.
///
/// Requirement 34.2
struct MeasureLine: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    /// Start point in normalized coordinates (0.0–1.0).
    var startPoint: CGPoint
    /// End point in normalized coordinates (0.0–1.0).
    var endPoint: CGPoint
    var colorHex: String = "#FFFF00"

    /// Euclidean length in normalized units.
    var normalizedLength: Double {
        let dx = endPoint.x - startPoint.x
        let dy = endPoint.y - startPoint.y
        return sqrt(dx * dx + dy * dy)
    }

    /// Midpoint in normalized coordinates (used for label placement).
    var midPoint: CGPoint {
        CGPoint(x: (startPoint.x + endPoint.x) / 2,
                y: (startPoint.y + endPoint.y) / 2)
    }
}

// MARK: - ArrowAnnotation

/// An arrow annotation pointing from a tail to a head in normalized coordinates.
///
/// Requirement 34.3
struct ArrowAnnotation: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    /// Tail (start) point in normalized coordinates.
    var tailPoint: CGPoint
    /// Head (arrowhead) point in normalized coordinates.
    var headPoint: CGPoint
    var colorHex: String = "#FF0000"
}

// CGPoint already conforms to Codable via CoreGraphics on iOS 16+.
// No extension needed.
