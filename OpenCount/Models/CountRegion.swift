import Foundation
import CoreGraphics
import SwiftData

/// The shape type for a counting region.
enum RegionShapeType: String, Codable {
    case rectangle
    case ellipse
    case polygon
}

/// A user-drawn geometric area on an image that restricts counting to objects within its boundary.
/// All coordinates are normalized (0.0–1.0) relative to the image dimensions.
@Model
final class CountRegion {
    var id: UUID
    var name: String
    /// Hex color string, e.g. "#3399FF"
    var colorHex: String
    var shapeType: RegionShapeType
    /// Polygon vertices or rect corners in normalized coordinates
    var normalizedPoints: [CGPoint]
    var session: CountSession?

    init(
        id: UUID = UUID(),
        name: String,
        colorHex: String = "#3399FF",
        shapeType: RegionShapeType = .rectangle,
        normalizedPoints: [CGPoint] = [],
        session: CountSession? = nil
    ) {
        self.id = id
        self.name = name
        self.colorHex = colorHex
        self.shapeType = shapeType
        self.normalizedPoints = normalizedPoints
        self.session = session
    }

    // MARK: - Geometry helpers

    /// Returns true if the given normalized point falls within this region's boundary.
    func contains(normalizedPoint point: CGPoint) -> Bool {
        switch shapeType {
        case .rectangle:
            return containsRectangle(point)
        case .ellipse:
            return containsEllipse(point)
        case .polygon:
            return containsPolygon(point)
        }
    }

    private func containsRectangle(_ point: CGPoint) -> Bool {
        guard normalizedPoints.count >= 2 else { return false }
        let minX = normalizedPoints.map(\.x).min() ?? 0
        let maxX = normalizedPoints.map(\.x).max() ?? 0
        let minY = normalizedPoints.map(\.y).min() ?? 0
        let maxY = normalizedPoints.map(\.y).max() ?? 0
        return point.x > minX && point.x < maxX && point.y > minY && point.y < maxY
    }

    private func containsEllipse(_ point: CGPoint) -> Bool {
        guard normalizedPoints.count >= 2 else { return false }
        let minX = normalizedPoints.map(\.x).min() ?? 0
        let maxX = normalizedPoints.map(\.x).max() ?? 0
        let minY = normalizedPoints.map(\.y).min() ?? 0
        let maxY = normalizedPoints.map(\.y).max() ?? 0
        let cx = (minX + maxX) / 2
        let cy = (minY + maxY) / 2
        let rx = (maxX - minX) / 2
        let ry = (maxY - minY) / 2
        guard rx > 0, ry > 0 else { return false }
        let dx = (point.x - cx) / rx
        let dy = (point.y - cy) / ry
        return (dx * dx + dy * dy) < 1.0
    }

    private func containsPolygon(_ point: CGPoint) -> Bool {
        guard normalizedPoints.count >= 3 else { return false }
        // Ray-casting algorithm
        var inside = false
        var j = normalizedPoints.count - 1
        for i in 0..<normalizedPoints.count {
            let pi = normalizedPoints[i]
            let pj = normalizedPoints[j]
            let intersects = ((pi.y > point.y) != (pj.y > point.y)) &&
                (point.x < (pj.x - pi.x) * (point.y - pi.y) / (pj.y - pi.y) + pi.x)
            if intersects { inside.toggle() }
            j = i
        }
        return inside
    }
}
