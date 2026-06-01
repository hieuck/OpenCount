import Foundation

// MARK: - SessionImage

/// An image associated with a counting session.
final class SessionImage: ObservableObject, Identifiable, Codable {
    var id: UUID
    var filename: String
    var thumbnailFilename: String?
    var importedAt: Date
    weak var session: CountSession?

    init(
        id: UUID = UUID(),
        filename: String,
        thumbnailFilename: String? = nil,
        importedAt: Date = Date(),
        session: CountSession? = nil
    ) {
        self.id = id
        self.filename = filename
        self.thumbnailFilename = thumbnailFilename
        self.importedAt = importedAt
        self.session = session
    }

    enum CodingKeys: String, CodingKey {
        case id, filename, thumbnailFilename, importedAt
    }

    required init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id                = try c.decode(UUID.self,   forKey: .id)
        filename          = try c.decode(String.self, forKey: .filename)
        thumbnailFilename = try c.decodeIfPresent(String.self, forKey: .thumbnailFilename)
        importedAt        = try c.decode(Date.self,   forKey: .importedAt)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id,       forKey: .id)
        try c.encode(filename, forKey: .filename)
        try c.encodeIfPresent(thumbnailFilename, forKey: .thumbnailFilename)
        try c.encode(importedAt, forKey: .importedAt)
    }
}
