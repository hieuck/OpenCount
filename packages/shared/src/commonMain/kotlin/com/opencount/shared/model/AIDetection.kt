package com.opencount.shared.model

import kotlinx.serialization.Serializable

@Serializable
data class NormalizedRect(
    val x: Double,
    val y: Double,
    val width: Double,
    val height: Double,
) {
    val midX: Double get() = x + width / 2.0
    val midY: Double get() = y + height / 2.0
}

data class AIDetection(
    val id: String,
    val normalizedBoundingBox: NormalizedRect,
    val label: String,
    val confidenceScore: Float,
    var isAccepted: Boolean = false,
) {
    val normalizedCentroid: NormalizedPoint
        get() = NormalizedPoint(
            x = normalizedBoundingBox.midX,
            y = normalizedBoundingBox.midY,
        )
}
