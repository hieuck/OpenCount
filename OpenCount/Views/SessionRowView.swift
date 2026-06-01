import SwiftUI

/// A single row in the session list, showing thumbnail, name, description,
/// modified date, marker count, object type chips, and a 7-day activity sparkline.
/// Supports a context menu with Duplicate and Delete actions.
///
/// Requirement 47 (Req 36): sparkline showing counting activity over the last 7 days.
struct SessionRowView: View {

    let session: CountSession
    let onDuplicate: () -> Void
    let onDelete: () -> Void

    // MARK: - Thumbnail

    @State private var thumbnail: UIImage?

    // MARK: - Formatted values

    private var formattedDate: String {
        session.modifiedAt.formatted(date: .abbreviated, time: .shortened)
    }

    private var markerCount: Int {
        session.markers.count
    }

    private var objectTypes: [ObjectType] {
        Array(session.objectTypes.sorted { $0.sortOrder < $1.sortOrder }.prefix(3))
    }

    // MARK: - Body

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Thumbnail
            thumbnailView

            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(session.name)
                            .font(.headline)
                            .foregroundStyle(.primary)
                            .accessibilityLabel("Session name: \(session.name)")

                        if let description = session.sessionDescription, !description.isEmpty {
                            Text(description)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .accessibilityLabel("Description: \(description)")
                        }
                    }
                    Spacer()
                    // 7-day activity sparkline — Requirement 47 (Req 36)
                    SparklineView(session: session)
                        .padding(.top, 2)
                }

                // Object type chips
                if !objectTypes.isEmpty {
                    HStack(spacing: 6) {
                        ForEach(objectTypes) { type in
                            objectTypeChip(type)
                        }
                        if session.objectTypes.count > 3 {
                            Text("+\(session.objectTypes.count - 3)")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color(.tertiarySystemBackground), in: Capsule())
                        }
                    }
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

                    if !session.images.isEmpty {
                        Label("\(session.images.count)", systemImage: "photo")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .accessibilityLabel("\(session.images.count) images")
                    }
                }
            }
        }
        .padding(.vertical, 4)
        .onAppear { loadThumbnail() }
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

    // MARK: - Thumbnail view

    @ViewBuilder
    private var thumbnailView: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(.secondarySystemBackground))
                .frame(width: 52, height: 52)

            if let thumb = thumbnail {
                Image(uiImage: thumb)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 52, height: 52)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            } else if session.images.isEmpty {
                Image(systemName: "hand.tap")
                    .font(.title3)
                    .foregroundStyle(.tertiary)
            } else {
                Image(systemName: "photo")
                    .font(.title3)
                    .foregroundStyle(.tertiary)
            }
        }
        .accessibilityHidden(true)
    }

    // MARK: - Object type chip

    private func objectTypeChip(_ type: ObjectType) -> some View {
        HStack(spacing: 3) {
            Circle()
                .fill(Color(hex: type.colorHex) ?? .accentColor)
                .frame(width: 6, height: 6)
            Text(type.name)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(Color(.tertiarySystemBackground), in: Capsule())
    }

    // MARK: - Thumbnail loading

    private func loadThumbnail() {
        guard let firstImage = session.images.sorted(by: { $0.importedAt < $1.importedAt }).first else {
            return
        }
        let imagesDir = FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("images")
            .appendingPathComponent(session.id.uuidString)

        if let thumbName = firstImage.thumbnailFilename {
            let thumbURL = imagesDir.appendingPathComponent(thumbName)
            if let img = UIImage(contentsOfFile: thumbURL.path) {
                thumbnail = img
                return
            }
        }
        let fullURL = imagesDir.appendingPathComponent(firstImage.filename)
        if let img = UIImage(contentsOfFile: fullURL.path) {
            thumbnail = img.preparingThumbnail(of: CGSize(width: 52, height: 52))
        }
    }
}
