import Foundation

// MARK: - TallyHistoryEntry

struct TallyHistoryEntry: Codable {
    let timestamp: Date
    let objectTypeName: String
    let delta: Int
}

// MARK: - CountSession

/// A counting session — the central model of OpenCount.
/// Stored as JSON in Documents/sessions/<id>.json
final class CountSession: ObservableObject, Identifiable, Codable, Hashable {

    // MARK: - Hashable
    static func == (lhs: CountSession, rhs: CountSession) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    var id: UUID
    var name: String
    var sessionDescription: String?
    var createdAt: Date
    var modifiedAt: Date
    var objectTypes: [ObjectType]
    var images: [SessionImage]
    var regions: [CountRegion]
    var markers: [CountMarker]
    var videoTimestamps: [VideoFrameCount]
    var formulas: [CountFormula]
    var tallyHistory: [TallyHistoryEntry]

    init(
        id: UUID = UUID(),
        name: String,
        sessionDescription: String? = nil,
        createdAt: Date = Date(),
        modifiedAt: Date = Date(),
        objectTypes: [ObjectType] = [],
        images: [SessionImage] = [],
        regions: [CountRegion] = [],
        markers: [CountMarker] = [],
        videoTimestamps: [VideoFrameCount] = [],
        formulas: [CountFormula] = [],
        tallyHistory: [TallyHistoryEntry] = []
    ) {
        self.id = id
        self.name = name
        self.sessionDescription = sessionDescription
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
        self.objectTypes = objectTypes
        self.images = images
        self.regions = regions
        self.markers = markers
        self.videoTimestamps = videoTimestamps
        self.formulas = formulas
        self.tallyHistory = tallyHistory
        // Wire back-references
        objectTypes.forEach { $0.session = self }
        images.forEach      { $0.session = self }
        regions.forEach     { $0.session = self }
        markers.forEach     { $0.session = self }
        videoTimestamps.forEach { $0.session = self }
        formulas.forEach    { $0.session = self }
    }

    // MARK: - Codable (manual — weak refs excluded)
    enum CodingKeys: String, CodingKey {
        case id, name, sessionDescription, createdAt, modifiedAt
        case objectTypes, images, regions, markers, videoTimestamps, formulas, tallyHistory
    }

    required init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id                 = try c.decode(UUID.self,   forKey: .id)
        name               = try c.decode(String.self, forKey: .name)
        sessionDescription = try c.decodeIfPresent(String.self, forKey: .sessionDescription)
        createdAt          = try c.decode(Date.self,   forKey: .createdAt)
        modifiedAt         = try c.decode(Date.self,   forKey: .modifiedAt)
        objectTypes        = try c.decode([ObjectType].self,      forKey: .objectTypes)
        images             = try c.decode([SessionImage].self,    forKey: .images)
        regions            = try c.decode([CountRegion].self,     forKey: .regions)
        markers            = try c.decode([CountMarker].self,     forKey: .markers)
        videoTimestamps    = try c.decode([VideoFrameCount].self, forKey: .videoTimestamps)
        formulas           = try c.decode([CountFormula].self,    forKey: .formulas)
        tallyHistory       = try c.decode([TallyHistoryEntry].self, forKey: .tallyHistory)
        // Wire back-references after decode
        objectTypes.forEach { $0.session = self }
        images.forEach      { $0.session = self }
        regions.forEach     { $0.session = self }
        markers.forEach     { $0.session = self }
        videoTimestamps.forEach { $0.session = self }
        formulas.forEach    { $0.session = self }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id,                 forKey: .id)
        try c.encode(name,               forKey: .name)
        try c.encodeIfPresent(sessionDescription, forKey: .sessionDescription)
        try c.encode(createdAt,          forKey: .createdAt)
        try c.encode(modifiedAt,         forKey: .modifiedAt)
        try c.encode(objectTypes,        forKey: .objectTypes)
        try c.encode(images,             forKey: .images)
        try c.encode(regions,            forKey: .regions)
        try c.encode(markers,            forKey: .markers)
        try c.encode(videoTimestamps,    forKey: .videoTimestamps)
        try c.encode(formulas,           forKey: .formulas)
        try c.encode(tallyHistory,       forKey: .tallyHistory)
    }
}
