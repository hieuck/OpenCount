import Foundation
import AVFoundation
import UIKit
import SwiftUI

// MARK: - VideoPlayerViewModel

/// Manages video playback, frame-by-frame navigation, and per-frame counting.
///
/// Requirements: 11.1, 11.2, 11.3, 11.4, 11.5, 11.6
@MainActor
final class VideoPlayerViewModel: ObservableObject {

    // MARK: - Published state

    @Published var currentFrame: UIImage?
    @Published var currentTimestamp: Double = 0.0
    @Published var duration: Double = 0.0
    @Published var frameTimestamps: [Double] = []
    @Published var countedFrames: [VideoFrameCount] = []
    @Published var isProcessingAI: Bool = false
    @Published var aiProgress: Double = 0.0
    @Published var error: AppError?
    @Published var samplingInterval: Double = 1.0 // seconds

    // MARK: - Private

    private var asset: AVAsset?
    private var imageGenerator: AVAssetImageGenerator?
    private let aiService = CoreMLAIService()
    private var autoSamplingTask: Task<Void, Never>?

    // MARK: - Setup

    /// Loads a video asset from a file URL.
    func loadVideo(url: URL) async {
        let asset = AVAsset(url: url)
        self.asset = asset

        do {
            let duration = try await asset.load(.duration)
            self.duration = CMTimeGetSeconds(duration)

            let generator = AVAssetImageGenerator(asset: asset)
            generator.appliesPreferredTrackTransform = true
            generator.requestedTimeToleranceBefore = .zero
            generator.requestedTimeToleranceAfter = CMTime(seconds: 0.1, preferredTimescale: 600)
            self.imageGenerator = generator

            // Extract first frame
            await seekToTime(0.0)
        } catch {
            self.error = .videoFrameExtractionFailure
        }
    }

    // MARK: - Navigation

    /// Seeks to a specific timestamp and extracts the frame.
    /// Requirement 11.1: pause video at any frame and perform counting.
    func seekToTime(_ seconds: Double) async {
        guard let generator = imageGenerator else { return }
        let time = CMTime(seconds: seconds, preferredTimescale: 600)
        currentTimestamp = seconds

        do {
            if #available(iOS 16.0, *) {
                let (cgImage, _) = try await generator.image(at: time)
                currentFrame = UIImage(cgImage: cgImage)
            } else {
                // Fallback for older iOS (shouldn't happen since we target 16+)
                var actualTime = CMTime.zero
                let cgImage = try generator.copyCGImage(at: time, actualTime: &actualTime)
                currentFrame = UIImage(cgImage: cgImage)
            }
        } catch {
            self.error = .videoFrameExtractionFailure
        }
    }

    /// Steps forward by one frame (approximately 1/30s).
    /// Requirement 11.2: step through video frame by frame.
    func stepForward() async {
        let nextTime = min(currentTimestamp + (1.0 / 30.0), duration)
        await seekToTime(nextTime)
    }

    /// Steps backward by one frame.
    /// Requirement 11.2: step through video frame by frame.
    func stepBackward() async {
        let prevTime = max(currentTimestamp - (1.0 / 30.0), 0.0)
        await seekToTime(prevTime)
    }

    // MARK: - Manual counting on frame

    /// Saves counting results for the current frame.
    /// Requirement 11.3: store counting result associated with the frame timestamp.
    func saveCountsForCurrentFrame(markers: [CountMarker], session: CountSession) {
        // Remove existing entry for this timestamp (within 0.05s tolerance)
        countedFrames.removeAll { abs($0.timestampSeconds - currentTimestamp) < 0.05 }

        let frameCount = VideoFrameCount(
            timestampSeconds: currentTimestamp,
            markers: markers,
            session: session
        )
        countedFrames.append(frameCount)
        countedFrames.sort { $0.timestampSeconds < $1.timestampSeconds }

        session.videoTimestamps.append(frameCount)
        session.modifiedAt = Date()
    }

    // MARK: - Auto-sampling AI

    /// Runs AI detection on frames sampled at `samplingInterval` seconds.
    /// Requirement 11.4: run AI detection automatically on frames at a configurable interval.
    func startAutoSampling(session: CountSession, confidenceThreshold: Float = 0.5) {
        autoSamplingTask?.cancel()
        isProcessingAI = true
        aiProgress = 0.0

        autoSamplingTask = Task {
            var t = 0.0
            var processed = 0
            let totalFrames = max(1, Int(duration / samplingInterval))

            while t <= duration && !Task.isCancelled {
                await seekToTime(t)

                if let frame = currentFrame {
                    do {
                        let detections = try await aiService.detect(
                            in: frame,
                            confidenceThreshold: confidenceThreshold
                        )
                        // Convert detections to markers for the first object type
                        if let objectType = session.objectTypes.first {
                            let markers = detections.map { det in
                                CountMarker(
                                    normalizedX: Double(det.normalizedCentroid.x),
                                    normalizedY: Double(det.normalizedCentroid.y),
                                    objectType: objectType,
                                    isAIDerived: true,
                                    session: session
                                )
                            }
                            saveCountsForCurrentFrame(markers: markers, session: session)
                        }
                    } catch {
                        // Skip frame on error
                    }
                }

                processed += 1
                aiProgress = Double(processed) / Double(totalFrames)
                t += samplingInterval
            }

            isProcessingAI = false
            aiProgress = 1.0
        }
    }

    func stopAutoSampling() {
        autoSamplingTask?.cancel()
        isProcessingAI = false
    }

    // MARK: - Timeline data

    /// Returns tally-over-time data for charting.
    /// Requirement 11.6: line chart showing count over time per Object_Type.
    func tallyOverTime(for objectType: ObjectType) -> [(timestamp: Double, count: Int)] {
        countedFrames.map { frame in
            let count = frame.markers.filter { $0.objectType.id == objectType.id }.count
            return (timestamp: frame.timestampSeconds, count: count)
        }
    }
}
