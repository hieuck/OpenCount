import SwiftUI

/// A single row in the session list, showing name, description, modified date, marker count,
/// and a 7-day activity sparkline.
/// Supports a context menu with Duplicate and Delete actions.
///
/// Requirement 47 (Req 36): sparkline showing counting activity over the last 7 days.
struct SessionRowView: View {

    let session: CountSession
    let onDuplicate: () -> Void
    let onDelete: () -> Void

    // MARK: - Formatted values

    private var formattedDate: String {
        session.modifiedAt.formatted(date: .abbreviated, time: .shortened)
    }

    private var markerCount: Int {
        session.markers.count
    }

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(session.name)
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .accessibilityLabel("Session name: \(session.name)")

                    if let description = session.sessionDescription, !description.isEmpty {
                        Text(description)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                            .accessibilityLabel("Description: \(description)")
                    }
                }
                Spacer()
                // 7-day activity sparkline — Requirement 47 (Req 36)
                SparklineView(session: session)
                    .padding(.top, 2)
            }

            HStack(spacing: 12) {
                Label(formattedDate, systemImage: "clock")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .accessibilityLabel("Last modified \(formattedDate)")

                Label("\(markerCount)", systemImage: "mappin.circle")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .accessibilityLabel("\(markerCount) markers")
            }
        }
        .padding(.vertical, 4)
        .contextMenu {
            Button {
                onDuplicate()
            } label: {
                Label("Duplicate", systemImage: "doc.on.doc")
            }
            .accessibilityLabel("Duplicate session \(session.name)")

            Divider()

            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("Delete", systemImage: "trash")
            }
            .accessibilityLabel("Delete session \(session.name)")
        }
    }
}
