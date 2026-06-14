package com.opencount.shared.service

import com.opencount.shared.model.AIDetection
import com.opencount.shared.model.NormalizedRect

/**
 * Configuration for AI-based object detection.
 * Controls confidence threshold, maximum detections, and IoU threshold for NMS.
 */
data class DetectionConfig(
    val confidenceThreshold: Float = 0.5f,
    val maxDetections: Int = 100,
    val iouThreshold: Float = 0.5f,
)

/**
 * Interface for AI-powered object detection.
 * Implementations handle model loading, inference, and result delivery for various platforms.
 */
interface AIService {
    /**
     * Runs object detection on the given image bytes.
     * @param imageBytes raw image data, @param config detection parameters
     * @return list of detected objects with bounding boxes and confidence scores
     */
    suspend fun detect(
        imageBytes: ByteArray,
        config: DetectionConfig = DetectionConfig(),
    ): List<AIDetection>

    /** Pre-loads and warms up the AI model to reduce latency on the first [detect] call. */
    suspend fun warmUp()
}

/**
 * Utility object that performs non-maximum suppression to remove duplicate overlapping detections.
 * Keeps the highest-confidence detection among overlapping boxes.
 */
object NMS {
    /**
     * Applies non-maximum suppression to filter overlapping detections by IoU threshold.
     * @param detections input detections to filter
     * @param iouThreshold minimum IoU for a box to be suppressed
     * @return filtered list of non-overlapping detections sorted by confidence
     */
    fun nonMaximumSuppression(
        detections: List<AIDetection>,
        iouThreshold: Float = 0.5f,
    ): List<AIDetection> {
        val sorted = detections
            .filter { it.confidenceScore >= 0.1f }
            .sortedByDescending { it.confidenceScore }
        val selected = mutableListOf<AIDetection>()

        for (detection in sorted) {
            var suppressed = false
            for (selectedDetection in selected) {
                if (iou(detection.normalizedBoundingBox, selectedDetection.normalizedBoundingBox) > iouThreshold) {
                    suppressed = true
                    break
                }
            }
            if (!suppressed) selected.add(detection)
        }
        return selected
    }

    /**
     * Computes the Intersection over Union (IoU) of two normalized rectangles.
     * @return IoU value between 0 and 1, or 0 if rectangles do not overlap
     */
    fun iou(a: NormalizedRect, b: NormalizedRect): Float {
        val xOverlap = (minOf(a.x + a.width, b.x + b.width) - maxOf(a.x, b.x)).coerceAtLeast(0.0)
        val yOverlap = (minOf(a.y + a.height, b.y + b.height) - maxOf(a.y, b.y)).coerceAtLeast(0.0)
        if (xOverlap <= 0 || yOverlap <= 0) return 0f
        val intersection = xOverlap * yOverlap
        val areaA = a.width * a.height
        val areaB = b.width * b.height
        val union = areaA + areaB - intersection
        return if (union > 0) (intersection / union).toFloat() else 0f
    }
}
