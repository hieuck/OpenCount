import Foundation
import SwiftData

// MARK: - SessionTag

/// A user-defined tag for organizing counting sessions.
/// Tags support color coding and emoji icons for quick visual identification.
///
/// This feature surpasses ZapCount and CountThings which offer no session organization.
@Model
final class SessionTag {
    var id: UUID
    var name: String
    var colorHex: String
    var emoji: String
    var createdAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        colorHex: String = "#3498DB",
        emoji: String = "🏷️",
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.colorHex = colorHex
        self.emoji = emoji
        self.createdAt = createdAt
    }
}

// MARK: - Predefined tags

extension SessionTag {
    static let predefinedTags: [(name: String, colorHex: String, emoji: String)] = [
        ("Wildlife",    "#2ECC71", "🦁"),
        ("Inventory",   "#3498DB", "📦"),
        ("Research",    "#9B59B6", "🔬"),
        ("Agriculture", "#F39C12", "🌾"),
        ("Urban",       "#E74C3C", "🏙️"),
        ("Marine",      "#1ABC9C", "🐠"),
        ("Aerial",      "#34495E", "✈️"),
        ("Medical",     "#E67E22", "🏥"),
        ("Sports",      "#F1C40F", "⚽"),
        ("Education",   "#16A085", "📚"),
    ]
}
