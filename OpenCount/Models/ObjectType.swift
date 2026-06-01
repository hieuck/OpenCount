import Foundation
import SwiftData

/// A user-defined category of object to count within a Session,
/// identified by a name, color, and SF Symbol icon.
@Model
final class ObjectType {
    var id: UUID
    var name: String
    /// Hex color string, e.g. "#FF5733"
    var colorHex: String
    /// SF Symbol name, e.g. "person.fill"
    var iconName: String
    var sortOrder: Int
    var session: CountSession?
    /// Optional count target. When set, a progress ring is shown in the toolbar.
    /// Requirement 53 (Req 42)
    var targetCount: Int?

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
}
