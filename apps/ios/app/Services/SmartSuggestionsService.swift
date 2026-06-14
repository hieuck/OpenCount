import Foundation

// MARK: - SmartSuggestionsService

/// Analyzes past sessions to suggest object types when creating a new session.
///
/// Uses frequency analysis across all sessions to recommend the most commonly
/// used object type names, colors, and icons.
///
/// This feature gives OpenCount an advantage over ZapCount and CountThings
/// which require users to manually define all object types every time.
final class SmartSuggestionsService {

    // MARK: - Suggestion model

    struct ObjectTypeSuggestion: Identifiable, Hashable {
        let id = UUID()
        let name: String
        let colorHex: String
        let iconName: String
        let usageCount: Int
        let lastUsed: Date
    }

    // MARK: - Generate suggestions

    /// Returns the top N most frequently used object type names across all sessions,
    /// sorted by usage frequency descending.
    ///
    /// - Parameters:
    ///   - sessions: All available sessions to analyze.
    ///   - limit: Maximum number of suggestions to return.
    ///   - excludingNames: Names to exclude (e.g. already added to current session).
    func suggestions(
        from sessions: [CountSession],
        limit: Int = 10,
        excludingNames: Set<String> = []
    ) -> [ObjectTypeSuggestion] {
        // Aggregate usage across all sessions
        var usageMap: [String: (count: Int, colorHex: String, iconName: String, lastUsed: Date)] = [:]

        for session in sessions {
            for objectType in session.objectTypes {
                let name = objectType.name
                guard !excludingNames.contains(name) else { continue }

                let existing = usageMap[name]
                let newCount = (existing?.count ?? 0) + 1
                let newLastUsed = max(existing?.lastUsed ?? .distantPast, session.modifiedAt)

                usageMap[name] = (
                    count: newCount,
                    colorHex: objectType.colorHex,
                    iconName: objectType.iconName,
                    lastUsed: newLastUsed
                )
            }
        }

        // Sort by usage count descending, then by last used date
        return usageMap
            .map { name, data in
                ObjectTypeSuggestion(
                    name: name,
                    colorHex: data.colorHex,
                    iconName: data.iconName,
                    usageCount: data.count,
                    lastUsed: data.lastUsed
                )
            }
            .sorted { lhs, rhs in
                if lhs.usageCount != rhs.usageCount {
                    return lhs.usageCount > rhs.usageCount
                }
                return lhs.lastUsed > rhs.lastUsed
            }
            .prefix(limit)
            .map { $0 }
    }

    // MARK: - Icon suggestions

    /// Returns SF Symbol names that are commonly used for counting apps,
    /// grouped by category.
    static let iconCategories: [(category: String, icons: [String])] = [
        ("Animals", [
            "bird.fill", "ant.fill", "tortoise.fill", "hare.fill",
            "fish.fill", "pawprint.fill", "ladybug.fill", "lizard.fill"
        ]),
        ("Nature", [
            "leaf.fill", "tree.fill", "flame.fill", "drop.fill",
            "cloud.fill", "sun.max.fill", "moon.fill", "snowflake"
        ]),
        ("Objects", [
            "car.fill", "bicycle", "airplane", "shippingbox.fill",
            "bag.fill", "cart.fill", "cube.fill", "cylinder.fill"
        ]),
        ("People", [
            "person.fill", "person.2.fill", "person.3.fill",
            "figure.walk", "figure.run", "figure.stand"
        ]),
        ("Shapes", [
            "circle.fill", "square.fill", "triangle.fill", "diamond.fill",
            "star.fill", "heart.fill", "bolt.fill", "flag.fill"
        ]),
        ("Science", [
            "atom", "cross.fill", "waveform", "chart.bar.fill",
            "microscope", "stethoscope", "pills.fill", "syringe.fill"
        ]),
    ]

    // MARK: - Color palette

    /// A curated palette of colors suitable for counting markers.
    static let colorPalette: [(name: String, hex: String)] = [
        ("Red",       "#E74C3C"),
        ("Orange",    "#E67E22"),
        ("Yellow",    "#F1C40F"),
        ("Green",     "#2ECC71"),
        ("Teal",      "#1ABC9C"),
        ("Blue",      "#3498DB"),
        ("Indigo",    "#5B6EAE"),
        ("Purple",    "#9B59B6"),
        ("Pink",      "#E91E8C"),
        ("Brown",     "#795548"),
        ("Gray",      "#95A5A6"),
        ("Dark",      "#34495E"),
    ]
}
