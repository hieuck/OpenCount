import SwiftUI
import StoreKit

// MARK: - OpenCountClip App Entry Point
//
// App Clip for quick live counting.
// Invoked via NFC tag or QR code: https://opencount.app/clip?session=<id>
// Binary must remain under 15 MB — uses a minimal UI with no SwiftData dependency.
//
// Requirement 56 (Req 45)

@main
struct OpenCountClipApp: App {

    var body: some Scene {
        WindowGroup {
            ClipLiveCountView()
                .onContinueUserActivity(NSUserActivityTypes.browsingWeb) { activity in
                    // Parse session ID from the activation URL if provided
                    if let url = activity.webpageURL {
                        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
                        let sessionID = components?.queryItems?.first(where: { $0.name == "session" })?.value
                        print("[AppClip] Activated with sessionID: \(sessionID ?? "none")")
                    }
                }
        }
    }
}

// MARK: - NSUserActivityTypes

private enum NSUserActivityTypes {
    static let browsingWeb = "NSUserActivityTypeBrowsingWeb"
}
