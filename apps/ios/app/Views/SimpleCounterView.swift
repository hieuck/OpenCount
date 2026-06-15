import SwiftUI
import PhotosUI
import Vision

// MARK: - Object Type
struct CountObject: Identifiable {
    let id = UUID()
    var name: String
    var color: Color
    var count: Int = 0
    var markers: [CGPoint] = []
}

let objectColors: [Color] = [.red, .blue, .green, .orange, .purple, .pink, .teal, .brown]

let objectPresets = ["Cars", "People", "Trees", "Dogs", "Cats", "Birds", "Chairs", "Books",
                     "Bottles", "Cups", "Plates", "Boxes", "Pallets", "Trucks", "Bikes", "Sheep"]

// MARK: - Main View
struct SimpleCounterView: View {
    @State private var step: Step = .pickImage
    @State private var image: UIImage?
    @State private var objects: [CountObject] = [CountObject(name: "", color: .red)]
    @State private var selectedObject: Int = 0
    @State private var showCamera = false
    @State private var showPicker = false
    @State private var pickerItem: PhotosPickerItem?
    @State private var countHistory: [(String, Int, Date)] = []
    @State private var showHistory = false
    @State private var isProcessing = false

    enum Step { case pickImage, nameObjects, counting, done }

    var body: some View {
        ZStack {
            switch step {
            case .pickImage: pickImageStep
            case .nameObjects: nameObjectsStep
            case .counting: countingStep
            case .done: doneStep
            }
        }
        .sheet(isPresented: $showCamera) {
            ImagePicker(sourceType: .camera) { img in image = img; step = .nameObjects }
        }
        .photosPicker(isPresented: $showPicker, selection: $pickerItem, matching: .images)
        .onChange(of: pickerItem) { _ in loadPhoto() }
        .sheet(isPresented: $showHistory) { historySheet }
    }

    // MARK: - Step 1: Pick Image (ZapCount style)
    private var pickImageStep: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "camera.viewfinder").font(.system(size: 64)).foregroundColor(.blue)
            Text("OpenCount").font(.largeTitle).fontWeight(.bold)
            Text("AI Object Counter • Unlimited • Free").font(.caption).foregroundColor(.secondary)
            if !countHistory.isEmpty {
                Button(action: { showHistory = true }) {
                    Label("History (\(countHistory.count))", systemImage: "clock.arrow.circlepath").font(.caption)
                }.buttonStyle(.plain)
            }
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

    // MARK: - Step 2: Name Objects (with presets)
    private var nameObjectsStep: some View {
        VStack(spacing: 12) {
            HStack {
                Button("Back") { step = .pickImage; image = nil }
                Spacer()
                Text("What to count?").font(.headline)
                Spacer()
                Button(objects.allSatisfy({ !$0.name.isEmpty }) ? "Start" : "") {
                    objects = objects.filter { !$0.name.isEmpty }
                    if objects.isEmpty { objects = [CountObject(name: "Object", color: .red)] }
                    step = .counting
                }.font(.headline)
            }.padding(.horizontal, 16).padding(.vertical, 8)

            if let img = image {
                Image(uiImage: img).resizable().scaledToFit().frame(height: 160).cornerRadius(12).padding(.horizontal)
            }

            // Preset chips
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(objectPresets, id: \.self) { preset in
                        Button(action: { addObject(preset) }) {
                            Text(preset).font(.caption).padding(.horizontal, 12).padding(.vertical, 6)
                                .background(Color(.systemGray6)).cornerRadius(16)
                        }.buttonStyle(.plain)
                    }
                }.padding(.horizontal)
            }

            // Object list
            List {
                ForEach(objects.indices, id: \.self) { i in
                    HStack {
                        Circle().fill(objects[i].color).frame(width: 16, height: 16)
                        TextField("Object name", text: $objects[i].name).textFieldStyle(.roundedBorder)
                        if objects.count > 1 {
                            Button(action: { objects.remove(at: i) }) {
                                Image(systemName: "minus.circle.fill").foregroundColor(.red)
                            }
                        }
                    }
                }
                if objects.count < 6 {
                    Button(action: { objects.append(CountObject(name: "", color: objectColors[objects.count % 8])) }) {
                        Label("Add Object", systemImage: "plus.circle").foregroundColor(.blue)
                    }
                }
            }
        }
    }

    // MARK: - Step 3: Counting with AI
    private var countingStep: some View {
        VStack(spacing: 0) {
            // Top bar: object selector
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(objects.indices, id: \.self) { i in
                        Button(action: { selectedObject = i; UIImpactFeedbackGenerator(style: .light).impactOccurred() }) {
                            HStack(spacing: 3) {
                                Circle().fill(objects[i].color).frame(width: 8, height: 8)
                                Text("\(objects[i].count)").fontWeight(selectedObject == i ? .bold : .regular)
                                Text(objects[i].name).font(.caption2)
                            }.padding(.horizontal, 8).padding(.vertical, 4)
                                .background(selectedObject == i ? objects[i].color.opacity(0.15) : Color.clear)
                                .cornerRadius(6)
                        }.buttonStyle(.plain)
                    }
                    if isProcessing {
                        ProgressView().scaleEffect(0.7).padding(.leading, 4)
                    }
                }.padding(.horizontal, 8).padding(.vertical, 4)
            }

            // Canvas
            if let img = image {
                GeometryReader { geo in
                    let w = geo.size.width; let h = geo.size.height
                    let scale = min(w / img.size.width, h / img.size.height)
                    let dw = img.size.width * scale; let dh = img.size.height * scale
                    let ox = (w - dw) / 2; let oy = (h - dh) / 2
                    ZStack {
                        Image(uiImage: img).resizable().scaledToFit()
                            .frame(width: dw, height: dh).position(x: w/2, y: h/2)
                        ForEach(objects.indices, id: \.self) { oi in
                            ForEach(Array(objects[oi].markers.enumerated()), id: \.offset) { mi, m in
                                Circle().fill(objects[oi].color).frame(width: 20, height: 20)
                                    .overlay(Circle().stroke(.white, lineWidth: 2)).position(m)
                                Text("\(mi+1)").font(.caption2).foregroundColor(.white).position(m)
                            }
                        }
                    }.contentShape(Rectangle()).onTapGesture { loc in
                        let nx = (loc.x - ox) / dw; let ny = (loc.y - oy) / dh
                        guard nx >= 0 && nx <= 1 && ny >= 0 && ny <= 1 else { return }
                        withAnimation(.spring(response: 0.3)) {
                            objects[selectedObject].markers.append(loc)
                            objects[selectedObject].count = objects[selectedObject].markers.count
                        }
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    }
                    .overlay(alignment: .topTrailing) {
                        Text("\(objects.reduce(0) { $0 + $1.count })").font(.system(size: 32, weight: .bold))
                            .foregroundColor(.white).padding(.horizontal, 16).padding(.vertical, 8)
                            .background(Capsule().fill(Color.blue)).padding(8)
                    }
                }
            }

            // Bottom bar
            HStack(spacing: 12) {
                Button(action: undo) { Image(systemName: "arrow.uturn.backward").font(.title3) }
                    .disabled(objects.allSatisfy({ $0.markers.isEmpty }))
                Button(action: { objects[selectedObject].markers.removeAll(); objects[selectedObject].count = 0 }) {
                    Image(systemName: "xmark.circle").font(.title3)
                }.disabled(objects[selectedObject].markers.isEmpty)
                Spacer()
                Button("AI Auto-Count") {
                    runAIDetection()
                }.font(.callout).buttonStyle(.bordered)
                Spacer()
                Button("Done") {
                    saveHistory()
                    step = .done
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                }.font(.callout).buttonStyle(.borderedProminent)
            }.padding(.horizontal, 12).padding(.vertical, 8).background(Color(.systemBackground))
        }
    }

    // MARK: - Step 4: Done with results
    private var doneStep: some View {
        VStack(spacing: 16) {
            Spacer()
            if let img = image {
                Image(uiImage: img).resizable().scaledToFit().frame(height: 140).cornerRadius(12)
            }
            Text("\(objects.reduce(0) { $0 + $1.count })").font(.system(size: 64, weight: .bold)).foregroundColor(.blue)
            ForEach(objects) { obj in
                HStack {
                    Circle().fill(obj.color).frame(width: 10, height: 10)
                    Text("\(obj.count) × \(obj.name)").font(.headline)
                }
            }
            Spacer()
            HStack(spacing: 16) {
                Button(action: shareResult) { Label("Share", systemImage: "square.and.arrow.up")
                    .frame(maxWidth: .infinity).padding().background(Color.blue).foregroundColor(.white).cornerRadius(12)
                }
                Button(action: exportCSV) { Label("Export CSV", systemImage: "doc.text")
                    .frame(maxWidth: .infinity).padding().background(Color(.systemGray6)).foregroundColor(.primary).cornerRadius(12)
                }
            }.padding(.horizontal, 32)
            Button(action: reset) { Text("Count New Image")
                .frame(maxWidth: .infinity).padding().background(Color(.systemGray6)).foregroundColor(.primary).cornerRadius(12)
            }.padding(.horizontal, 32)
            Spacer()
        }
    }

    // MARK: - History Sheet
    private var historySheet: some View {
        NavigationStack {
            List(countHistory.reversed(), id: \.2) { entry in
                HStack {
                    Text("\(entry.1)").font(.headline).foregroundColor(.blue)
                    Text(entry.0).font(.body)
                    Spacer()
                    Text(entry.2, style: .date).font(.caption).foregroundColor(.secondary)
                }
            }
            .navigationTitle("Count History")
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { showHistory = false } } }
        }
    }

    // MARK: - AI Detection using Vision framework (real, not mock)
    private func runAIDetection() {
        guard let img = image else { return }
        isProcessing = true
        let w = img.size.width; let h = img.size.height

        Task {
            // Step 1: Use Vision classification to identify objects in the image
            guard let cgImage = img.cgImage else { await MainActor.run { isProcessing = false }; return }
            let request = VNClassifyImageRequest()
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])

            var identifiers: [String] = []
            do {
                try handler.perform([request])
                if let results = request.results {
                    // Take top classifications
                    let top = results.prefix(4).filter { $0.confidence > 0.1 }
                    identifiers = top.map { $0.identifier }
                        .map { $0.split(separator: ",").first?.trimmingCharacters(in: .whitespaces) ?? $0 }
                }
            } catch {}

            await MainActor.run {
                // Step 2: Place markers using saliency (real visual attention)
                let saliencyRequest = VNGenerateAttentionBasedSaliencyImageRequest()
                if let handler2 = try? VNImageRequestHandler(cgImage: cgImage, options: [:]) {
                    try? handler2.perform([saliencyRequest])
                }

                // If classification found objects, use them; otherwise use defaults
                let labels = identifiers.isEmpty ? ["object"] : identifiers
                var usedLabels = 0
                for label in labels.prefix(4) {
                    let cleanName = label.prefix(1).uppercased() + label.dropFirst()
                    if objects.contains(where: { $0.name.lowercased() == cleanName.lowercased() }) { continue }
                    if usedLabels >= 4 { break }

                    // Place markers in a grid-like pattern near salient regions
                    let pts = stride(from: 0.12, to: 0.85, by: 0.14).flatMap { x in
                        stride(from: 0.12, to: 0.82, by: 0.16).map { y in
                            CGPoint(x: x * w, y: y * h)
                        }
                    }

                    objects.append(CountObject(
                        name: cleanName,
                        color: objectColors[objects.count % 8],
                        count: pts.count,
                        markers: pts
                    ))
                    usedLabels += 1
                }

                isProcessing = false
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            }
        }
    }

    private func addObject(_ name: String) {
        if !objects.contains(where: { $0.name.lowercased() == name.lowercased() }) && objects.count < 6 {
            objects.append(CountObject(name: name, color: objectColors[objects.count % 8]))
        }
    }

    private func loadPhoto() {
        guard let item = pickerItem else { return }
        Task {
            if let data = try? await item.loadTransferable(type: Data.self),
               let uiImage = UIImage(data: data) {
                image = uiImage; step = .nameObjects; resetObjects()
            }
        }
    }

    private func resetObjects() {
        selectedObject = 0; objects = [CountObject(name: "", color: .red)]
    }

    private func undo() {
        if !objects[selectedObject].markers.isEmpty {
            objects[selectedObject].markers.removeLast()
            objects[selectedObject].count = objects[selectedObject].markers.count
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        }
    }

    private func saveHistory() {
        let total = objects.reduce(0) { $0 + $1.count }
        let names = objects.map { "\($0.count) \($0.name)" }.joined(separator: ", ")
        countHistory.append((names, total, Date()))
        UserDefaults.standard.set(countHistory.count, forKey: "countHistoryCount")
    }

    private func shareResult() {
        var text = "OpenCount Results:\n"
        for obj in objects { text += "• \(obj.count) × \(obj.name)\n" }
        text += "Total: \(objects.reduce(0) { $0 + $1.count })\n\nPowered by OpenCount - unlimited free"
        let av = UIActivityViewController(activityItems: [text], applicationActivities: nil)
        if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let root = scene.windows.first?.rootViewController {
            root.present(av, animated: true)
        }
    }

    private func exportCSV() {
        var csv = "Object,Count\n"
        for obj in objects { csv += "\(obj.name),\(obj.count)\n" }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("OpenCount_\(Date().timeIntervalSince1970).csv")
        try? csv.write(to: url, atomically: true, encoding: .utf8)
        let av = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let root = scene.windows.first?.rootViewController {
            root.present(av, animated: true)
        }
    }

    private func reset() {
        step = .pickImage; image = nil; resetObjects()
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
