import Foundation

// MARK: - ObjectType

/// A user-defined category of object to count within a Session.
final class ObjectType: ObservableObject, Identifiable, Codable {
    var id: UUID
    var name: String
    var colorHex: String
    var iconName: String
    var sortOrder: Int
    var targetCount: Int?
    weak var session: CountSession?

    init(
        id: UUID = UUID(),
        name: String,
        colorHex: String = "#FF5733",
        iconName: String = "circle.fill",
        sortOrder: Int = 0,
        session: CountSession? = nil,
        targetCount: Int? = nil
    ) {
        self.id = id
        self.name = name
        self.colorHex = colorHex
        self.iconName = iconName
        self.sortOrder = sortOrder
        self.session = session
        self.targetCount = targetCount
    }

    // MARK: - Codable
    enum CodingKeys: String, CodingKey {
        case id, name, colorHex, iconName, sortOrder, targetCount
    }

    required init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id          = try c.decode(UUID.self,   forKey: .id)
        name        = try c.decode(String.self, forKey: .name)
        colorHex    = try c.decode(String.self, forKey: .colorHex)
        iconName    = try c.decode(String.self, forKey: .iconName)
        sortOrder   = try c.decode(Int.self,    forKey: .sortOrder)
        targetCount = try c.decodeIfPresent(Int.self, forKey: .targetCount)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id,          forKey: .id)
        try c.encode(name,        forKey: .name)
        try c.encode(colorHex,    forKey: .colorHex)
        try c.encode(iconName,    forKey: .iconName)
        try c.encode(sortOrder,   forKey: .sortOrder)
        try c.encodeIfPresent(targetCount, forKey: .targetCount)
    }
}
