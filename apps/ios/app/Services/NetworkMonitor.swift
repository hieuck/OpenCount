import Foundation
import Network
import SwiftUI

// MARK: - NetworkMonitor

/// Observes device connectivity state and drives offline-mode UI.
///
/// Injected as an `@EnvironmentObject` at the root so all views can react
/// to connectivity changes. The offline banner is a `safeAreaInset(edge: .top)`
/// overlay that animates in/out.
///
/// Requirement 33.1–33.6
final class NetworkMonitor: ObservableObject {

    // MARK: - Published state

    /// Whether the device currently has a network connection.
    @Published var isConnected: Bool = true

    /// The type of the current connection.
    @Published var connectionType: ConnectionType = .unknown

    // MARK: - Connection type

    enum ConnectionType {
        case wifi
        case cellular
        case unknown
        case none
    }

    // MARK: - Private

    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "com.opencount.networkmonitor", qos: .utility)

    // MARK: - Init / deinit

    init() {
        start()
    }

    deinit {
        stop()
    }

    // MARK: - Lifecycle

    /// Starts monitoring network path changes.
    func start() {
        monitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                self?.isConnected = path.status == .satisfied
                self?.connectionType = Self.connectionType(from: path)
            }
        }
        monitor.start(queue: queue)
    }

    /// Stops monitoring.
    func stop() {
        monitor.cancel()
    }

    // MARK: - Private helpers

    private static func connectionType(from path: NWPath) -> ConnectionType {
        if path.status != .satisfied { return .none }
        if path.usesInterfaceType(.wifi) { return .wifi }
        if path.usesInterfaceType(.cellular) { return .cellular }
        return .unknown
    }
}

// MARK: - OfflineBanner

/// A non-intrusive banner shown at the top of the screen when the device is offline.
/// Animates in when `isConnected == false` and auto-dismisses on reconnect.
///
/// Requirement 33.2
struct OfflineBanner: View {

    @EnvironmentObject private var networkMonitor: NetworkMonitor

    var body: some View {
        if !networkMonitor.isConnected {
            HStack(spacing: 8) {
                Image(systemName: "wifi.slash")
                    .font(.caption.bold())
                    .accessibilityHidden(true)
                Text("You're offline — core features still work")
                    .font(.caption.bold())
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(Color.orange)
                    .shadow(radius: 4)
            )
            .padding(.top, 4)
            .transition(.move(edge: .top).combined(with: .opacity))
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: networkMonitor.isConnected)
            .accessibilityLabel("Offline mode. Core features still work without internet.")
        }
    }
}

// MARK: - OfflineFeatureAlert

/// A view modifier that shows an alert when a network-dependent feature is accessed offline.
///
/// Requirement 33.4
@available(iOS 16.0, *)
struct OfflineFeatureAlert: ViewModifier {

    @EnvironmentObject private var networkMonitor: NetworkMonitor
    @Binding var isPresented: Bool
    let featureName: String

    func body(content: Content) -> some View {
        content
            .alert("\(featureName) Requires Internet", isPresented: $isPresented) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("\(featureName) is not available while offline. Please connect to the internet and try again.")
            }
            .onChange(of: isPresented) { newValue in
                if newValue && !networkMonitor.isConnected {
                    // Keep alert open — feature is blocked
                } else if newValue && networkMonitor.isConnected {
                    // Feature is available — dismiss the offline alert
                    isPresented = false
                }
            }
    }
}

extension View {
    /// Shows an offline alert when the user tries to access a network-dependent feature.
    func offlineFeatureAlert(isPresented: Binding<Bool>, featureName: String) -> some View {
        modifier(OfflineFeatureAlert(isPresented: isPresented, featureName: featureName))
    }
}
