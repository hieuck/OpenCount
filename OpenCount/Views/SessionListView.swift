import SwiftUI
import SwiftData

/// The root screen of the app. Displays all counting sessions sorted by most-recently-modified
/// date descending, with a search bar and controls to create, duplicate, and delete sessions.
///
/// Requirements: 1.1, 1.4, 1.5, 1.6, 1.8, 15.4, 16.6
struct SessionListView: View {

    // MARK: - Environment

    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var syncViewModel: iCloudSyncViewModel
    @EnvironmentObject private var networkMonitor: NetworkMonitor

    // MARK: - ViewModel

    @StateObject private var viewModel: SessionListViewModel

    // MARK: - Local UI state

    @State private var isShowingNewSessionSheet = false
    @State private var sessionToDelete: CountSession?
    @State private var isShowingDeleteConfirmation = false
    @State private var isSettingsPresented: Bool = false
    @State private var isShowingTemplateGallery: Bool = false

    /// Session UUID received from a deep-link URL (`opencount://session/<id>`).
    /// When set, the NavigationStack navigates directly to the corresponding CountingView.
    /// Requirement 27.1–27.4
    @Binding private var deepLinkedSessionID: UUID?

    /// The session resolved from `deepLinkedSessionID`, used as the NavigationStack path.
    @State private var navigationPath: [CountSession] = []

    /// The currently selected session for the iPad `NavigationSplitView` detail column.
    /// When non-nil, the split view shows `CountingView` for this session.
    /// Requirement 31.1: session list in sidebar drives detail column selection.
    @Binding private var selectedSession: CountSession?

    // MARK: - Init

    init(
        storage: StorageServiceProtocol,
        deepLinkedSessionID: Binding<UUID?> = .constant(nil),
        selectedSession: Binding<CountSession?> = .constant(nil)
    ) {
        _viewModel = StateObject(wrappedValue: SessionListViewModel(storage: storage))
        _deepLinkedSessionID = deepLinkedSessionID
        _selectedSession = selectedSession
    }

    // MARK: - Body

    var body: some View {
        NavigationStack(path: $navigationPath) {
            Group {
                if viewModel.filteredSessions.isEmpty {
                    emptyStateView
                } else {
                    sessionList
                }
            }
            .navigationTitle("Sessions")
            .searchable(
                text: $viewModel.searchQuery,
                placement: .navigationBarDrawer(displayMode: .always),
                prompt: "Search sessions"
            )
            .toolbar {
                // iCloud sync status indicator — Requirement 15.4
                ToolbarItem(placement: .navigationBarLeading) {
                    HStack(spacing: 8) {
                        iCloudSyncStatusView(status: syncViewModel.syncStatus)
                        // Settings button — Requirement 17.1
                        Button {
                            isSettingsPresented = true
                        } label: {
                            Image(systemName: "gear")
                        }
                        .accessibilityLabel("Settings")
                        .accessibilityHint("Open app settings.")
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        isShowingNewSessionSheet = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("New session")
                    .accessibilityHint("Create a new counting session.")
                    // Keyboard shortcut ⌘N — Requirement 31.6
                    .keyboardShortcut("n", modifiers: .command)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        isShowingTemplateGallery = true
                    } label: {
                        Image(systemName: "square.stack.3d.up")
                    }
                    .accessibilityLabel("Template Gallery")
                    .accessibilityHint("Browse and install community Object Type templates.")
                }
            }
            .sheet(isPresented: $isShowingNewSessionSheet) {
                NewSessionSheet { name, description, _ in
                    Task {
                        try? await viewModel.createSession(name: name, description: description)
                    }
                }
            }
            // Settings sheet — Requirements 17.1–17.5
            .sheet(isPresented: $isSettingsPresented) {
                SettingsView()
                    .environmentObject(syncViewModel)
            }
            // Template Gallery — Requirement 26.1–26.6
            .sheet(isPresented: $isShowingTemplateGallery) {
                TemplateGalleryView(targetSession: nil)
                    .environmentObject(networkMonitor)
            }
            // Confirmation alert before deleting — Requirements 1.4, 16.6
            .alert(
                deleteAlertTitle,
                isPresented: $isShowingDeleteConfirmation,
                presenting: sessionToDelete
            ) { session in
                Button("Delete", role: .destructive) {
                    Task {
                        try? await viewModel.deleteSession(session)
                    }
                }
                .accessibilityLabel("Confirm delete \(session.name)")

                Button("Cancel", role: .cancel) {
                    sessionToDelete = nil
                }
                .accessibilityLabel("Cancel delete")
            } message: { session in
                Text("Are you sure you want to delete '\(session.name)'? This cannot be undone.")
            }
        }
        .task {
            await viewModel.loadSessions()
        }
        // Handle deep-link navigation — Requirement 27.1–27.4
        .onChange(of: deepLinkedSessionID) { _, newID in
            guard let id = newID else { return }
            // Find the session in the loaded list and push it onto the navigation stack
            if let session = viewModel.filteredSessions.first(where: { $0.id == id }) {
                navigationPath = [session]
                deepLinkedSessionID = nil
            } else {
                // Sessions may not be loaded yet; load them first then navigate
                Task {
                    await viewModel.loadSessions()
                    if let session = viewModel.filteredSessions.first(where: { $0.id == id }) {
                        navigationPath = [session]
                    }
                    deepLinkedSessionID = nil
                }
            }
        }
    }

    // MARK: - Subviews

    private var sessionList: some View {
        List(selection: $selectedSession) {
            ForEach(viewModel.filteredSessions) { session in
                NavigationLink(value: session) {
                    SessionRowView(
                        session: session,
                        onDuplicate: {
                            Task {
                                try? await viewModel.duplicateSession(session)
                            }
                        },
                        onDelete: {
                            sessionToDelete = session
                            isShowingDeleteConfirmation = true
                        }
                    )
                }
                .accessibilityLabel("Session: \(session.name)")
                // Also update the split-view selectedSession binding when tapped
                .simultaneousGesture(TapGesture().onEnded {
                    selectedSession = session
                })
            }
            .onDelete { indexSet in
                // Swipe-to-delete: show confirmation for the first session in the set
                if let index = indexSet.first {
                    sessionToDelete = viewModel.filteredSessions[index]
                    isShowingDeleteConfirmation = true
                }
            }
        }
        .listStyle(.insetGrouped)
        // NavigationStack destination — CountingView (Task 8)
        .navigationDestination(for: CountSession.self) { session in
            CountingView(session: session)
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "tray")
                .font(.system(size: 56))
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)

            if viewModel.searchQuery.isEmpty {
                Text("No Sessions Yet")
                    .font(.title2)
                    .fontWeight(.semibold)
                Text("Tap + to create your first counting session.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            } else {
                Text("No Results")
                    .font(.title2)
                    .fontWeight(.semibold)
                Text("No sessions match "\(viewModel.searchQuery)".")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding()
        .accessibilityElement(children: .combine)
    }

    // MARK: - Helpers

    private var deleteAlertTitle: String {
        "Delete Session"
    }
}


#Preview {
    // Preview with an in-memory storage stub
    SessionListView(storage: PreviewStorageService())
        .environmentObject(iCloudSyncViewModel())
        .environmentObject(NetworkMonitor())
        .modelContainer(for: [CountSession.self, ObjectType.self, CountMarker.self,
                               CountRegion.self, SessionImage.self, VideoFrameCount.self],
                        inMemory: true)
}

// MARK: - Preview helper

private final class PreviewStorageService: StorageServiceProtocol {
    func save(_ session: CountSession) async throws {}
    func delete(_ session: CountSession) async throws {}
    func fetchAllSessions() async throws -> [CountSession] {
        [
            CountSession(name: "Bird Survey", sessionDescription: "Counting birds in the park", modifiedAt: Date()),
            CountSession(name: "Inventory Check", sessionDescription: nil, modifiedAt: Date().addingTimeInterval(-3600)),
        ]
    }
    func fetchSessions(matching query: String) async throws -> [CountSession] {
        try await fetchAllSessions()
    }
}
