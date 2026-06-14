import Foundation

// MARK: - SessionTag

final class SessionTag: ObservableObject, Identifiable, Codable {
    var id: UUID
    var name: String
    var colorHex: String
    var emoji: String
    var createdAt: Date

    init(id: UUID = UUID(), name: String, colorHex: String = "#3498DB",
         emoji: String = "🏷️", createdAt: Date = Date()) {
        self.id = id; self.name = name; self.colorHex = colorHex
        self.emoji = emoji; self.createdAt = createdAt
    }

    static let predefinedTags: [(name: String, colorHex: String, emoji: String)] = [
        ("Wildlife","#2ECC71","🦁"),("Inventory","#3498DB","📦"),
        ("Research","#9B59B6","🔬"),("Agriculture","#F39C12","🌾"),
        ("Urban","#E74C3C","🏙️"),("Marine","#1ABC9C","🐠"),
        ("Aerial","#34495E","✈️"),("Medical","#E67E22","🏥"),
        ("Sports","#F1C40F","⚽"),("Education","#16A085","📚"),
    ]
}
