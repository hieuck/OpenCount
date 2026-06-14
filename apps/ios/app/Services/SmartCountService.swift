import Foundation
import CoreGraphics
import UIKit

// MARK: - SmartCountService

/// Provides duplicate detection and "Find Missed Objects" functionality.
///
/// Requirements: 35.1–35.5
final class SmartCountService {

    // MARK: - Duplicate detection

    /// Returns true if `newPoint` is within `duplicateRadius` of any existing marker
    /// of the same Object_Type (Euclidean distance in normalized coordinates).
    ///
    /// Requirement 35.1: warn when a new marker is placed within 20 normalized pixels
    /// of an existing marker of the same type.
    func isDuplicate(
        newPoint: CGPoint,
        existingMarkers: [CountMarker],
        objectType: ObjectType,
        duplicateRadius: Double = 0.02
    ) -> Bool {
        for marker in existingMarkers where marker.objectType.id == objectType.id {
            let dx = newPoint.x - marker.normalizedX
            let dy = newPoint.y - marker.normalizedY
            let distance = sqrt(dx * dx + dy * dy)
            if distance < duplicateRadius {
                return true
            }
        }
        return false
    }

    // MARK: - Find missed objects

    /// Runs AI at a low confidence threshold and returns detections not already
    /// covered by existing markers.
    ///
    /// Requirement 35.2, 35.3: secondary AI pass at threshold 0.2, highlight
    /// detections not covered by existing markers.
    func findMissedObjects(
        in image: UIImage,
        existingMarkers: [CountMarker],
        aiService: AIServiceProtocol,
        lowThreshold: Float = 0.2,
        coverageRadius: Double = 0.02
    ) async throws -> [AIDetection] {
        let allDetections = try await aiService.detect(in: image, confidenceThreshold: lowThreshold)

        // Filter out detections already covered by an existing marker
        return allDetections.filter { detection in
            let centroid = detection.normalizedCentroid
            return !existingMarkers.contains { marker in
                let dx = centroid.x - marker.normalizedX
                let dy = centroid.y - marker.normalizedY
                let distance = sqrt(dx * dx + dy * dy)
                return distance < coverageRadius
            }
        }
    }
}

// MARK: - Density-based auto-grid

extension SmartCountService {

    /// Analyzes the spatial distribution of markers and suggests an optimal grid
    /// density in the range 2–20.
    ///
    /// The heuristic divides the canvas into candidate grid sizes and picks the
    /// density whose average cell population is closest to 5 markers per cell —
    /// a density that keeps each cell visually manageable without being too sparse.
    ///
    /// - Parameters:
    ///   - markers: The current set of placed markers (normalized coordinates).
    ///   - canvasSize: The pixel dimensions of the canvas (used for aspect-ratio
    ///                 weighting; pass `.zero` to treat the canvas as square).
    /// - Returns: Suggested grid density (number of rows/columns), clamped to 2–20.
    func suggestGridDensity(for markers: [CountMarker], canvasSize: CGSize) -> Int {
        guard !markers.isEmpty else { return 5 }

        let targetMarkersPerCell: Double = 5.0
        let count = Double(markers.count)

        // Ideal total cells = total markers / target-per-cell
        let idealCells = count / targetMarkersPerCell

        // density^2 ≈ idealCells  →  density ≈ sqrt(idealCells)
        let rawDensity = sqrt(idealCells)

        // Adjust for non-square canvases: if the canvas is wider than tall, prefer
        // a slightly higher density so cells remain roughly square.
        var aspectAdjustment: Double = 1.0
        if canvasSize.height > 0 && canvasSize.width > 0 {
            let ratio = Double(canvasSize.width / canvasSize.height)
            aspectAdjustment = max(1.0, sqrt(ratio))
        }

        let adjusted = rawDensity * aspectAdjustment
        let clamped = Int(adjusted.rounded()).clamped(to: 2...20)
        return clamped
    }

    /// Groups nearby markers into clusters using a simple single-linkage
    /// distance-based algorithm (normalized coordinate space).
    ///
    /// Two markers are considered neighbours if their Euclidean distance in
    /// normalized coordinates is less than `clusterRadius`.  The algorithm
    /// performs a breadth-first flood-fill so that transitively close markers
    /// end up in the same cluster.
    ///
    /// - Parameters:
    ///   - markers: The markers to cluster.
    ///   - clusterRadius: Maximum normalized distance between two markers for
    ///                    them to be considered part of the same cluster.
    ///                    Defaults to 0.05 (5 % of the image dimension).
    /// - Returns: An array of clusters, each cluster being an array of markers.
    func detectClusters(
        in markers: [CountMarker],
        clusterRadius: Double = 0.05
    ) -> [[CountMarker]] {
        guard !markers.isEmpty else { return [] }

        var visited = Set<UUID>()
        var clusters: [[CountMarker]] = []

        for seed in markers {
            guard !visited.contains(seed.id) else { continue }

            // BFS from this seed
            var cluster: [CountMarker] = []
            var queue: [CountMarker] = [seed]
            visited.insert(seed.id)

            while !queue.isEmpty {
                let current = queue.removeFirst()
                cluster.append(current)

                for candidate in markers where !visited.contains(candidate.id) {
                    let dx = current.normalizedX - candidate.normalizedX
                    let dy = current.normalizedY - candidate.normalizedY
                    let distance = sqrt(dx * dx + dy * dy)
                    if distance < clusterRadius {
                        visited.insert(candidate.id)
                        queue.append(candidate)
                    }
                }
            }

            clusters.append(cluster)
        }

        return clusters
    }

    /// Estimates the total object count in an image by extrapolating from a
    /// sampled sub-area.
    ///
    /// Uses the formula:  estimatedTotal = detected × (imageArea / sampleArea)
    /// with a small Poisson-style correction for sampling variance.
    ///
    /// - Parameters:
    ///   - detected: Number of objects counted in the sampled area.
    ///   - imageArea: Total area of the image in consistent units (e.g. px²).
    ///   - sampleArea: Area of the sampled region in the same units.
    /// - Returns: Estimated total count rounded to the nearest integer.
    ///            Returns `detected` unchanged if `sampleArea` ≥ `imageArea`.
    func estimateMissedCount(
        detected: Int,
        imageArea: CGFloat,
        sampleArea: CGFloat
    ) -> Int {
        guard sampleArea > 0, imageArea > sampleArea else { return detected }

        let scaleFactor = Double(imageArea / sampleArea)
        let rawEstimate = Double(detected) * scaleFactor

        // Poisson variance correction: add half a standard deviation to avoid
        // systematic under-counting when the sample is small.
        let poissonCorrection = sqrt(rawEstimate) * 0.5
        let corrected = rawEstimate + poissonCorrection

        return max(detected, Int(corrected.rounded()))
    }
}

// MARK: - CountingVelocityTracker

/// Tracks counting velocity (markers placed per minute) using a sliding 60-second window.
///
/// Requirement 35.4: display a fatigue warning if the user places more than 60 markers
/// per minute for more than 2 consecutive minutes.
final class CountingVelocityTracker {

    // MARK: - Configuration

    /// The sliding window duration in seconds.
    private let windowDuration: TimeInterval = 60.0

    /// The velocity threshold (markers per minute) that triggers a warning.
    private let velocityThreshold: Double = 60.0

    /// How long (in seconds) the velocity must exceed the threshold before a warning fires.
    private let sustainedDuration: TimeInterval = 120.0

    // MARK: - State

    /// Timestamps of recent marker placements within the sliding window.
    private var timestamps: [Date] = []

    /// When the velocity first exceeded the threshold (nil if not currently exceeded).
    private var thresholdExceededSince: Date?

    // MARK: - Public API

    /// Records a new marker placement at the current time.
    func recordPlacement() {
        let now = Date()
        timestamps.append(now)
        pruneOldTimestamps(before: now.addingTimeInterval(-windowDuration))
    }

    /// Returns the current velocity in markers per minute.
    var currentVelocity: Double {
        let now = Date()
        pruneOldTimestamps(before: now.addingTimeInterval(-windowDuration))
        // markers per 60-second window = markers per minute
        return Double(timestamps.count)
    }

    /// Returns true if the fatigue warning should be shown.
    func updateFatigueState() -> Bool {
        let velocity = currentVelocity
        let now = Date()

        if velocity > velocityThreshold {
            if thresholdExceededSince == nil {
                thresholdExceededSince = now
            }
            if let since = thresholdExceededSince,
               now.timeIntervalSince(since) >= sustainedDuration {
                return true
            }
        } else {
            thresholdExceededSince = nil
        }
        return false
    }

    /// Resets the tracker state.
    func reset() {
        timestamps = []
        thresholdExceededSince = nil
    }

    // MARK: - Private

    private func pruneOldTimestamps(before cutoff: Date) {
        timestamps = timestamps.filter { $0 >= cutoff }
    }
}
