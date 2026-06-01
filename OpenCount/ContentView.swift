import SwiftUI
import SwiftData

/// Root view of the app. Injects a `StorageService` backed by the SwiftData `ModelContext`
/// from the environment and presents the appropriate navigation structure:
///
/// - **iPad (regular horizontal size class)**: `NavigationSplitView` with the session list
///   in the sidebar and `CountingView` in the detail column. (Requirement 31.1)
/// - **iPhone (compact horizontal size class)**: `NavigationStack`-based `SessionListView`.
///
/// On first launch, shows `OnboardingView` as a full-screen cover until the user
/// completes or skips the onboarding flow.  Also seeds the bundled sample session
/// on first launch via `SampleSessionSeeder`.
///
/// Requirements: 10.2, 10.3, 10.5, 16.1, 16.2, 16.3, 16.4, 27.1–27.4, 29.5, 31.1, 31.2, 31.7
struct ContentView: View {

    @Environment(\.modelContext) private var modelContext
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    /// Persisted flag — `false` on first launch, set to `true` after onboarding.
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding: Bool = false

    /// Session UUID received from a deep-link URL (`opencount://session/<id>`).
    /// When non-nil, `SessionListView` navigates directly to the corresponding session.
    /// Requirement 27.1–27.4
    @Binding var deepLinkedSessionID: UUID?

    /// iPad layout coordinator — manages column visibility and active annotation tool.
    /// Requirement 31.2: iPadLayoutCoordinator managing column visibility.
    @StateObject private var iPadCoordinator = iPadLayoutCoordinator()

    /// The session selected in the sidebar (iPad split view only).
    @State private var selectedSession: CountSession? = nil

    init(deepLinkedSessionID: Binding<UUID?> = .constant(nil)) {
        _deepLinkedSessionID = deepLinkedSessionID
    }

    var body: some View {
        Group {
            if horizontalSizeClass == .regular {
                // iPad / regular width: NavigationSplitView — Requirement 31.1
                iPadSplitView
            } else {
                // iPhone / compact width: NavigationStack
                iPhoneStackView
            }
        }
        .fullScreenCover(
            isPresented: Binding(
                get: { !hasSeenOnboarding },
                set: { _ in }
            )
        ) {
            OnboardingView()
        }
        .onAppear {
            // Seed the sample session on first launch — Requirement 29.5
            SampleSessionSeeder.seedIfNeeded(into: modelContext)
        }
    }

    // MARK: - iPad split view (Requirement 31.1)

    /// `NavigationSplitView` with session list in the sidebar and `CountingView` in the
    /// detail column. The `iPadLayoutCoordinator` manages column visibility.
    ///
    /// Stage Manager support: the window scene uses `.automatic` activation conditions
    /// so the app participates in Stage Manager on iPadOS 16+. (Requirement 31.7)
    private var iPadSplitView: some View {
        NavigationSplitView(columnVisibility: $iPadCoordinator.columnVisibility) {
            // Sidebar: session list
            SessionListView(
                storage: StorageService(context: modelContext),
                deepLinkedSessionID: $deepLinkedSessionID,
                selectedSession: $selectedSession
            )
            .navigationSplitViewColumnWidth(min: 280, ideal: 320, max: 400)
        } detail: {
            // Detail column: counting view for the selected session, or placeholder
            if let session = selectedSession {
                CountingView(session: session)
                    .environmentObject(iPadCoordinator)
            } else {
                iPadDetailPlaceholder
            }
        }
        .environmentObject(iPadCoordinator)
        // Stage Manager: allow the window to be resized freely — Requirement 31.7
        .onAppear {
            configureWindowScene()
        }
    }

    // MARK: - iPhone stack view

    private var iPhoneStackView: some View {
        SessionListView(
            storage: StorageService(context: modelContext),
            deepLinkedSessionID: $deepLinkedSessionID
        )
    }

    // MARK: - iPad detail placeholder

    private var iPadDetailPlaceholder: some View {
        VStack(spacing: 16) {
            Image(systemName: "sidebar.left")
                .font(.system(size: 56))
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            Text("Select a Session")
                .font(.title2)
                .fontWeight(.semibold)
            Text("Choose a counting session from the sidebar to get started.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
        .accessibilityElement(children: .combine)
    }

    // MARK: - Stage Manager (Requirement 31.7)

    /// Configures the window scene activation conditions to support Stage Manager.
    /// On iPadOS 16+, this allows the app window to be freely resized and tiled.
    private func configureWindowScene() {
        #if !targetEnvironment(macCatalyst)
        guard let windowScene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first else { return }

        // Allow the scene to be activated in any size — supports Stage Manager
        let conditions = UISceneActivationConditions()
        windowScene.activationConditions = conditions
        #endif
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [CountSession.self, ObjectType.self, CountMarker.self,
                               CountRegion.self, SessionImage.self, VideoFrameCount.self],
                        inMemory: true)
}
