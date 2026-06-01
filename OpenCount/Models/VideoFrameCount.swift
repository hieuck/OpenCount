import Foundation
import SwiftData

/// Counting results associated with a specific video frame timestamp.
@Model
final class VideoFrameCount {
    var id: UUID
    /// Timestamp in seconds from the start of the video
    var timestampSeconds: Double
    /// IDs of CountMarkers placed on this frame (stored as UUIDs to avoid
    /// a complex many-to-many SwiftData relationship)
    var markerIDs: [UUID]
    var session: CountSession?

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
}
