import Foundation
import SwiftUI
import ARKit
import Combine

// MARK: - ARCountAnchor

/// A counted object anchor placed in AR world space.
struct ARCountAnchor: Identifiable {
    let id: UUID
    let worldTransform: simd_float4x4
    let objectType: ObjectType
    var distanceMeters: Float
    let createdAt: Date
}

// MARK: - ARCountViewModel

/// Manages the ARKit session for augmented reality counting.
///
/// Requirements: 19.1–19.8
@MainActor
final class ARCountViewModel: ObservableObject {

    // MARK: - Published state

    @Published var arAnchors: [ARCountAnchor] = []
    @Published var isARSupported: Bool = false
    @Published var selectedObjectType: ObjectType?
    @Published var error: AppError?
    @Published var isSessionRunning: Bool = false
    @Published var cameraDistanceMeters: Float = 0.0

    // MARK: - AR Session (exposed for ARSCNView binding)

    let arSession = ARSession()

    // MARK: - Private

    private var configuration: ARWorldTrackingConfiguration?

    // MARK: - Init

    init() {
        isARSupported = ARWorldTrackingConfiguration.isSupported
    }

    // MARK: - Session lifecycle

    /// Starts the AR world tracking session.
    /// Requirement 19.1: use ARKit to overlay count markers on detected objects.
    func startARSession() {
        guard isARSupported else { return }
        let config = ARWorldTrackingConfiguration()
        config.planeDetection = [.horizontal, .vertical]
        // Enable scene reconstruction on LiDAR devices (iPhone 12 Pro+)
        // Requirement 19.8: LiDAR-enhanced precision on supported devices.
        if ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh) {
            config.sceneReconstruction = .mesh
        }
        configuration = config
        arSession.run(config, options: [.resetTracking, .removeExistingAnchors])
        isSessionRunning = true
    }

    /// Stops the AR session.
    func stopARSession() {
        arSession.pause()
        isSessionRunning = false
    }

    // MARK: - Anchor placement

    /// Places a 3D anchor at the given raycast result position.
    ///
    /// Requirement 19.2: place a persistent 3D anchor and increment the Tally.
    func placeAnchor(at worldTransform: simd_float4x4) {
        guard let objectType = selectedObjectType else { return }
        let distance = distanceFromCamera(to: worldTransform)
        let anchor = ARCountAnchor(
            id: UUID(),
            worldTransform: worldTransform,
            objectType: objectType,
            distanceMeters: distance,
            createdAt: Date()
        )
        arAnchors.append(anchor)
    }

    /// Removes an anchor by ID.
    func removeAnchor(_ anchor: ARCountAnchor) {
        arAnchors.removeAll { $0.id == anchor.id }
    }

    // MARK: - Snapshot

    /// Captures a snapshot of the AR scene.
    /// Requirement 19.4: capture a snapshot with all anchors rendered.
    func captureSnapshot(from view: UIView) async -> UIImage? {
        return await withCheckedContinuation { continuation in
            DispatchQueue.main.async {
                let renderer = UIGraphicsImageRenderer(bounds: view.bounds)
                let image = renderer.image { _ in
                    view.drawHierarchy(in: view.bounds, afterScreenUpdates: true)
                }
                continuation.resume(returning: image)
            }
        }
    }

    // MARK: - Save to session

    /// Saves all AR-placed anchors as CountMarkers in the current session.
    /// Requirement 19.5: save all AR-placed Count_Markers to the current Session.
    func saveToSession(_ session: CountSession) async throws {
        guard let frame = arSession.currentFrame else {
            // Fallback: save with center coordinates if no AR frame available
            for anchor in arAnchors {
                let marker = CountMarker(
                    normalizedX: 0.5,
                    normalizedY: 0.5,
                    objectType: anchor.objectType,
                    isAIDerived: false,
                    session: session
                )
                session.markers.append(marker)
            }
            session.modifiedAt = Date()
            return
        }

        let camera = frame.camera
        let viewportSize = CGSize(width: 1920, height: 1080) // Standard HD viewport

        for anchor in arAnchors {
            // Project 3D world position to 2D screen coordinates
            let worldPos = simd_float3(
                anchor.worldTransform.columns.3.x,
                anchor.worldTransform.columns.3.y,
                anchor.worldTransform.columns.3.z
            )

            let screenPoint = camera.projectPoint(
                worldPos,
                orientation: .landscapeRight,
                viewportSize: viewportSize
            )

            // Normalize to [0, 1] range
            let normalizedX = Double(screenPoint.x / viewportSize.width).clamped(to: 0...1)
            let normalizedY = Double(screenPoint.y / viewportSize.height).clamped(to: 0...1)

            let marker = CountMarker(
                normalizedX: normalizedX,
                normalizedY: normalizedY,
                objectType: anchor.objectType,
                isAIDerived: false,
                session: session
            )
            session.markers.append(marker)
        }
        session.modifiedAt = Date()
    }

    // MARK: - Computed

    /// Global tally of AR anchors per ObjectType.
    var globalTally: [ObjectType: Int] {
        var tally: [ObjectType: Int] = [:]
        for anchor in arAnchors {
            tally[anchor.objectType, default: 0] += 1
        }
        return tally
    }

    // MARK: - Camera distance

    /// Updates distances from the current camera position to all anchors.
    /// Requirement 19.6: display distance from device to each AR anchor.
    func updateDistances(cameraTransform: simd_float4x4) {
        for i in arAnchors.indices {
            arAnchors[i].distanceMeters = distanceFromCamera(
                cameraTransform: cameraTransform,
                to: arAnchors[i].worldTransform
            )
        }
    }

    // MARK: - Private helpers

    private func distanceFromCamera(to anchorTransform: simd_float4x4) -> Float {
        guard let frame = arSession.currentFrame else { return 0 }
        return distanceFromCamera(cameraTransform: frame.camera.transform, to: anchorTransform)
    }

    private func distanceFromCamera(cameraTransform: simd_float4x4, to anchorTransform: simd_float4x4) -> Float {
        let cameraPos = simd_float3(cameraTransform.columns.3.x,
                                    cameraTransform.columns.3.y,
                                    cameraTransform.columns.3.z)
        let anchorPos = simd_float3(anchorTransform.columns.3.x,
                                    anchorTransform.columns.3.y,
                                    anchorTransform.columns.3.z)
        return simd_distance(cameraPos, anchorPos)
    }
}

// MARK: - Comparable clamped helper

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
