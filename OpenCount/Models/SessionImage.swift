import Foundation
import SwiftData

/// An image associated with a counting session.
/// The actual image file is stored in the app's Documents/images/ directory;
/// only the filename is persisted here.
@Model
final class SessionImage {
    var id: UUID
    /// Filename in the app's Documents/images/ directory
    var filename: String
    /// Optional thumbnail filename in the app's Documents/thumbnails/ directory
    var thumbnailFilename: String?
    var importedAt: Date
    var session: CountSession?

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
}
