import SwiftUI

struct ContentView: View {

    @EnvironmentObject private var appState: AppState
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding: Bool = false
    @Binding var deepLinkedSessionID: UUID?
    @StateObject private var iPadCoordinator = iPadLayoutCoordinator()
    @State private var selectedSession: CountSession? = nil
    @State private var showCounter: Bool = true

    init(deepLinkedSessionID: Binding<UUID?> = .constant(nil)) {
        _deepLinkedSessionID = deepLinkedSessionID
    }

    var body: some View {
        ZStack {
            if showCounter {
                SimpleCounterView()
            } else {
                if horizontalSizeClass == .regular {
                    iPadSplitView
                } else {
                    iPhoneStackView
                }
            }
        }
        .overlay(alignment: .topLeading) {
            if showCounter {
                Button(action: { showCounter = false }) {
                    Label("Sessions", systemImage: "list.bullet").font(.caption).padding(8)
                        .background(.ultraThinMaterial).cornerRadius(8)
                }.padding(12)
            } else {
                Button(action: { showCounter = true }) {
                    Label("Quick Count", systemImage: "plus.circle").font(.caption).padding(8)
                        .background(.ultraThinMaterial).cornerRadius(8)
                }.padding(12)
            }
        }
        .overlay(alignment: .topTrailing) {
            if showCounter {
                Button(action: {}) {
                    Image(systemName: "gearshape").font(.caption).padding(8)
                        .background(.ultraThinMaterial).cornerRadius(8)
                }.padding(12)
            }
        }
        .fullScreenCover(isPresented: Binding(
            get: { !hasSeenOnboarding },
            set: { _ in }
        )) {
            OnboardingView()
        }
    }

    private var iPadSplitView: some View {
        NavigationSplitView(columnVisibility: $iPadCoordinator.columnVisibility) {
            SessionListView(
                storage: StorageService.shared,
                deepLinkedSessionID: $deepLinkedSessionID,
                selectedSession: $selectedSession
            )
            .navigationSplitViewColumnWidth(min: 280, ideal: 320, max: 400)
        } detail: {
            if let session = selectedSession {
                CountingView(session: session)
                    .environmentObject(iPadCoordinator)
            } else {
                iPadPlaceholder
            }
        }
        .environmentObject(iPadCoordinator)
    }

    private var iPhoneStackView: some View {
        SessionListView(
            storage: StorageService.shared,
            deepLinkedSessionID: $deepLinkedSessionID
        )
    }

    private var iPadPlaceholder: some View {
        VStack(spacing: 16) {
            Image(systemName: "sidebar.left")
                .font(.system(size: 56))
                .foregroundStyle(.secondary)
            Text("Select a Session")
                .font(.title2).fontWeight(.semibold)
            Text("Choose a counting session from the sidebar to get started.")
                .font(.body).foregroundStyle(.secondary)
                .multilineTextAlignment(.center).padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
    }
}

#Preview {
    ContentView()
        .environmentObject(AppState())
        .environmentObject(iCloudSyncViewModel())
        .environmentObject(NetworkMonitor())
}
