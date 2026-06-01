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
