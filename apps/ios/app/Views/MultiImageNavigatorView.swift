import SwiftUI

// MARK: - MultiImageNavigatorView

/// A horizontal thumbnail strip that lets the user switch between multiple
/// images in a session. Shown at the bottom of CountingView when the session
/// has more than one image.
///
/// Tapping a thumbnail loads that image into the counting canvas.
struct MultiImageNavigatorView: View {

    let session: CountSession
    @ObservedObject var viewModel: CountingViewModel

    private var images: [SessionImage] {
        session.images.sorted { $0.importedAt < $1.importedAt }
    }

    var body: some View {
        if images.count > 1 {
            VStack(spacing: 0) {
                Divider()
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(images.indices, id: \.self) { index in
                            let sessionImage = images[index]
                            ThumbnailCell(
                                sessionImage: sessionImage,
                                sessionID: session.id,
                                isSelected: viewModel.currentImageIndex == index
                            )
                            .onTapGesture {
                                viewModel.selectImage(at: index, session: session)
                            }
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                }
                .background(.regularMaterial)
            }
        }
    }
}

// MARK: - ThumbnailCell

private struct ThumbnailCell: View {

    let sessionImage: SessionImage
    let sessionID: UUID
    let isSelected: Bool

    @State private var thumbnail: UIImage?

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(.secondarySystemBackground))
                .frame(width: 56, height: 56)

            if let thumb = thumbnail {
                Image(uiImage: thumb)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 56, height: 56)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                Image(systemName: "photo")
                    .foregroundStyle(.tertiary)
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
        )
        .shadow(color: isSelected ? .accentColor.opacity(0.3) : .clear, radius: 4)
        .onAppear { loadThumbnail() }
        .accessibilityLabel("Image \(sessionImage.filename)")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func loadThumbnail() {
        let imagesDir = FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("images")
            .appendingPathComponent(sessionID.uuidString)

        if let thumbName = sessionImage.thumbnailFilename {
            let thumbURL = imagesDir.appendingPathComponent(thumbName)
            if let img = UIImage(contentsOfFile: thumbURL.path) {
                thumbnail = img
                return
            }
        }
        let fullURL = imagesDir.appendingPathComponent(sessionImage.filename)
        if let img = UIImage(contentsOfFile: fullURL.path) {
            thumbnail = img.preparingThumbnail(of: CGSize(width: 56, height: 56))
        }
    }
}
