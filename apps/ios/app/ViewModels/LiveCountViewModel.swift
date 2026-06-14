import Foundation
import AVFoundation
import UIKit
import Combine

// MARK: - LiveCountViewModel

/// Manages the AVCaptureSession pipeline for live camera counting.
///
/// - Runs `CoreMLAIService.detect` on each captured frame on a background queue,
///   throttled to 15 fps (frames are dropped when inference is still running).
/// - Publishes live detections, frozen-frame state, and confidence threshold.
/// - Handles camera permission denial and devices without required capabilities.
///
/// Requirements: 9.1, 9.2, 9.3, 9.4, 9.5, 9.6, 9.7, 9.8
@MainActor
final class LiveCountViewModel: NSObject, ObservableObject {

    // MARK: - Published state

    /// Live AI detections from the most recent processed frame.
    /// Requirement 9.2: display bounding boxes and tallies overlaid on the live preview.
    @Published var liveDetections: [AIDetection] = []

    /// Whether the live feed is currently frozen.
    /// Requirement 9.4: allow the user to freeze the live feed.
    @Published var isFrozen: Bool = false

    /// The frozen frame captured when `freeze()` is called.
    /// Requirement 9.4, 9.5: save the frozen frame as a new image in the current session.
    @Published var frozenFrame: UIImage?

    /// Confidence threshold for filtering live detections (0.1–0.9).
    /// Requirement 9.6: adjust confidence threshold without interrupting the live feed.
    @Published var confidenceThreshold: Float = 0.5

    /// Whether the capture session is running.
    @Published var isSessionRunning: Bool = false

    /// Whether the device supports the required camera capabilities.
    /// Requirement 9.8: display informative message if device lacks camera capabilities.
    @Published var isCameraAvailable: Bool = true

    /// Whether camera permission has been denied.
    @Published var isCameraPermissionDenied: Bool = false

    /// Current error, if any.
    @Published var error: AppError?

    /// Whether AI inference is currently running on a frame.
    @Published var isInferenceRunning: Bool = false

    // MARK: - AVFoundation

    /// The capture session. Exposed so the preview layer can attach to it.
    nonisolated(unsafe) let captureSession = AVCaptureSession()

    // MARK: - Private

    private let aiService = CoreMLAIService()
    private let sessionQueue = DispatchQueue(label: "com.opencount.captureSession",
                                             qos: .userInitiated)

    /// The currently active camera position.
    private var currentCameraPosition: AVCaptureDevice.Position = .back

    /// The current video data output.
    private var videoDataOutput: AVCaptureVideoDataOutput?

    /// Timestamp of the last frame sent to inference (used for 15 fps throttle).
    private var lastInferenceTime: CFTimeInterval = 0

    /// Minimum interval between inference calls: 1/15 ≈ 66.7 ms.
    private let inferenceInterval: CFTimeInterval = 1.0 / 15.0

    /// Whether an inference call is currently in flight (prevents concurrent calls).
    private var inferenceInFlight: Bool = false

    /// The most recent pixel buffer captured (used by `freeze()`).
    private var latestPixelBuffer: CVPixelBuffer?

    // MARK: - Init

    override init() {
        super.init()
    }

    // MARK: - Session lifecycle

    /// Requests camera permission and configures the capture session.
    ///
    /// Requirement 9.1: activate the device camera and run continuous AI detection.
    /// Requirement 9.8: handle devices without required camera capabilities.
    func startSession() {
        checkCameraCapabilities()
        guard isCameraAvailable else { return }

        let status = AVCaptureDevice.authorizationStatus(for: .video)
        switch status {
        case .authorized:
            sessionQueue.async { [weak self] in
                Task { @MainActor [weak self] in
                    self?.configureAndStartSession()
                }
            }
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                if granted {
                    self?.sessionQueue.async { [weak self] in
                        Task { @MainActor [weak self] in
                            self?.configureAndStartSession()
                        }
                    }
                } else {
                    Task { @MainActor [weak self] in
                        self?.isCameraPermissionDenied = true
                        self?.error = .cameraPermissionDenied
                    }
                }
            }
        case .denied, .restricted:
            Task { @MainActor in
                self.isCameraPermissionDenied = true
                self.error = .cameraPermissionDenied
            }
        @unknown default:
            break
        }
    }

    /// Stops the capture session and cleans up.
    func stopSession() {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            if self.captureSession.isRunning {
                self.captureSession.stopRunning()
            }
            Task { @MainActor in
                self.isSessionRunning = false
            }
        }
    }

    // MARK: - Freeze

    /// Captures the current frame as a `UIImage` and sets `isFrozen = true`.
    ///
    /// Requirement 9.4: freeze the live feed and switch to manual editing mode.
    /// Requirement 9.5: save the frozen frame as a new image in the current session.
    func freeze() {
        guard !isFrozen else { return }
        guard let pixelBuffer = latestPixelBuffer else { return }

        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let context = CIContext()
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else { return }
        let image = UIImage(cgImage: cgImage)

        frozenFrame = image
        isFrozen = true

        // Pause the capture session while frozen.
        sessionQueue.async { [weak self] in
            self?.captureSession.stopRunning()
            Task { @MainActor [weak self] in
                self?.isSessionRunning = false
            }
        }
    }

    /// Unfreezes the live feed and resumes the capture session.
    func unfreeze() {
        guard isFrozen else { return }
        frozenFrame = nil
        isFrozen = false
        liveDetections = []

        sessionQueue.async { [weak self] in
            guard let self else { return }
            if !self.captureSession.isRunning {
                self.captureSession.startRunning()
            }
            Task { @MainActor in
                self.isSessionRunning = true
            }
        }
    }

    // MARK: - Camera switch

    /// Toggles between front and rear cameras.
    ///
    /// Requirement 9.7: allow the user to switch between front and rear cameras.
    func switchCamera() {
        let newPosition: AVCaptureDevice.Position =
            currentCameraPosition == .back ? .front : .back
        currentCameraPosition = newPosition

        sessionQueue.async { [weak self] in
            guard let self else { return }
            self.captureSession.beginConfiguration()
            defer { self.captureSession.commitConfiguration() }

            // Remove existing video inputs.
            for input in self.captureSession.inputs {
                self.captureSession.removeInput(input)
            }

            // Add the new camera input.
            guard let device = AVCaptureDevice.default(
                .builtInWideAngleCamera,
                for: .video,
                position: newPosition
            ),
            let input = try? AVCaptureDeviceInput(device: device),
            self.captureSession.canAddInput(input) else {
                // Fall back to the previous position if the new one is unavailable.
                Task { @MainActor [weak self] in
                    self?.currentCameraPosition = newPosition == .back ? .front : .back
                }
                return
            }
            self.captureSession.addInput(input)
        }
    }

    // MARK: - Save frozen frame to session

    /// Saves the frozen frame as a `SessionImage` in the given `CountSession`.
    ///
    /// Requirement 9.5: save the frozen frame as a new image in the current session.
    func saveFrameToSession(_ session: CountSession) async throws {
        guard let image = frozenFrame else { return }

        // Write the image to the app's Documents/images/ directory.
        let filename = "live_\(UUID().uuidString).jpg"
        let documentsURL = FileManager.default.urls(for: .documentDirectory,
                                                     in: .userDomainMask)[0]
        let imagesDir = documentsURL.appendingPathComponent("images", isDirectory: true)
        try FileManager.default.createDirectory(at: imagesDir,
                                                withIntermediateDirectories: true)
        let fileURL = imagesDir.appendingPathComponent(filename)

        guard let jpegData = image.jpegData(compressionQuality: 0.85) else {
            throw AppError.exportWriteFailure(reason: "Could not encode frozen frame as JPEG.")
        }
        try jpegData.write(to: fileURL)

        let sessionImage = SessionImage(filename: filename, session: session)
        session.images.append(sessionImage)
        session.modifiedAt = Date()
    }

    // MARK: - Computed

    /// Live detections filtered by the current confidence threshold.
    var filteredDetections: [AIDetection] {
        liveDetections.filter { $0.confidenceScore >= confidenceThreshold }
    }

    /// Global tally of filtered live detections grouped by label.
    var liveTally: [String: Int] {
        var tally: [String: Int] = [:]
        for detection in filteredDetections {
            tally[detection.label, default: 0] += 1
        }
        return tally
    }

    // MARK: - Private: session configuration

    /// Configures the `AVCaptureSession` with a video input and `AVCaptureVideoDataOutput`.
    private func configureAndStartSession() {
        captureSession.beginConfiguration()
        defer { captureSession.commitConfiguration() }

        // Prefer 1280×720 for a good balance of quality and inference speed.
        captureSession.sessionPreset = .hd1280x720

        // Add video input.
        guard let device = AVCaptureDevice.default(
            .builtInWideAngleCamera,
            for: .video,
            position: currentCameraPosition
        ),
        let input = try? AVCaptureDeviceInput(device: device),
        captureSession.canAddInput(input) else {
            Task { @MainActor in
                self.isCameraAvailable = false
            }
            return
        }
        captureSession.addInput(input)

        // Add video data output.
        let output = AVCaptureVideoDataOutput()
        output.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ]
        output.alwaysDiscardsLateVideoFrames = true
        output.setSampleBufferDelegate(self, queue: sessionQueue)

        guard captureSession.canAddOutput(output) else {
            Task { @MainActor in
                self.isCameraAvailable = false
            }
            return
        }
        captureSession.addOutput(output)
        videoDataOutput = output

        // Set video orientation to portrait.
        if let connection = output.connection(with: .video) {
            if #available(iOS 17.0, *) {
                if connection.isVideoRotationAngleSupported(90) {
                    connection.videoRotationAngle = 90
                }
            } else {
                if connection.isVideoOrientationSupported {
                    connection.videoOrientation = .portrait
                }
            }
        }

        captureSession.startRunning()
        Task { @MainActor in
            self.isSessionRunning = true
        }
    }

    // MARK: - Private: capability check

    /// Checks whether the device has a usable camera.
    ///
    /// Requirement 9.8: display informative message if device lacks camera capabilities.
    private func checkCameraCapabilities() {
        let hasRearCamera = AVCaptureDevice.default(
            .builtInWideAngleCamera, for: .video, position: .back) != nil
        let hasFrontCamera = AVCaptureDevice.default(
            .builtInWideAngleCamera, for: .video, position: .front) != nil

        isCameraAvailable = hasRearCamera || hasFrontCamera

        // Default to front if rear is unavailable.
        if !hasRearCamera && hasFrontCamera {
            currentCameraPosition = .front
        }
    }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate

extension LiveCountViewModel: AVCaptureVideoDataOutputSampleBufferDelegate {

    /// Called on `sessionQueue` for every captured video frame.
    ///
    /// Throttles inference to 15 fps and drops frames when inference is in flight.
    ///
    /// Requirement 9.3: update the live detection overlay at a minimum of 15 fps.
    nonisolated func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            let now = CACurrentMediaTime()
            guard now - self.lastInferenceTime >= self.inferenceInterval,
                  !self.inferenceInFlight else { return }
            guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
            self.latestPixelBuffer = pixelBuffer
            self.lastInferenceTime = now
            self.inferenceInFlight = true
            let threshold = self.confidenceThreshold
            let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
            let context = CIContext()
            guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else {
                self.inferenceInFlight = false
                return
            }
            let image = UIImage(cgImage: cgImage)
            do {
                let detections = try await self.aiService.detect(
                    in: image,
                    confidenceThreshold: threshold
                )
                self.liveDetections = detections
                self.inferenceInFlight = false
            } catch {
                self.inferenceInFlight = false
            }
        }
    }
}
