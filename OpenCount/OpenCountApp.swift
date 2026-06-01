import SwiftUI
import SwiftData
import AppIntents

@main
struct OpenCountApp: App {

    let modelContainer: ModelContainer

    @StateObject private var syncViewModel = iCloudSyncViewModel()
    @StateObject private var networkMonitor = NetworkMonitor()

    @Environment(\.scenePhase) private var scenePhase

    /// Whether to show the crash report consent sheet.
    @State private var isShowingCrashConsent: Bool = false
    @State private var pendingCrashDescription: String = ""

    // MARK: - Deep-link state (Requirement 27.1–27.4)

    /// The session UUID parsed from an `opencount://session/<id>` deep-link URL.
    @State private var deepLinkedSessionID: UUID? = nil

    init() {
        let schema = Schema([
            CountSession.self,
            ObjectType.self,
            CountMarker.self,
            CountRegion.self,
            SessionImage.self,
            VideoFrameCount.self,
            SessionTemplate.self,
        ])

        let iCloudSyncEnabled = UserDefaults.standard.bool(forKey: "iCloudSyncEnabled")
        let iCloudAvailable = FileManager.default.ubiquityIdentityToken != nil

        if iCloudSyncEnabled && iCloudAvailable {
            do {
                let cloudConfig = ModelConfiguration(
                    schema: schema,
                    isStoredInMemoryOnly: false,
                    cloudKitDatabase: .private("iCloud.com.opencount.app")
                )
                modelContainer = try ModelContainer(
                    for: schema,
                    configurations: [cloudConfig]
                )
            } catch {
                modelContainer = Self.makeLocalContainer(schema: schema)
            }
        } else {
            modelContainer = Self.makeLocalContainer(schema: schema)
        }

        if let recovery = CrashRecoveryService.loadRecovery() {
            print("[CrashRecovery] Recovery file found for session '\(recovery.name)' " +
                  "with \(recovery.markers.count) marker(s).")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView(deepLinkedSessionID: $deepLinkedSessionID)
                .environmentObject(syncViewModel)
                .environmentObject(networkMonitor)
                // Handoff — Requirement 49 (Req 38)
                .onContinueUserActivity("com.opencount.counting") { activity in
                    if let sessionIDString = activity.userInfo?["sessionID"] as? String,
                       let uuid = UUID(uuidString: sessionIDString) {
                        deepLinkedSessionID = uuid
                    }
                }
                // Offline banner injected at root level — Requirement 33.2
                .safeAreaInset(edge: .top, spacing: 0) {
                    OfflineBanner()
                        .environmentObject(networkMonitor)
                        .animation(.spring(response: 0.4, dampingFraction: 0.8),
                                   value: networkMonitor.isConnected)
                }
                // Crash report consent — Requirement 32.5
                .sheet(isPresented: $isShowingCrashConsent) {
                    CrashReportConsentView(
                        crashDescription: pendingCrashDescription,
                        onConsent: {
                            Task {
                                try? await FeedbackService.shared.submitCrashReport(
                                    pendingCrashDescription, userConsented: true)
                            }
                            isShowingCrashConsent = false
                        },
                        onDecline: {
                            isShowingCrashConsent = false
                        }
                    )
                }
                .onAppear {
                    // Skip onboarding in UI test mode — Requirement 50 (Req 39)
                    if CommandLine.arguments.contains("--skip-onboarding") {
                        UserDefaults.standard.set(true, forKey: "hasSeenOnboarding")
                    }
                    // Check for pending crash report on launch — Requirement 32.4
                    if FeedbackService.shared.hasPendingCrashReport,
                       let desc = FeedbackService.shared.getPendingCrashDescription() {
                        pendingCrashDescription = desc
                        isShowingCrashConsent = true
                    }
                }
                // Handle deep-link URL scheme opencount://session/<id> — Requirement 27.1–27.4
                .onOpenURL { url in
                    handleDeepLink(url)
                }
        }
        .modelContainer(modelContainer)
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .background {
                try? modelContainer.mainContext.save()
            }
        }
    }

    // MARK: - Deep-link handling (Requirement 27.1–27.4)

    /// Parses `opencount://session/<uuid>` URLs and sets `deepLinkedSessionID`.
    /// The `ContentView` / `SessionListView` observes this binding to navigate directly
    /// to the corresponding `CountingView`.
    private func handleDeepLink(_ url: URL) {
        guard url.scheme?.lowercased() == "opencount" else { return }

        // Expected format: opencount://session/<uuid>
        if url.host?.lowercased() == "session" {
            let pathComponents = url.pathComponents.filter { $0 != "/" }
            if let idString = pathComponents.first, let uuid = UUID(uuidString: idString) {
                deepLinkedSessionID = uuid
            }
        }
    }

    private static func makeLocalContainer(schema: Schema) -> ModelContainer {
        do {
            let localConfig = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
            return try ModelContainer(for: schema, configurations: [localConfig])
        } catch {
            fatalError("Failed to create local ModelContainer: \(error)")
        }
    }
}