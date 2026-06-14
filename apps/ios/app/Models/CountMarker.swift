import Foundation

// MARK: - CountMarker

/// A visual point placed on an image representing one counted instance of an ObjectType.
final class CountMarker: ObservableObject, Identifiable, Codable {
    var id: UUID
    var normalizedX: Double
    var normalizedY: Double
    var objectTypeID: UUID          // stored as ID; resolved via session.objectTypes
    var isAIDerived: Bool
    var createdAt: Date
    var regionID: UUID?
    weak var session: CountSession?

    // Transient resolved reference (not persisted)
    var objectType: ObjectType {
        get {
            session?.objectTypes.first { $0.id == objectTypeID }
                ?? ObjectType(id: objectTypeID, name: "Unknown")
        }
        set { objectTypeID = newValue.id }
    }

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
        self.objectTypeID = objectType.id
        self.isAIDerived = isAIDerived
        self.createdAt = createdAt
        self.session = session
        self.regionID = regionID
    }

    // MARK: - Codable
    enum CodingKeys: String, CodingKey {
        case id, normalizedX, normalizedY, objectTypeID, isAIDerived, createdAt, regionID
    }

    required init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id          = try c.decode(UUID.self,   forKey: .id)
        normalizedX = try c.decode(Double.self, forKey: .normalizedX)
        normalizedY = try c.decode(Double.self, forKey: .normalizedY)
        objectTypeID = try c.decode(UUID.self,  forKey: .objectTypeID)
        isAIDerived = try c.decode(Bool.self,   forKey: .isAIDerived)
        createdAt   = try c.decode(Date.self,   forKey: .createdAt)
        regionID    = try c.decodeIfPresent(UUID.self, forKey: .regionID)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id,          forKey: .id)
        try c.encode(normalizedX, forKey: .normalizedX)
        try c.encode(normalizedY, forKey: .normalizedY)
        try c.encode(objectTypeID, forKey: .objectTypeID)
        try c.encode(isAIDerived, forKey: .isAIDerived)
        try c.encode(createdAt,   forKey: .createdAt)
        try c.encodeIfPresent(regionID, forKey: .regionID)
    }
}
