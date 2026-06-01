import Foundation
import SwiftData

// MARK: - TallyHistoryEntry

/// A timestamped record of a single tally change within a CountSession.
/// Stored as part of the session to allow review of counting progression.
/// Requirement 13.6
struct TallyHistoryEntry: Codable {
    /// When the change occurred.
    let timestamp: Date
    /// The name of the ObjectType whose tally changed.
    let objectTypeName: String
    /// +1 for a placed marker, -1 for a removed marker.
    let delta: Int
}

// MARK: - CountSession

/// A counting session containing one or more source images or a video,
/// a set of ObjectTypes, and all counting results.
@Model
final class CountSession {
    var id: UUID
    var name: String
    var sessionDescription: String?
    var createdAt: Date
    var modifiedAt: Date

    @Relationship(deleteRule: .cascade, inverse: \ObjectType.session)
    var objectTypes: [ObjectType]

    @Relationship(deleteRule: .cascade, inverse: \SessionImage.session)
    var images: [SessionImage]

    @Relationship(deleteRule: .cascade, inverse: \CountRegion.session)
    var regions: [CountRegion]

    @Relationship(deleteRule: .cascade, inverse: \CountMarker.session)
    var markers: [CountMarker]

    @Relationship(deleteRule: .cascade, inverse: \VideoFrameCount.session)
    var videoTimestamps: [VideoFrameCount]

    /// Timestamped log of tally changes (marker placed / removed) within this session.
    /// Requirement 13.6
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
        self.tallyHistory = tallyHistory
    }
}
