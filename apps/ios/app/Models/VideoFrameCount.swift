import Foundation

// MARK: - VideoFrameCount

/// Counting results associated with a specific video frame timestamp.
final class VideoFrameCount: ObservableObject, Identifiable, Codable {
    var id: UUID
    var timestampSeconds: Double
    var markerIDs: [UUID]
    weak var session: CountSession?

    init(
        id: UUID = UUID(),
        timestampSeconds: Double,
        markerIDs: [UUID] = [],
        session: CountSession? = nil
    ) {
        self.id = id
        self.timestampSeconds = timestampSeconds
        self.markerIDs = markerIDs
        self.session = session
    }

    enum CodingKeys: String, CodingKey {
        case id, timestampSeconds, markerIDs
    }

    required init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id               = try c.decode(UUID.self,   forKey: .id)
        timestampSeconds = try c.decode(Double.self, forKey: .timestampSeconds)
        markerIDs        = try c.decode([UUID].self, forKey: .markerIDs)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id,               forKey: .id)
        try c.encode(timestampSeconds, forKey: .timestampSeconds)
        try c.encode(markerIDs,        forKey: .markerIDs)
    }
}
