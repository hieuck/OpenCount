import SwiftUI

/// Simple ZapCount-like counting view: tap to count, no session needed.
struct SimpleCounterView: View {
    @State private var count: Int = 0
    @State private var objectName: String = "Object"
    @State private var showNameAlert: Bool = false
    @State private var newName: String = ""

    var body: some View {
        VStack(spacing: 0) {
            // Top bar: object name + count
            HStack {
                Button(action: { newName = objectName; showNameAlert = true }) {
                    HStack(spacing: 4) {
                        Text(objectName).font(.headline)
                        Image(systemName: "pencil").font(.caption2)
                    }
                }
                .buttonStyle(.plain)

                Spacer()

                Text("\(count)").font(.system(size: 48, weight: .bold))
                    .animation(.spring(response: 0.2), value: count)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)

            // Counting canvas: tap anywhere to add marker
            GeometryReader { geo in
                ZStack {
                    Color(.systemGray6)
                        .ignoresSafeArea()

                    // Markers
                    ForEach(Array(markers.enumerated()), id: \.offset) { i, marker in
                        Circle()
                            .fill(Color.red)
                            .frame(width: 20, height: 20)
                            .overlay(Circle().stroke(Color.white, lineWidth: 2))
                            .position(marker)
                    }

                    if markers.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "hand.tap").font(.system(size: 40)).foregroundColor(.secondary)
                            Text("Tap anywhere to count").foregroundColor(.secondary).font(.title3)
                            Text("\(Image(systemName: "gearshape")) Tap top-left to rename object")
                                .foregroundColor(.secondary).font(.caption)
                        }
                    }

                    // Count badge
                    VStack {
                        HStack {
                            Spacer()
                            if count > 0 {
                                Text("\(count)")
                                    .font(.system(size: 32, weight: .bold))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 10)
                                    .background(Capsule().fill(Color.blue))
                                    .padding(16)
                            }
                        }
                        Spacer()
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture { location in
                    withAnimation(.spring(response: 0.3)) {
                        markers.append(location)
                        count = markers.count
                    }
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                }
            }

            // Bottom bar
            HStack(spacing: 16) {
                Button(action: {
                    if !markers.isEmpty {
                        markers.removeLast()
                        count = markers.count
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    }
                }) {
                    Label("Undo", systemImage: "arrow.uturn.backward")
                }
                .disabled(markers.isEmpty)

                Spacer()

                Button(action: { markers.removeAll(); count = 0 }) {
                    Label("Clear", systemImage: "trash")
                }
                .disabled(markers.isEmpty)

                Spacer()

                Button(action: shareCount) {
                    Label("Share", systemImage: "square.and.arrow.up")
                }
                .disabled(count == 0)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(Color(.systemBackground))
        }
        .alert("Rename Object", isPresented: $showNameAlert) {
            TextField("Name", text: $newName)
            Button("OK") { if !newName.isEmpty { objectName = newName } }
            Button("Cancel", role: .cancel) {}
        }
    }

    @State private var markers: [CGPoint] = []

    private func shareCount() {
        let text = "\(objectName): \(count)"
        let av = UIActivityViewController(activityItems: [text], applicationActivities: nil)
        if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let root = scene.windows.first?.rootViewController {
            root.present(av, animated: true)
        }
    }
}
