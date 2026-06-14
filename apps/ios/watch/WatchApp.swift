import SwiftUI
import WidgetKit

// MARK: - OpenCountWatchApp
// watchOS app entry point for the OpenCount Watch companion.
// Requirements: 22.1–22.6

@main
struct OpenCountWatchApp: App {

    @StateObject private var sessionManager = WatchSessionManager()

    var body: some Scene {
        WindowGroup {
            WatchCountingView()
                .environmentObject(sessionManager)
        }
        // Register complications via WKExtensionDelegateAdaptor is not needed for
        // WidgetKit-based complications — they are registered via the WidgetBundle.
    }
}
