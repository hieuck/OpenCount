import Foundation
import WidgetKit

// MARK: - WidgetDataKeys (main app copy)
// Requirement 23.3, 23.4

/// Keys used to share data between the main app and the widget extension via UserDefaults app group.
/// This enum is duplicated in `OpenCountWidget/OpenCountWidget.swift` for the widget extension target,
/// since the widget extension cannot import the main app module.
/// Both copies must stay in sync.
enum WidgetDataKeys {
    static let sessionName = "widget_sessionName"
    static let objectTypeName = "widget_objectTypeName"
    static let tally = "widget_tally"
    static let sessionID = "widget_sessionID"
}

// MARK: - WidgetDataWriter
// Requirement 23.3, 23.4

/// Writes the latest session tally snapshot to the shared UserDefaults app group
/// so the WidgetKit extension can read it without direct SwiftData access.
///
/// Call `write(session:objectTypeName:)` after any tally-changing operation
/// (marker placed, marker removed, AI accepted) to keep the widget up to date.
///
/// The app group identifier `group.com.opencount.app` must be configured in:
///   - The main app target's entitlements (App Groups capability)
///   - The OpenCountWidget extension target's entitlements (App Groups capability)
enum WidgetDataWriter {

    private static let suiteName = "group.com.opencount.app"

    /// Writes the tally for the given session (and optional object type) to the shared
    /// UserDefaults suite and requests a WidgetKit timeline reload.
    ///
    /// - Parameters:
    ///   - session: The session whose tally should be displayed in the widget.
    ///   - objectTypeName: If non-nil, only the tally for this object type is written.
    ///                     If nil, the total marker count is written.
    static func write(session: CountSession, objectTypeName: String? = nil) {
        guard let defaults = UserDefaults(suiteName: suiteName) else { return }

        let tally: Int
        if let typeName = objectTypeName {
            let lower = typeName.lowercased()
            tally = session.markers.filter { $0.objectType.name.lowercased() == lower }.count
        } else {
            tally = session.markers.count
        }

        defaults.set(session.name, forKey: WidgetDataKeys.sessionName)
        defaults.set(objectTypeName, forKey: WidgetDataKeys.objectTypeName)
        defaults.set(tally, forKey: WidgetDataKeys.tally)
        defaults.set(session.id.uuidString, forKey: WidgetDataKeys.sessionID)

        // Ask WidgetKit to reload the timeline so the widget reflects the new data
        // within the 15-minute budget — Requirement 23.4
        WidgetCenter.shared.reloadTimelines(ofKind: "OpenCountWidget")
    }
}
