import SwiftUI
import AVFoundation

// MARK: - LiveCountView

/// Full-screen live camera counting view.
///
/// Displays a real-time camera preview with AI detection bounding boxes overlaid,
/// a tally HUD, confidence threshold slider, freeze/unfreeze button, and camera-switch button.
///
/// Requirements: 9.1, 9.2, 9.3, 9.4, 9.5, 9.6, 9.7, 9.8
struct LiveCountView: View {

    let session: CountSession

    @StateObject private var viewModel = LiveCountViewModel()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            // Camera preview layer
            if viewModel.isCameraAvailable && !viewModel.isCameraPermissionDenied {
                CameraPreviewView(captureSession: viewModel.captureSession)
                    .ignoresSafeArea()

                // Bounding box overlay
                GeometryReader { geometry in
                    ForEach(viewModel.filteredDetections) { detection in
                        LiveBoundingBoxView(
                            detection: detection,
                            canvasSize: geometry.size
                        )
                    }
                }
                .ignoresSafeArea()

                // Frozen frame overlay
                if viewModel.isFrozen, let frozen = viewModel.frozenFrame {
                    Image(uiImage: frozen)
                        .resizable()
                        .scaledToFill()
                        .ignoresSafeArea()
                        .overlay(
                            Text("FROZEN")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundStyle(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Capsule().fill(Color.blue.opacity(0.8)))
                                .padding(12),
                            alignment: .topLeading
                        )
                }

            } else {
                unavailableView
            }

            // HUD overlay
            VStack {
                // Top bar: dismiss + tally
                topBar

                Spacer()

                // Bottom controls
                bottomControls
            }
        }
        .onAppear { viewModel.startSession() }
        .onDisappear { viewModel.stopSession() }
        .alert(
            "Error",
            isPresented: Binding(
                get: { viewModel.error != nil },
                set: { if !$0 { viewModel.error = nil } }
            ),
            presenting: viewModel.error
        ) { _ in
            Button("OK", role: .cancel) { viewModel.error = nil }
            if viewModel.isCameraPermissionDenied {
                Button("Open Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
            }
        } message: { error in
            Text(error.localizedDescription)
        }
    }

    // MARK: - Top bar

    private var topBar: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.white)
                    .shadow(radius: 2)
            }
            .accessibilityLabel("Close live camera")
            .padding()

            Spacer()

            // Live tally HUD
            if !viewModel.liveTally.isEmpty {
                VStack(alignment: .trailing, spacing: 4) {
                    ForEach(viewModel.liveTally.sorted(by: { $0.key < $1.key }), id: \.key) { label, count in
                        HStack(spacing: 6) {
                            Text(label)
                                .font(.caption)
                                .foregroundStyle(.white)
                            Text("\(count)")
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
                .accessibilityLabel("Live tally: \(viewModel.liveTally.map { "\($0.value) \($0.key)" }.joined(separator: ", "))")
            }
        }
    }

    // MARK: - Bottom controls

    private var bottomControls: some View {
        VStack(spacing: 12) {
            // Confidence slider
            HStack(spacing: 12) {
                Image(systemName: "slider.horizontal.3")
                    .foregroundStyle(.white)
                    .accessibilityHidden(true)
                Slider(
                    value: Binding(
                        get: { Double(viewModel.confidenceThreshold) },
                        set: { viewModel.confidenceThreshold = Float($0) }
                    ),
                    in: 0.1...0.9,
                    step: 0.05
                )
                .tint(.white)
                .accessibilityLabel("Confidence threshold")
                .accessibilityValue("\(Int(viewModel.confidenceThreshold * 100)) percent")
                Text("\(Int(viewModel.confidenceThreshold * 100))%")
                    .font(.caption.bold())
                    .foregroundStyle(.white)
                    .monospacedDigit()
                    .frame(width: 36)
            }
            .padding(.horizontal, 20)

            // Action buttons row
            HStack(spacing: 40) {
                // Camera switch
                Button {
                    viewModel.switchCamera()
                } label: {
                    Image(systemName: "arrow.triangle.2.circlepath.camera")
                        .font(.title2)
                        .foregroundStyle(.white)
                        .frame(width: 56, height: 56)
                        .background(Circle().fill(Color.black.opacity(0.5)))
                }
                .accessibilityLabel("Switch camera")
                .disabled(viewModel.isFrozen)

                // Freeze / Unfreeze
                Button {
                    if viewModel.isFrozen {
                        viewModel.unfreeze()
                    } else {
                        viewModel.freeze()
                    }
                } label: {
                    Image(systemName: viewModel.isFrozen ? "play.circle.fill" : "pause.circle.fill")
                        .font(.system(size: 64))
                        .foregroundStyle(.white)
                        .shadow(radius: 4)
                }
                .accessibilityLabel(viewModel.isFrozen ? "Resume live feed" : "Freeze frame")

                // Save frozen frame
                Button {
                    Task {
                        try? await viewModel.saveFrameToSession(session)
                    }
                } label: {
                    Image(systemName: "square.and.arrow.down")
                        .font(.title2)
                        .foregroundStyle(.white)
                        .frame(width: 56, height: 56)
                        .background(Circle().fill(Color.black.opacity(0.5)))
                }
                .accessibilityLabel("Save frozen frame to session")
                .disabled(!viewModel.isFrozen)
                .opacity(viewModel.isFrozen ? 1.0 : 0.4)
            }
        }
        .padding(.bottom, 40)
        .background(
            LinearGradient(
                colors: [.clear, .black.opacity(0.6)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        )
    }

    // MARK: - Unavailable view

    private var unavailableView: some View {
        VStack(spacing: 20) {
            Image(systemName: "camera.slash")
                .font(.system(size: 64))
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)

            if viewModel.isCameraPermissionDenied {
                Text("Camera Access Required")
                    .font(.title2.bold())
                Text("OpenCount needs camera access for live counting.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                Button("Open Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                .buttonStyle(.borderedProminent)
            } else {
                Text("Camera Unavailable")
                    .font(.title2.bold())
                Text("This device does not support the required camera capabilities for live counting.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Button("Close") { dismiss() }
                .buttonStyle(.bordered)
        }
        .padding(32)
    }
}

// MARK: - CameraPreviewView

/// UIViewRepresentable wrapping AVCaptureVideoPreviewLayer.
/// Requirement 9.1: display live camera preview.
struct CameraPreviewView: UIViewRepresentable {

    let captureSession: AVCaptureSession

    func makeUIView(context: Context) -> PreviewUIView {
        let view = PreviewUIView()
        view.previewLayer.session = captureSession
        view.previewLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ uiView: PreviewUIView, context: Context) {
        uiView.previewLayer.session = captureSession
    }

    final class PreviewUIView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        var previewLayer: AVCaptureVideoPreviewLayer {
            guard let layer = layer as? AVCaptureVideoPreviewLayer else {
                fatalError("PreviewUIView must use AVCaptureVideoPreviewLayer")
            }
            return layer
        }
    }
}

// MARK: - LiveBoundingBoxView

/// Renders a single live detection bounding box with label and confidence.
/// Requirement 9.2: display bounding boxes and tallies overlaid on the live preview.
struct LiveBoundingBoxView: View {

    let detection: AIDetection
    let canvasSize: CGSize

    private var boxRect: CGRect {
        CGRect(
            x: detection.normalizedBoundingBox.minX * canvasSize.width,
            y: detection.normalizedBoundingBox.minY * canvasSize.height,
            width: detection.normalizedBoundingBox.width * canvasSize.width,
            height: detection.normalizedBoundingBox.height * canvasSize.height
        )
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            Rectangle()
                .strokeBorder(Color.green, lineWidth: 2)
                .background(Rectangle().fill(Color.green.opacity(0.08)))
                .frame(width: boxRect.width, height: boxRect.height)
                .position(x: boxRect.midX, y: boxRect.midY)

            HStack(spacing: 4) {
                Text(detection.label)
                    .font(.system(size: 10, weight: .semibold))
                Text("\(Int(detection.confidenceScore * 100))%")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .monospacedDigit()
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(Capsule().fill(Color.green.opacity(0.85)))
            .position(
                x: boxRect.minX + 40,
                y: boxRect.minY - 10
            )
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(detection.label), \(Int(detection.confidenceScore * 100)) percent confidence")
    }
}
