import SwiftUI

// MARK: - CollaborationView

/// Sheet for starting/stopping a collaborative counting session.
/// Shows a shareable link and live collaborator count.
///
/// Requirements: 28.1–28.6
struct CollaborationView: View {

    let session: CountSession
    @ObservedObject var viewModel: CountingViewModel
    @ObservedObject private var collaborationService = CollaborationService.shared
    @Environment(\.dismiss) private var dismiss

    @State private var shareLink: URL?
    @State private var isCopied: Bool = false

    var body: some View {
        NavigationStack {
            Form {
                // MARK: Status section
                Section {
                    HStack {
                        Image(systemName: collaborationService.isCollaborating
                              ? "person.2.fill" : "person.2")
                            .foregroundStyle(collaborationService.isCollaborating ? .green : .secondary)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(collaborationService.isCollaborating
                                 ? "Collaboration Active"
                                 : "Collaboration Off")
                                .font(.headline)
                            if collaborationService.isCollaborating {
                                Text("\(collaborationService.collaboratorCount) remote participant(s)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                        Toggle("", isOn: Binding(
                            get: { collaborationService.isCollaborating },
                            set: { enabled in
                                Task {
                                    if enabled {
                                        await collaborationService.startCollaboration(
                                            sessionID: session.id,
                                            onMarkersReceived: { _ in }
                                        )
                                        shareLink = collaborationService.shareLink(for: session.id)
                                        viewModel.isCollaborating = true
                                    } else {
                                        await collaborationService.stopCollaboration()
                                        viewModel.isCollaborating = false
                                    }
                                }
                            }
                        ))
                        .labelsHidden()
                    }
                } header: {
                    Text("Real-Time Collaboration")
                } footer: {
                    Text("When enabled, other devices can join this session and count simultaneously. Markers are merged in real time.")
                }

                // MARK: Share link section
                if collaborationService.isCollaborating, let link = shareLink {
                    Section {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(link.absoluteString)
                                .font(.caption.monospaced())
                                .foregroundStyle(.secondary)
                                .lineLimit(2)

                            HStack(spacing: 12) {
                                Button {
                                    UIPasteboard.general.string = link.absoluteString
                                    withAnimation { isCopied = true }
                                    Task {
                                        try? await Task.sleep(nanoseconds: 2_000_000_000)
                                        await MainActor.run {
                                            withAnimation { isCopied = false }
                                        }
                                    }
                                } label: {
                                    Label(isCopied ? "Copied!" : "Copy Link",
                                          systemImage: isCopied ? "checkmark.circle.fill" : "doc.on.clipboard")
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.bordered)
                                .tint(isCopied ? .green : .blue)

                                ShareLink(item: link) {
                                    Label("Share", systemImage: "square.and.arrow.up")
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.borderedProminent)
                            }
                        }
                        .padding(.vertical, 4)
                    } header: {
                        Text("Invite Link")
                    } footer: {
                        Text("Share this link with collaborators. They can open it to join this counting session.")
                    }

                    // MARK: Sync status
                    Section {
                        HStack {
                            Text("Sync Status")
                            Spacer()
                            syncStatusView
                        }

                        Button {
                            Task {
                                let merged = await collaborationService.fetchRemoteMarkers(
                                    sessionID: session.id,
                                    existingMarkers: viewModel.markers,
                                    objectTypes: session.objectTypes
                                )
                                // Add any new remote markers
                                let existingIDs = Set(viewModel.markers.map { $0.id })
                                for marker in merged where !existingIDs.contains(marker.id) {
                                    viewModel.markers.append(marker)
                                    session.markers.append(marker)
                                }
                                session.modifiedAt = Date()
                            }
                        } label: {
                            Label("Sync Now", systemImage: "arrow.triangle.2.circlepath")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                    } header: {
                        Text("Synchronisation")
                    }
                }

                // MARK: How it works
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        featureRow(icon: "person.2.fill", color: .blue,
                                   title: "Multiple Counters",
                                   detail: "Up to 10 people can count simultaneously")
                        featureRow(icon: "arrow.triangle.2.circlepath", color: .green,
                                   title: "Real-Time Sync",
                                   detail: "Markers appear on all devices instantly")
                        featureRow(icon: "checkmark.shield.fill", color: .orange,
                                   title: "Conflict-Free",
                                   detail: "Union merge — no markers are ever lost")
                        featureRow(icon: "wifi.slash", color: .gray,
                                   title: "Offline Resilient",
                                   detail: "Syncs automatically when reconnected")
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text("How It Works")
                }
            }
            .navigationTitle("Collaboration")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    // MARK: - Helpers

    @ViewBuilder
    private var syncStatusView: some View {
        switch collaborationService.syncStatus {
        case .idle:
            Text("Idle").foregroundStyle(.secondary)
        case .syncing:
            HStack(spacing: 4) {
                ProgressView().scaleEffect(0.7)
                Text("Syncing…").foregroundStyle(.secondary)
            }
        case .synced(let date):
            Text("Synced \(date.formatted(.relative(presentation: .named)))")
                .foregroundStyle(.green)
        case .failed(let msg):
            Text("Failed: \(msg)").foregroundStyle(.red).lineLimit(1)
        }
    }

    private func featureRow(icon: String, color: Color, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(color)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline).fontWeight(.medium)
                Text(detail).font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}
