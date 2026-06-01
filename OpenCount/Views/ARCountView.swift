import SwiftUI
import ARKit
import SceneKit

// MARK: - ARCountView

/// Augmented reality counting view using ARKit.
///
/// Requirements: 19.1–19.8
struct ARCountView: View {

    let session: CountSession
    @StateObject private var viewModel = ARCountViewModel()
    @Environment(\.dismiss) private var dismiss
    @State private var isShowingUnsupportedAlert = false

    var body: some View {
        ZStack {
            if viewModel.isARSupported {
                // AR Scene view
                ARSceneView(viewModel: viewModel)
                    .ignoresSafeArea()

                // HUD overlay
                VStack {
                    topBar
                    Spacer()
                    bottomControls
                }
            } else {
                unsupportedView
            }
        }
        .onAppear {
            if viewModel.isARSupported {
                viewModel.startARSession()
            }
        }
        .onDisappear {
            viewModel.stopARSession()
        }
        .alert("AR Unavailable", isPresented: $isShowingUnsupportedAlert) {
            Button("OK", role: .cancel) { dismiss() }
        } message: {
            Text("This device does not support ARKit world tracking required for AR counting.")
        }
    }

    // MARK: - Top bar

    private var topBar: some View {
        HStack {
            Button {
                Task {
                    try? await viewModel.saveToSession(session)
                    dismiss()
                }
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.white)
                    .shadow(radius: 2)
            }
            .accessibilityLabel("Save and close AR counting")
            .padding()

            Spacer()

            // Tally HUD
            if !viewModel.globalTally.isEmpty {
                VStack(alignment: .trailing, spacing: 4) {
                    ForEach(Array(viewModel.globalTally.keys).sorted { $0.name < $1.name }, id: \.id) { type in
                        HStack(spacing: 6) {
                            Text(type.name)
                                .font(.caption)
                                .foregroundStyle(.white)
                            Text("\(viewModel.globalTally[type] ?? 0)")
                                .font(.caption.bold())
                                .foregroundStyle(.white)
                                .monospacedDigit()
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(Color.black.opacity(0.5)))
                    }
                }
                .padding()
            }
        }
    }

    // MARK: - Bottom controls

    private var bottomControls: some View {
        VStack(spacing: 12) {
            // Object type selector
            if !session.objectTypes.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(session.objectTypes.sorted { $0.sortOrder < $1.sortOrder }) { type in
                            Button {
                                viewModel.selectedObjectType = type
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: type.iconName)
                                        .font(.caption)
                                    Text(type.name)
                                        .font(.caption.bold())
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(
                                    Capsule().fill(
                                        viewModel.selectedObjectType?.id == type.id
                                            ? (Color(hex: type.colorHex) ?? .accentColor)
                                            : Color.black.opacity(0.4)
                                    )
                                )
                                .foregroundStyle(.white)
                            }
                            .accessibilityLabel("Select \(type.name)")
                            .accessibilityAddTraits(viewModel.selectedObjectType?.id == type.id ? .isSelected : [])
                        }
                    }
                    .padding(.horizontal)
                }
            }

            Text("Tap on a surface to place a count marker")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.8))
                .padding(.bottom, 32)
        }
        .background(
            LinearGradient(
                colors: [.clear, .black.opacity(0.5)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        )
    }

    // MARK: - Unsupported view

    private var unsupportedView: some View {
        VStack(spacing: 20) {
            Image(systemName: "arkit")
                .font(.system(size: 64))
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            Text("AR Not Supported")
                .font(.title2.bold())
            Text("This device does not support ARKit world tracking. AR counting requires iPhone 12 or newer.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Button("Close") { dismiss() }
                .buttonStyle(.borderedProminent)
        }
        .padding()
    }
}

// MARK: - ARSceneView

/// UIViewRepresentable wrapping ARSCNView for AR scene rendering.
struct ARSceneView: UIViewRepresentable {

    @ObservedObject var viewModel: ARCountViewModel

    func makeUIView(context: Context) -> ARSCNView {
        let sceneView = ARSCNView()
        sceneView.session = viewModel.arSession
        sceneView.autoenablesDefaultLighting = true
        sceneView.automaticallyUpdatesLighting = true

        // Tap gesture to place anchors
        let tapGesture = UITapGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleTap(_:))
        )
        sceneView.addGestureRecognizer(tapGesture)

        context.coordinator.sceneView = sceneView
        return sceneView
    }

    func updateUIView(_ uiView: ARSCNView, context: Context) {
        // Sync anchor nodes
        context.coordinator.syncAnchors(viewModel.arAnchors, in: uiView)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(viewModel: viewModel)
    }

    // MARK: - Coordinator

    final class Coordinator: NSObject, ARSCNViewDelegate {

        weak var sceneView: ARSCNView?
        let viewModel: ARCountViewModel

        init(viewModel: ARCountViewModel) {
            self.viewModel = viewModel
        }

        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            guard let sceneView = sceneView else { return }
            let location = gesture.location(in: sceneView)

            // Raycast against detected planes
            let results = sceneView.raycastQuery(
                from: location,
                allowing: .estimatedPlane,
                alignment: .any
            ).flatMap { sceneView.session.raycast($0) } ?? []

            if let result = results.first {
                Task { @MainActor in
                    self.viewModel.placeAnchor(at: result.worldTransform)
                }
            }
        }

        func syncAnchors(_ anchors: [ARCountAnchor], in sceneView: ARSCNView) {
            // Remove nodes for deleted anchors
            let anchorIDs = Set(anchors.map { $0.id.uuidString })
            for node in sceneView.scene.rootNode.childNodes {
                if let name = node.name, !anchorIDs.contains(name) {
                    node.removeFromParentNode()
                }
            }

            // Add nodes for new anchors
            let existingIDs = Set(sceneView.scene.rootNode.childNodes.compactMap(\.name))
            for anchor in anchors where !existingIDs.contains(anchor.id.uuidString) {
                let node = makeAnchorNode(for: anchor)
                node.simdWorldTransform = anchor.worldTransform
                sceneView.scene.rootNode.addChildNode(node)
            }
        }

        private func makeAnchorNode(for anchor: ARCountAnchor) -> SCNNode {
            let sphere = SCNSphere(radius: 0.03)
            let color = UIColor(hex: anchor.objectType.colorHex) ?? .systemRed
            sphere.firstMaterial?.diffuse.contents = color
            sphere.firstMaterial?.emission.contents = color.withAlphaComponent(0.3)

            let node = SCNNode(geometry: sphere)
            node.name = anchor.id.uuidString

            // Distance label
            let text = SCNText(string: String(format: "%.1fm", anchor.distanceMeters), extrusionDepth: 0.001)
            text.font = UIFont.systemFont(ofSize: 0.1)
            text.firstMaterial?.diffuse.contents = UIColor.white
            let textNode = SCNNode(geometry: text)
            textNode.scale = SCNVector3(0.1, 0.1, 0.1)
            textNode.position = SCNVector3(0.04, 0.04, 0)
            node.addChildNode(textNode)

            return node
        }
    }
}

// MARK: - Color extension (reuse from existing)

private extension Color {
    init?(hex: String) {
        var str = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if str.hasPrefix("#") { str.removeFirst() }
        guard str.count == 6, let value = UInt64(str, radix: 16) else { return nil }
        let r = Double((value >> 16) & 0xFF) / 255
        let g = Double((value >> 8) & 0xFF) / 255
        let b = Double(value & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }
}
