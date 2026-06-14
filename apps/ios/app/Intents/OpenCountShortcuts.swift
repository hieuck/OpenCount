import AppIntents
import Foundation

// MARK: - OpenCountShortcuts
// Requirement 23.1, 23.6, 27.1–27.4

/// Registers 3 pre-built Shortcut templates in the Shortcuts gallery.
/// Users can discover and add these to their personal Shortcuts library.
struct OpenCountShortcuts: AppShortcutsProvider {

    /// The accent color shown in the Shortcuts app for OpenCount shortcuts.
    static var shortcutTileColor: ShortcutTileColor = .blue

    static var appShortcuts: [AppShortcut] {
        // Shortcut 1: Start counting — "Start counting in OpenCount"
        AppShortcut(
            intent: CreateSessionIntent(),
            phrases: [
                "Start counting in \(.applicationName)",
                "Create a new \(.applicationName) session",
                "New counting session in \(.applicationName)",
            ],
            shortTitle: "Start Counting",
            systemImageName: "plus.circle"
        )

        // Shortcut 2: Show tally — "Show tally in OpenCount"
        AppShortcut(
            intent: GetTallyIntent(),
            phrases: [
                "Show tally in \(.applicationName)",
                "Get count from \(.applicationName)",
                "What's the tally in \(.applicationName)",
            ],
            shortTitle: "Show Tally",
            systemImageName: "number.circle"
        )

        // Shortcut 3: Export as CSV — "Export session from OpenCount"
        AppShortcut(
            intent: ExportSessionIntent(),
            phrases: [
                "Export session from \(.applicationName)",
                "Export \(.applicationName) as CSV",
                "Share \(.applicationName) data",
            ],
            shortTitle: "Export Session",
            systemImageName: "square.and.arrow.up"
        )
    }
}
