import Foundation
import CoreGraphics

// MARK: - RegionShapeType

enum RegionShapeType: String, Codable {
    case rectangle
    case ellipse
    case polygon
}

// MARK: - CountRegion

/// A user-drawn geometric area on an image that restricts counting to objects within its boundary.
final class CountRegion: ObservableObject, Identifiable, Codable {
    var id: UUID
    var name: String
    var colorHex: String
    var shapeType: RegionShapeType
    var normalizedPoints: [CGPoint]
    weak var session: CountSession?

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

    enum CodingKeys: String, CodingKey {
        case id, name, colorHex, shapeType, normalizedPoints
    }

    required init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id              = try c.decode(UUID.self,            forKey: .id)
        name            = try c.decode(String.self,          forKey: .name)
        colorHex        = try c.decode(String.self,          forKey: .colorHex)
        shapeType       = try c.decode(RegionShapeType.self, forKey: .shapeType)
        normalizedPoints = try c.decode([CGPoint].self,      forKey: .normalizedPoints)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id,              forKey: .id)
        try c.encode(name,            forKey: .name)
        try c.encode(colorHex,        forKey: .colorHex)
        try c.encode(shapeType,       forKey: .shapeType)
        try c.encode(normalizedPoints, forKey: .normalizedPoints)
    }

    // MARK: - Geometry

    func contains(normalizedPoint point: CGPoint) -> Bool {
        switch shapeType {
        case .rectangle: return containsRectangle(point)
        case .ellipse:   return containsEllipse(point)
        case .polygon:   return containsPolygon(point)
        }
    }

    private func containsRectangle(_ point: CGPoint) -> Bool {
        guard normalizedPoints.count >= 2 else { return false }
        let xs = normalizedPoints.map(\.x), ys = normalizedPoints.map(\.y)
        return point.x > (xs.min() ?? 0) && point.x < (xs.max() ?? 0)
            && point.y > (ys.min() ?? 0) && point.y < (ys.max() ?? 0)
    }

    private func containsEllipse(_ point: CGPoint) -> Bool {
        guard normalizedPoints.count >= 2 else { return false }
        let xs = normalizedPoints.map(\.x), ys = normalizedPoints.map(\.y)
        let cx = ((xs.min() ?? 0) + (xs.max() ?? 0)) / 2
        let cy = ((ys.min() ?? 0) + (ys.max() ?? 0)) / 2
        let rx = ((xs.max() ?? 0) - (xs.min() ?? 0)) / 2
        let ry = ((ys.max() ?? 0) - (ys.min() ?? 0)) / 2
        guard rx > 0, ry > 0 else { return false }
        let dx = (point.x - cx) / rx, dy = (point.y - cy) / ry
        return (dx * dx + dy * dy) < 1.0
    }

    private func containsPolygon(_ point: CGPoint) -> Bool {
        guard normalizedPoints.count >= 3 else { return false }
        var inside = false
        var j = normalizedPoints.count - 1
        for i in 0..<normalizedPoints.count {
            let pi = normalizedPoints[i], pj = normalizedPoints[j]
            if ((pi.y > point.y) != (pj.y > point.y)) &&
               (point.x < (pj.x - pi.x) * (point.y - pi.y) / (pj.y - pi.y) + pi.x) {
                inside.toggle()
            }
            j = i
        }
        return inside
    }
}
