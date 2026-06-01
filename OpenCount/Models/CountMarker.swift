import Foundation
import SwiftData

/// A visual point placed on an image representing one counted instance of an ObjectType.
/// Coordinates are normalized (0.0–1.0) relative to the image dimensions.
@Model
final class CountMarker {
    var id: UUID
    /// Normalized X coordinate (0.0–1.0 relative to image width)
    var normalizedX: Double
    /// Normalized Y coordinate (0.0–1.0 relative to image height)
    var normalizedY: Double
    var objectType: ObjectType
    /// true if this marker was converted from an AI detection
    var isAIDerived: Bool
    var createdAt: Date
    var session: CountSession?
    /// Optional: the ID of the region this marker was placed in
    var regionID: UUID?

    init(
        id: UUID = UUID(),
        normalizedX: Double,
        normalizedY: Double,
        objectType: ObjectType,
        isAIDerived: Bool = false,
        createdAt: Date = Date(),
        session: CountSession? = nil,
        regionID: UUID? = nil
    ) {
        self.id = id
        self.normalizedX = normalizedX
        self.normalizedY = normalizedY
        self.objectType = objectType
        self.isAIDerived = isAIDerived
        self.createdAt = createdAt
        self.session = session
        self.regionID = regionID
    }
}
