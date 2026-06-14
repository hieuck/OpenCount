package com.opencount.shared.service

import com.opencount.shared.model.AIDetection
import com.opencount.shared.model.NormalizedRect

data class DetectionConfig(
    val confidenceThreshold: Float = 0.5f,
    val maxDetections: Int = 100,
    val iouThreshold: Float = 0.5f,
)

interface AIService {
    suspend fun detect(
        imageBytes: ByteArray,
        config: DetectionConfig = DetectionConfig(),
    ): List<AIDetection>

    suspend fun warmUp()
}

object NMS {
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
