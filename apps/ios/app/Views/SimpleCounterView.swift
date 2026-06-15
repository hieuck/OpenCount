import SwiftUI
import PhotosUI

/// ZapCount clone — pick image → choose object → tap to count → done
struct SimpleCounterView: View {
    @State private var step: Step = .pickImage
    @State private var image: UIImage?
    @State private var markers: [CGPoint] = []
    @State private var objectName: String = ""
    @State private var showCamera = false
    @State private var showPicker = false
    @State private var count: Int = 0

    enum Step { case pickImage, nameObject, counting, done }

    var body: some View {
        VStack(spacing: 0) {
            switch step {
            case .pickImage:
                pickImageStep
            case .nameObject:
                nameObjectStep
            case .counting:
                countingStep
            case .done:
                doneStep
            }
        }
        .sheet(isPresented: $showCamera) { ImagePicker(sourceType: .camera) { img in
            image = img; step = .nameObject
        }}
        .photosPicker(isPresented: $showPicker, selection: $pickerItem, matching: .images)
        .onChange(of: pickerItem) { _ in loadPhoto() }
    }

    @State private var pickerItem: PhotosPickerItem?

    // MARK: - Step 1: Pick Image
    private var pickImageStep: some View {
        VStack(spacing: 30) {
            Spacer()
            Image(systemName: "photo.on.rectangle").font(.system(size: 60)).foregroundColor(.blue)
            Text("ZapCount").font(.largeTitle).fontWeight(.bold)
            Text("AI Object Counter").foregroundColor(.secondary)
            Spacer()
            VStack(spacing: 16) {
                Button(action: { showPicker = true }) {
                    Label("Choose from Library", systemImage: "photo.on.rectangle")
                        .frame(maxWidth: .infinity).padding().background(Color.blue).foregroundColor(.white)
                        .cornerRadius(12)
                }
                Button(action: { showCamera = true }) {
                    Label("Take Photo", systemImage: "camera")
                        .frame(maxWidth: .infinity).padding().background(Color(.systemGray5)).foregroundColor(.primary)
                        .cornerRadius(12)
                }
            }.padding(.horizontal, 40)
            Spacer()
        }
    }

    // MARK: - Step 2: Name Object
    private var nameObjectStep: some View {
        VStack(spacing: 24) {
            if let img = image { Image(uiImage: img).resizable().scaledToFit().frame(height: 200).cornerRadius(12) }
            Text("What do you want to count?").font(.headline)
            TextField("e.g. Cars, People, Trees", text: $objectName)
                .textFieldStyle(.roundedBorder).multilineTextAlignment(.center).padding(.horizontal, 40)
            Button(action: {
                if objectName.isEmpty { objectName = "Object" }
                step = .counting
            }) {
                Text("Start Counting").frame(maxWidth: .infinity).padding().background(Color.blue).foregroundColor(.white).cornerRadius(12)
            }.padding(.horizontal, 40)
            Button(action: { step = .pickImage; image = nil }) {
                Text("Choose Different Photo").foregroundColor(.secondary)
            }
        }.padding()
    }

    // MARK: - Step 3: Counting
    private var countingStep: some View {
        VStack(spacing: 0) {
            // Top bar
            HStack {
                Text(count > 0 ? "\(count) \(objectName)" : "Tap to Count").font(.title2).fontWeight(.semibold)
                Spacer()
                Button("Done") { step = .done }.font(.headline)
            }.padding(.horizontal, 16).padding(.vertical, 8)

            // Canvas
            if let img = image {
                GeometryReader { geo in
                    let w = geo.size.width
                    let h = geo.size.height
                    let scale = min(w / img.size.width, h / img.size.height)
                    let dw = img.size.width * scale
                    let dh = img.size.height * scale
                    let ox = (w - dw) / 2
                    let oy = (h - dh) / 2
                    ZStack {
                        Image(uiImage: img).resizable().scaledToFit()
                            .frame(width: dw, height: dh).position(x: w/2, y: h/2)
                        ForEach(Array(markers.enumerated()), id: \.offset) { i, m in
                            Circle().fill(Color.red).frame(width: 20, height: 20)
                                .overlay(Circle().stroke(.white, lineWidth: 2)).position(m)
                            Text("\(i+1)").font(.caption2).foregroundColor(.white).position(m)
                        }
                    }.contentShape(Rectangle()).onTapGesture { loc in
                        let nx = (loc.x - ox) / dw
                        let ny = (loc.y - oy) / dh
                        guard nx >= 0 && nx <= 1 && ny >= 0 && ny <= 1 else { return }
                        withAnimation(.spring(response: 0.3)) { markers.append(loc); count = markers.count }
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    }
                }
            }

            // Bottom bar
            HStack(spacing: 20) {
                Button(action: { if !markers.isEmpty { markers.removeLast(); count = markers.count } }) {
                    Image(systemName: "arrow.uturn.backward").font(.title2) }
                .disabled(markers.isEmpty)
                Spacer()
                Button("AI Detect") {
                    // Mock AI: place markers in a grid pattern
                    guard let img = image else { return }
                    let w = img.size.width; let h = img.size.height
                    let pts = stride(from: 0.15, to: 0.9, by: 0.15).flatMap { x in
                        stride(from: 0.2, to: 0.85, by: 0.2).map { y in CGPoint(x: x * w, y: y * h) }
                    }
                    markers = pts
                    count = pts.count
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                }.font(.headline)
                Spacer()
                Button(action: { markers.removeAll(); count = 0 }) {
                    Image(systemName: "trash").font(.title2) }
                .disabled(markers.isEmpty)
            }.padding(.horizontal, 24).padding(.vertical, 12).background(Color(.systemBackground))
        }
    }

    // MARK: - Step 4: Done
    private var doneStep: some View {
        VStack(spacing: 24) {
            Spacer()
            if let img = image {
                Image(uiImage: img).resizable().scaledToFit().frame(height: 180).cornerRadius(12)
            }
            Text("\(count)").font(.system(size: 72, weight: .bold)).foregroundColor(.blue)
            Text(objectName).font(.title2).foregroundColor(.secondary)
            Spacer()
            Button(action: shareResult) {
                Label("Share Result", systemImage: "square.and.arrow.up")
                    .frame(maxWidth: .infinity).padding().background(Color.blue).foregroundColor(.white).cornerRadius(12)
            }.padding(.horizontal, 40)
            Button(action: reset) {
                Text("Count New Image").frame(maxWidth: .infinity).padding().background(Color(.systemGray5)).foregroundColor(.primary).cornerRadius(12)
            }.padding(.horizontal, 40)
            Spacer()
        }
    }

    private func loadPhoto() {
        guard let item = pickerItem else { return }
        Task {
            if let data = try? await item.loadTransferable(type: Data.self),
               let uiImage = UIImage(data: data) {
                image = uiImage; step = .nameObject; markers.removeAll(); count = 0
            }
        }
    }

    private func shareResult() {
        let text = "\(objectName): \(count) — counted with OpenCount"
        let av = UIActivityViewController(activityItems: [text], applicationActivities: nil)
        if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let root = scene.windows.first?.rootViewController {
            root.present(av, animated: true)
        }
    }

    private func reset() {
        step = .pickImage; image = nil; markers.removeAll(); count = 0; objectName = ""
    }
}

// MARK: - Camera ImagePicker
struct ImagePicker: UIViewControllerRepresentable {
    let sourceType: UIImagePickerController.SourceType
    let onImage: (UIImage) -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = sourceType
        picker.delegate = context.coordinator
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

#Preview {
    SimpleCounterView()
}
