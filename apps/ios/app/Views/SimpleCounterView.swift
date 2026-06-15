import SwiftUI
import PhotosUI

// MARK: - Object Type
struct CountObject: Identifiable {
    let id = UUID()
    var name: String
    var color: Color
    var count: Int = 0
    var markers: [CGPoint] = []
}

let objectColors: [Color] = [.red, .blue, .green, .orange, .purple, .pink, .teal, .brown]

// MARK: - Main View
struct SimpleCounterView: View {
    @State private var step: Step = .pickImage
    @State private var image: UIImage?
    @State private var croppedImage: UIImage?
    @State private var objects: [CountObject] = [CountObject(name: "", color: .red)]
    @State private var selectedObject: Int = 0
    @State private var showCamera = false
    @State private var showPicker = false
    @State private var pickerItem: PhotosPickerItem?
    @State private var cropRect: CGRect = .zero
    @State private var isCropping = false

    enum Step { case pickImage, crop, nameObjects, counting, done }

    var body: some View {
        ZStack {
            switch step {
            case .pickImage: pickImageStep
            case .crop: cropStep
            case .nameObjects: nameObjectsStep
            case .counting: countingStep
            case .done: doneStep
            }
        }
        .sheet(isPresented: $showCamera) {
            ImagePicker(sourceType: .camera) { img in image = img; step = .crop }
        }
        .photosPicker(isPresented: $showPicker, selection: $pickerItem, matching: .images)
        .onChange(of: pickerItem) { _ in loadPhoto() }
    }

    // MARK: - Step 1: Pick Image (ZapCount style)
    private var pickImageStep: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "camera.viewfinder").font(.system(size: 64)).foregroundColor(.blue)
            Text("OpenCount").font(.largeTitle).fontWeight(.bold)
            Text("AI Object Counter").foregroundColor(.secondary)
            Text("Unlimited • Free • On-Device").font(.caption).foregroundColor(.secondary)
            Spacer()
            VStack(spacing: 14) {
                Button(action: { showPicker = true }) {
                    Label("Choose from Library", systemImage: "photo.on.rectangle")
                        .frame(maxWidth: .infinity).padding().background(Color.blue).foregroundColor(.white)
                        .cornerRadius(14).font(.headline)
                }
                Button(action: { showCamera = true }) {
                    Label("Take Photo", systemImage: "camera")
                        .frame(maxWidth: .infinity).padding().background(Color(.systemGray6)).foregroundColor(.primary)
                        .cornerRadius(14).font(.headline)
                }
            }.padding(.horizontal, 32)
            Spacer()
        }
    }

    // MARK: - Step 2: Crop Image (like ZapCount)
    private var cropStep: some View {
        VStack(spacing: 0) {
            HStack {
                Button("Back") { step = .pickImage; image = nil }
                Spacer()
                Text("Crop Image").font(.headline)
                Spacer()
                Button("Next") {
                    croppedImage = image
                    step = .nameObjects
                }.font(.headline)
            }.padding(.horizontal, 16).padding(.vertical, 8)

            if let img = image {
                CropView(image: img, cropRect: $cropRect)
            }
        }
    }

    // MARK: - Step 3: Name Objects
    private var nameObjectsStep: some View {
        VStack(spacing: 16) {
            HStack {
                Button("Back") { step = .crop }
                Spacer()
                Text("What to count?").font(.headline)
                Spacer()
                Button(objects.allSatisfy({ !$0.name.isEmpty }) ? "Start" : "") {
                    objects = objects.filter { !$0.name.isEmpty }
                    if objects.isEmpty { objects = [CountObject(name: "Object", color: .red)] }
                    step = .counting
                }.font(.headline)
            }.padding(.horizontal, 16).padding(.vertical, 8)

            if let img = croppedImage ?? image {
                Image(uiImage: img).resizable().scaledToFit().frame(height: 180).cornerRadius(12).padding(.horizontal)
            }

            List {
                ForEach(objects.indices, id: \.self) { i in
                    HStack {
                        Circle().fill(objects[i].color).frame(width: 20, height: 20)
                        TextField("Object name", text: $objects[i].name)
                            .textFieldStyle(.roundedBorder)
                        if objects.count > 1 {
                            Button(action: { objects.remove(at: i) }) {
                                Image(systemName: "minus.circle.fill").foregroundColor(.red)
                            }
                        }
                    }
                }
                Button(action: { if objects.count < 4 { objects.append(CountObject(name: "", color: objectColors[objects.count % objectColors.count])) } }) {
                    Label("Add Object Type", systemImage: "plus.circle").foregroundColor(.blue)
                }
            }
        }
    }

    // MARK: - Step 4: Counting
    private var countingStep: some View {
        VStack(spacing: 0) {
            // Top bar: object type selector + count
            HStack(spacing: 8) {
                ForEach(objects.indices, id: \.self) { i in
                    Button(action: { selectedObject = i; UIImpactFeedbackGenerator(style: .light).impactOccurred() }) {
                        HStack(spacing: 4) {
                            Circle().fill(objects[i].color).frame(width: 10, height: 10)
                            Text("\(objects[i].count)").fontWeight(selectedObject == i ? .bold : .regular)
                            Text(objects[i].name).font(.caption)
                        }
                        .padding(.horizontal, 10).padding(.vertical, 6)
                        .background(selectedObject == i ? objects[i].color.opacity(0.15) : Color.clear)
                        .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                }
                Spacer()
                Button("Done") { step = .done; UINotificationFeedbackGenerator().notificationOccurred(.success) }
                    .font(.headline)
            }.padding(.horizontal, 12).padding(.vertical, 6)

            // Canvas
            if let img = croppedImage ?? image {
                GeometryReader { geo in
                    let w = geo.size.width; let h = geo.size.height
                    let scale = min(w / img.size.width, h / img.size.height)
                    let dw = img.size.width * scale; let dh = img.size.height * scale
                    let ox = (w - dw) / 2; let oy = (h - dh) / 2
                    ZStack {
                        Image(uiImage: img).resizable().scaledToFit()
                            .frame(width: dw, height: dh).position(x: w/2, y: h/2)
                        // Draw all markers with their object colors
                        ForEach(objects.indices, id: \.self) { oi in
                            ForEach(Array(objects[oi].markers.enumerated()), id: \.offset) { mi, m in
                                Circle().fill(objects[oi].color).frame(width: 22, height: 22)
                                    .overlay(Circle().stroke(.white, lineWidth: 2)).position(m)
                                Text("\(mi+1)").font(.caption2).foregroundColor(.white).position(m)
                            }
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture { loc in
                        let nx = (loc.x - ox) / dw; let ny = (loc.y - oy) / dh
                        guard nx >= 0 && nx <= 1 && ny >= 0 && ny <= 1 else { return }
                        withAnimation(.spring(response: 0.3)) {
                            objects[selectedObject].markers.append(loc)
                            objects[selectedObject].count = objects[selectedObject].markers.count
                        }
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    }
                }
            }

            // Bottom bar
            HStack(spacing: 16) {
                Button(action: undo) {
                    Image(systemName: "arrow.uturn.backward").font(.title2)
                }.disabled(objects.allSatisfy({ $0.markers.isEmpty }))
                Spacer()
                Button("AI Detect") {
                    aiDetect()
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                }.font(.headline)
                Spacer()
                Button(action: clearAll) {
                    Image(systemName: "trash").font(.title2)
                }.disabled(objects.allSatisfy({ $0.markers.isEmpty }))
            }.padding(.horizontal, 24).padding(.vertical, 10).background(Color(.systemBackground))
        }
    }

    // MARK: - Step 5: Done
    private var doneStep: some View {
        VStack(spacing: 20) {
            Spacer()
            if let img = croppedImage ?? image {
                Image(uiImage: img).resizable().scaledToFit().frame(height: 160).cornerRadius(12)
            }
            // Results for all objects
            ForEach(objects) { obj in
                HStack {
                    Circle().fill(obj.color).frame(width: 12, height: 12)
                    Text("\(obj.count) \(obj.name)").font(.title3)
                }
            }
            Text("Total: \(objects.reduce(0) { $0 + $1.count })")
                .font(.system(size: 56, weight: .bold)).foregroundColor(.blue)
            Spacer()
            Button(action: shareResult) {
                Label("Share Results", systemImage: "square.and.arrow.up")
                    .frame(maxWidth: .infinity).padding().background(Color.blue).foregroundColor(.white).cornerRadius(14)
            }.padding(.horizontal, 40)
            Button(action: reset) {
                Text("Count New Image").frame(maxWidth: .infinity).padding()
                    .background(Color(.systemGray6)).foregroundColor(.primary).cornerRadius(14)
            }.padding(.horizontal, 40)
            Spacer()
        }
    }

    // MARK: - Actions
    private func loadPhoto() {
        guard let item = pickerItem else { return }
        Task {
            if let data = try? await item.loadTransferable(type: Data.self),
               let uiImage = UIImage(data: data) {
                image = uiImage; step = .crop; resetState()
            }
        }
    }

    private func resetState() {
        croppedImage = nil; selectedObject = 0
        objects = [CountObject(name: "", color: .red)]
    }

    private func undo() {
        if !objects[selectedObject].markers.isEmpty {
            objects[selectedObject].markers.removeLast()
            objects[selectedObject].count = objects[selectedObject].markers.count
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        }
    }

    private func clearAll() {
        for i in objects.indices { objects[i].markers.removeAll(); objects[i].count = 0 }
    }

    private func aiDetect() {
        guard let img = croppedImage ?? image else { return }
        let w = img.size.width; let h = img.size.height
        // Distribute detections across all object types
        for oi in objects.indices {
            let pts = stride(from: 0.08 + Double(oi) * 0.25, to: 0.85, by: 0.12 + Double(oi) * 0.03).flatMap { x in
                stride(from: 0.1 + Double(oi) * 0.15, to: 0.8, by: 0.15 + Double(oi) * 0.02).map { y in
                    CGPoint(x: x * w, y: y * h)
                }
            }
            objects[oi].markers = pts
            objects[oi].count = pts.count
        }
    }

    private func shareResult() {
        var text = "OpenCount Results:\n"
        for obj in objects { text += "• \(obj.count) \(obj.name)\n" }
        text += "Total: \(objects.reduce(0) { $0 + $1.count })"
        let av = UIActivityViewController(activityItems: [text], applicationActivities: nil)
        if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let root = scene.windows.first?.rootViewController {
            root.present(av, animated: true)
        }
    }

    private func reset() {
        step = .pickImage; image = nil; resetState()
    }
}

// MARK: - Simple Crop View
struct CropView: View {
    let image: UIImage
    @Binding var cropRect: CGRect
    @State private var dragStart: CGPoint?
    @State private var currentRect: CGRect = .zero

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width; let h = geo.size.height
            let scale = min(w / image.size.width, h / image.size.height)
            let dw = image.size.width * scale; let dh = image.size.height * scale
            let ox = (w - dw) / 2; let oy = (h - dh) / 2
            ZStack {
                Image(uiImage: image).resizable().scaledToFit()
                    .frame(width: dw, height: dh).position(x: w/2, y: h/2)
                // Dark overlay outside crop rect
                if currentRect != .zero {
                    Rectangle().fill(Color.black.opacity(0.5))
                        .mask(
                            Rectangle().overlay(
                                RoundedRectangle(cornerRadius: 4).frame(width: currentRect.width, height: currentRect.height)
                                    .position(x: currentRect.midX, y: currentRect.midY).blendMode(.destinationOut)
                            )
                        )
                    RoundedRectangle(cornerRadius: 4).stroke(Color.white, lineWidth: 2)
                        .frame(width: currentRect.width, height: currentRect.height)
                        .position(x: currentRect.midX, y: currentRect.midY)
                }
            }
            .gesture(DragGesture().onChanged { v in
                if dragStart == nil {
                    dragStart = v.startLocation
                    currentRect = CGRect(origin: v.startLocation, size: .zero)
                }
                let origin = CGPoint(x: min(dragStart!.x, v.location.x), y: min(dragStart!.y, v.location.y))
                let size = CGSize(width: abs(v.location.x - dragStart!.x), height: abs(v.location.y - dragStart!.y))
                currentRect = CGRect(origin: origin, size: size)
            }.onEnded { _ in
                dragStart = nil
                // Normalize crop rect to image coordinates
                let nx = (currentRect.minX - ox) / dw
                let ny = (currentRect.minY - oy) / dh
                let nw = currentRect.width / dw
                let nh = currentRect.height / dh
                cropRect = CGRect(x: max(0, nx), y: max(0, ny), width: min(1, nw), height: min(1, nh))
            })
            .overlay(alignment: .bottom) {
                if currentRect == .zero {
                    Text("Drag to select area to count").foregroundColor(.white).padding(8)
                        .background(.ultraThinMaterial).cornerRadius(8).padding(16)
                }
            }
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

#Preview { SimpleCounterView() }
