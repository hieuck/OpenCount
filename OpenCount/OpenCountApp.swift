import SwiftUI
import AppIntents

@main
struct OpenCountApp: App {

    @StateObject private var syncViewModel   = iCloudSyncViewModel()
    @StateObject private var networkMonitor  = NetworkMonitor()
    @StateObject private var localAPIServer  = LocalAPIServer()
    @StateObject private var appState        = AppState()
    @StateObject private var aiService       = CoreMLAIService()

    @Environment(\.scenePhase) private var scenePhase

    @State private var isShowingCrashConsent: Bool = false
    @State private var pendingCrashDescription: String = ""
    @AppStorage("localAPIServerEnabled") private var localAPIServerEnabled: Bool = false
    @State private var deepLinkedSessionID: UUID? = nil

    var body: some Scene {
        WindowGroup {
            ContentView(deepLinkedSessionID: $deepLinkedSessionID)
                .environmentObject(syncViewModel)
                .environmentObject(networkMonitor)
                .environmentObject(appState)
                .environmentObject(aiService)
                .onContinueUserActivity("com.opencount.counting") { activity in
                    if let s = activity.userInfo?["sessionID"] as? String,
                       let uuid = UUID(uuidString: s) {
                        deepLinkedSessionID = uuid
                    }
                }
                .safeAreaInset(edge: .top, spacing: 0) {
                    OfflineBanner()
                        .environmentObject(networkMonitor)
                        .animation(.spring(response: 0.4, dampingFraction: 0.8),
                                   value: networkMonitor.isConnected)
                }
                .sheet(isPresented: $isShowingCrashConsent) {
                    CrashReportConsentView(
                        crashDescription: pendingCrashDescription,
                        onConsent: {
                            Task { try? await FeedbackService.shared.submitCrashReport(
                                pendingCrashDescription, userConsented: true) }
                            isShowingCrashConsent = false
                        },
                        onDecline: { isShowingCrashConsent = false }
                    )
                }
                .onAppear {
                    if CommandLine.arguments.contains("--skip-onboarding") {
                        UserDefaults.standard.set(true, forKey: "hasSeenOnboarding")
                    }
                    if FeedbackService.shared.hasPendingCrashReport,
                       let desc = FeedbackService.shared.getPendingCrashDescription() {
                        pendingCrashDescription = desc
                        isShowingCrashConsent = true
                    }
                    // Seed sample session on first launch
                    Task { await appState.seedSampleIfNeeded() }
                    // Warm-up AI model on app launch for faster first inference
                    Task { await aiService.warmUp() }
                }
                .onOpenURL { url in handleDeepLink(url) }
        }
        .onChange(of: scenePhase) { newPhase in
            if newPhase == .background { appState.saveAll() }
            if newPhase == .active && localAPIServerEnabled && !localAPIServer.isRunning {
                localAPIServer.start(storage: StorageService.shared)
            }
        }
        .onChange(of: localAPIServerEnabled) { enabled in
            if enabled { localAPIServer.start(storage: StorageService.shared) }
            else { localAPIServer.stop() }
        }
    }

    private func handleDeepLink(_ url: URL) {
        guard url.scheme?.lowercased() == "opencount",
              url.host?.lowercased() == "session",
              let idStr = url.pathComponents.filter({ $0 != "/" }).first,
              let uuid = UUID(uuidString: idStr) else { return }
        deepLinkedSessionID = uuid
    }
}

// MARK: - AppState

/// Central observable state holder — replaces SwiftData ModelContainer.
@MainActor
final class AppState: ObservableObject {
    @Published var sessions: [CountSession] = []
    private let storage = StorageService.shared

    init() {
        Task { await load() }
    }

    func load() async {
        sessions = (try? await storage.fetchAllSessions()) ?? []
    }

    func saveAll() {
        for session in sessions {
            Task { try? await storage.save(session) }
        }
    }

    func save(_ session: CountSession) {
        Task { try? await storage.save(session) }
    }

    func delete(_ session: CountSession) {
        sessions.removeAll { $0.id == session.id }
        Task { try? await storage.delete(session) }
    }

    func seedSampleIfNeeded() async {
        guard !UserDefaults.standard.bool(forKey: "sampleSeeded") else { return }
        let all = (try? await storage.fetchAllSessions()) ?? []
        if all.isEmpty {
            SampleSessionSeeder.seed(into: self)
            UserDefaults.standard.set(true, forKey: "sampleSeeded")
        }
        await load()
    }
}
