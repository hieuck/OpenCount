import Foundation
import SwiftData

/// Counting results associated with a specific video frame timestamp.
@Model
final class VideoFrameCount {
    var id: UUID
    /// Timestamp in seconds from the start of the video
    var timestampSeconds: Double

    @Relationship(deleteRule: .cascade)
    var markers: [CountMarker]

    var session: CountSession?

    init(
        id: UUID = UUID(),
        timestampSeconds: Double,
        markers: [CountMarker] = [],
        session: CountSession? = nil
    ) {
        self.id = id
        self.timestampSeconds = timestampSeconds
        self.markers = markers
        self.session = session
    }
}
