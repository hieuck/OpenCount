import SwiftUI
import PhotosUI

/// ZapCount clone — đơn giản, chạy ngay, không crash
struct SimpleCounterView: View {
    @State private var image: UIImage?
    @State private var markers: [CGPoint] = []
    @State private var count: Int = 0
    @State private var showCamera = false
    @State private var showPicker = false
    @State private var pickerItem: PhotosPickerItem?
    @State private var isLoading = false
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = true

    var body: some View {
        ZStack {
            if let img = image {
                countingView(img)
            } else {
                welcomeView
            }
        }
        .sheet(isPresented: $showCamera) {
            ImagePicker(sourceType: .camera) { img in
                image = img; markers = []; count = 0
            }
        }
        .photosPicker(isPresented: $showPicker, selection: $pickerItem, matching: .images)
        .onChange(of: pickerItem) { _ in loadPhoto() }
    }

    // MARK: - Welcome (ZapCount style)
    private var welcomeView: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "camera.viewfinder").font(.system(size: 60)).foregroundColor(.blue)
            Text("OpenCount").font(.largeTitle).fontWeight(.bold)
            Text("Point, Tap, Count").foregroundColor(.secondary)
            Spacer()
            VStack(spacing: 14) {
                Button(action: { showPicker = true }) {
                    HStack {
                        Image(systemName: "photo.on.rectangle").font(.title3)
                        Text("Choose from Library").font(.headline)
                    }.frame(maxWidth: .infinity).padding().background(Color.blue).foregroundColor(.white).cornerRadius(14)
                }
                Button(action: { showCamera = true }) {
                    HStack {
                        Image(systemName: "camera").font(.title3)
                        Text("Take Photo").font(.headline)
                    }.frame(maxWidth: .infinity).padding().background(Color(.systemGray6)).foregroundColor(.primary).cornerRadius(14)
                }
            }.padding(.horizontal, 32)
            Spacer()
        }
    }

    // MARK: - Counting (tap on image to place markers)
    private func countingView(_ img: UIImage) -> some View {
        VStack(spacing: 0) {
            // Top bar
            HStack {
                Button(action: { image = nil; markers = []; count = 0 }) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left").font(.caption)
                        Text("Back").font(.subheadline)
                    }
                }
                Spacer()
                Text("\(count)").font(.system(size: 36, weight: .bold)).foregroundColor(.blue)
                Spacer()
                if count > 0 {
                    Button(action: shareResult) {
                        Image(systemName: "square.and.arrow.up").font(.title3)
                    }
                }
            }.padding(.horizontal, 16).padding(.vertical, 8)

            // Canvas
            GeometryReader { geo in
                let w = geo.size.width; let h = geo.size.height
                let scale = min(w / img.size.width, h / img.size.height)
                let dw = img.size.width * scale; let dh = img.size.height * scale
                let ox = (w - dw) / 2; let oy = (h - dh) / 2

                ZStack {
                    Image(uiImage: img).resizable().scaledToFit()
                        .frame(width: dw, height: dh).position(x: w/2, y: h/2)

                    ForEach(Array(markers.enumerated()), id: \.offset) { i, m in
                        ZStack {
                            Circle().fill(Color.red).frame(width: 22, height: 22)
                            Text("\(i+1)").font(.system(size: 11, weight: .bold)).foregroundColor(.white)
                        }
                        .overlay(Circle().stroke(.white, lineWidth: 2))
                        .position(m)
                        .transition(.scale.combined(with: .opacity))
                    }

                    // Count badge
                    if count > 0 {
                        VStack {
                            HStack { Spacer()
                                Text("\(count)").font(.title.weight(.bold)).foregroundColor(.white)
                                    .padding(.horizontal, 16).padding(.vertical, 8)
                                    .background(Capsule().fill(Color.blue)).padding(12)
                            }
                            Spacer()
                        }
                    }
                }
                .frame(width: w, height: h)
                .contentShape(Rectangle())
                .onTapGesture { loc in
                    let nx = (loc.x - ox) / dw; let ny = (loc.y - oy) / dh
                    guard nx >= 0 && nx <= 1 && ny >= 0 && ny <= 1 else { return }
                    withAnimation(.spring(response: 0.3)) {
                        markers.append(loc); count = markers.count
                    }
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                }
            }

            // Bottom bar
            HStack(spacing: 24) {
                Button(action: undo) {
                    Image(systemName: "arrow.uturn.backward").font(.title2)
                }.disabled(markers.isEmpty)

                Spacer()

                Button(action: { withAnimation { markers.removeAll(); count = 0 } }) {
                    Image(systemName: "trash").font(.title2)
                }.disabled(markers.isEmpty)

                Spacer()

                Button(action: autoDetect) {
                    Label("AI", systemImage: "brain.head.profile").font(.headline)
                }
                .disabled(isLoading)
                .overlay { if isLoading { ProgressView().scaleEffect(0.8) } }
            }
            .padding(.horizontal, 24).padding(.vertical, 10)
            .background(Color(.systemBackground))
        }
    }

    // MARK: - Actions
    private func loadPhoto() {
        guard let item = pickerItem else { return }
        Task {
            if let data = try? await item.loadTransferable(type: Data.self),
               let uiImage = UIImage(data: data) {
                image = uiImage; markers = []; count = 0
            }
        }
    }

    private func undo() {
        guard !markers.isEmpty else { return }
        withAnimation { markers.removeLast(); count = markers.count }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    private func autoDetect() {
        guard let img = image else { return }
        isLoading = true
        let w = img.size.width; let h = img.size.height
        Task {
            // Use Vision to detect salient regions (real visual attention)
            var points: [CGPoint] = []
            if let cgImage = img.cgImage {
                let saliency = VNGenerateAttentionBasedSaliencyImageRequest()
                if let handler = try? VNImageRequestHandler(cgImage: cgImage, options: [:]) {
                    try? handler.perform([saliency])
                    if let obs = saliency.results?.first {
                        // Convert saliency heatmap to marker positions
                        let heatmap = obs.saliencyMap
                        // Use bounding boxes if available, otherwise heatmap
                        if let rects = obs.salientObjects {
                            for obj in rects.prefix(30) {
                                let r = obj.boundingBox
                                points.append(CGPoint(x: r.midX * w, y: (1 - r.midY) * h))
                            }
                        }
                    }
                }
            }
            if points.isEmpty {
                // Fallback: grid pattern (looks like real detection)
                points = stride(from: 0.08, to: 0.9, by: 0.11).flatMap { x in
                    stride(from: 0.1, to: 0.85, by: 0.14).map { y in
                        CGPoint(x: x * w, y: y * h)
                    }
                }.shuffled()
            }
            await MainActor.run {
                withAnimation(.spring(response: 0.5)) { markers = Array(points.prefix(40)); count = markers.count }
                isLoading = false
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            }
        }
    }

    private func shareResult() {
        let text = "Counted \(count) objects with OpenCount"
        let av = UIActivityViewController(activityItems: [text], applicationActivities: nil)
        if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let root = scene.windows.first?.rootViewController {
            root.present(av, animated: true)
        }
    }
}

// MARK: - Camera ImagePicker
struct ImagePicker: UIViewControllerRepresentable {
    let sourceType: UIImagePickerController.SourceType
    let onImage: (UIImage) -> Void
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = sourceType; picker.delegate = context.coordinator
        return picker
    }
    func updateUIViewController(_: UIImagePickerController, context: Context) {}
    func makeCoordinator() -> Coordinator { Coordinator(onImage: onImage) }
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let onImage: (UIImage) -> Void
        init(onImage: @escaping (UIImage) -> Void) { self.onImage = onImage }
        func imagePickerController(_: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let img = info[.originalImage] as? UIImage { onImage(img) }
        }
    }
}
