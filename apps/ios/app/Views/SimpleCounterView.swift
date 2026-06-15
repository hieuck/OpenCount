import SwiftUI
import PhotosUI

/// ZapCount-like flow: pick image → count on image → done
struct SimpleCounterView: View {
    @State private var count: Int = 0
    @State private var markers: [CGPoint] = []
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var image: UIImage?
    @State private var imageSize: CGSize = .zero
    @State private var objectName: String = "Object"
    @State private var showRename: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            // Top bar
            HStack {
                Button(action: { showRename = true }) {
                    HStack(spacing: 4) {
                        Text(objectName).font(.headline)
                        Image(systemName: "pencil").font(.caption2)
                    }
                }
                .buttonStyle(.plain)
                Spacer()
                if image != nil {
                    Text("\(count)").font(.system(size: 40, weight: .bold))
                        .animation(.spring(response: 0.2), value: count)
                }
            }
            .padding(.horizontal, 16).padding(.vertical, 8)

            // Main content
            ZStack {
                if let image = image {
                    // Image canvas with markers
                    GeometryReader { geo in
                        let displayW = geo.size.width
                        let displayH = geo.size.height
                        let scale = min(displayW / imageSize.width, displayH / imageSize.height)
                        let drawW = imageSize.width * scale
                        let drawH = imageSize.height * scale
                        let ox = (displayW - drawW) / 2
                        let oy = (displayH - drawH) / 2

                        ZStack {
                            Image(uiImage: image).resizable().scaledToFit()
                                .frame(width: drawW, height: drawH)
                                .position(x: displayW/2, y: displayH/2)

                            // Markers
                            ForEach(Array(markers.enumerated()), id: \.offset) { i, m in
                                Circle()
                                    .fill(Color.red).frame(width: 18, height: 18)
                                    .overlay(Circle().stroke(.white, lineWidth: 2))
                                    .position(m)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture { loc in
                            // Convert tap to image-normalized coords
                            let nx = (loc.x - ox) / drawW
                            let ny = (loc.y - oy) / drawH
                            guard nx >= 0 && nx <= 1 && ny >= 0 && ny <= 1 else { return }
                            markers.append(loc)
                            count = markers.count
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        }
                    }
                } else {
                    // Empty state: prompt to pick image
                    VStack(spacing: 20) {
                        Image(systemName: "photo.on.rectangle").font(.system(size: 50)).foregroundColor(.secondary)
                        Text("Tap to pick an image").font(.title2).foregroundColor(.secondary)
                        Text("Then tap on objects to count them").font(.body).foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(.systemGray6))
                    .contentShape(Rectangle())
                    .onTapGesture { /* PhotosPicker handles it */ }
                }
            }
            .overlay(alignment: .topTrailing) {
                if count > 0 {
                    Text("\(count)")
                        .font(.system(size: 28, weight: .bold)).foregroundColor(.white)
                        .padding(.horizontal, 16).padding(.vertical, 8)
                        .background(Capsule().fill(Color.blue)).padding(12)
                }
            }

            // Bottom bar (only when image loaded)
            if image != nil {
                HStack(spacing: 16) {
                    Button(action: { if !markers.isEmpty { markers.removeLast(); count = markers.count } }) {
                        Label("Undo", systemImage: "arrow.uturn.backward") }
                    .disabled(markers.isEmpty)

                    Spacer()

                    PhotosPicker(selection: $selectedPhoto, matching: .images) {
                        Label("New Photo", systemImage: "photo")
                    }

                    Spacer()

                    Button(action: { markers.removeAll(); count = 0 }) {
                        Label("Clear", systemImage: "trash") }
                    .disabled(markers.isEmpty)

                    Spacer()

                    Button(action: shareCount) {
                        Label("Share", systemImage: "square.and.arrow.up")
                    }
                    .disabled(count == 0)
                }
                .padding(.horizontal, 16).padding(.vertical, 10)
                .background(Color(.systemBackground))
            }
        }
        .onChange(of: selectedPhoto) { _ in loadPhoto() }
        .alert("Rename", isPresented: $showRename) {
            TextField("Name", text: $objectName)
            Button("OK") { if objectName.isEmpty { objectName = "Object" } }
            Button("Cancel", role: .cancel) {}
        } message: { Text("What are you counting?") }
    }

    private func shareCount() {
        let text = "\(objectName): \(count)"
        let av = UIActivityViewController(activityItems: [text], applicationActivities: nil)
        if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let root = scene.windows.first?.rootViewController {
            root.present(av, animated: true)
        }
    }

    private func loadPhoto() {
        guard let item = selectedPhoto else { return }
        Task {
            if let data = try? await item.loadTransferable(type: Data.self),
               let uiImage = UIImage(data: data) {
                image = uiImage
                imageSize = uiImage.size
                markers.removeAll()
                count = 0
            }
        }
    }
}
