import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var appState: AppState
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding: Bool = false
    @Binding var deepLinkedSessionID: UUID?
    @State private var showSessions = false

    init(deepLinkedSessionID: Binding<UUID?> = .constant(nil)) {
        _deepLinkedSessionID = deepLinkedSessionID
    }

    var body: some View {
        SimpleCounterView()
            .overlay(alignment: .topTrailing) {
                Button(action: { showSessions = true }) {
                    Image(systemName: "list.bullet").padding(8).background(.ultraThinMaterial).cornerRadius(8)
                }.padding(8)
            }
            .sheet(isPresented: $showSessions) {
                NavigationStack {
                    SessionListView(storage: StorageService.shared, deepLinkedSessionID: $deepLinkedSessionID)
                        .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { showSessions = false } } }
                }
            }
            .fullScreenCover(isPresented: Binding(get: { !hasSeenOnboarding }, set: { _ in })) {
                OnboardingView()
            }
    }
}
