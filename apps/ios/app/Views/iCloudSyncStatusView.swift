import SwiftUI

/// A small toolbar view that reflects the current iCloud sync status.
///
/// Requirement 15.4
struct iCloudSyncStatusView: View {

    let status: iCloudSyncStatus

    var body: some View {
        Group {
            switch status {
            case .idle:
                Image(systemName: "icloud")
                    .foregroundStyle(.secondary)
                    .accessibilityLabel("iCloud sync idle")

            case .syncing:
                ProgressView()
                    .accessibilityLabel("iCloud sync in progress")

            case .synced(let date):
                Image(systemName: "checkmark.icloud")
                    .foregroundStyle(.green)
                    .accessibilityLabel("iCloud sync complete at \(date.formatted(date: .omitted, time: .shortened))")

            case .failed(let message):
                Image(systemName: "exclamationmark.icloud")
                    .foregroundStyle(.red)
                    .accessibilityLabel("iCloud sync failed: \(message)")
            }
        }
        .imageScale(.medium)
    }
}

#Preview {
    HStack(spacing: 20) {
        iCloudSyncStatusView(status: .idle)
        iCloudSyncStatusView(status: .syncing)
        iCloudSyncStatusView(status: .synced(Date()))
        iCloudSyncStatusView(status: .failed("Network unavailable"))
    }
    .padding()
}
