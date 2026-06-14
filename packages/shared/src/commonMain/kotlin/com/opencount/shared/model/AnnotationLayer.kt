package com.opencount.shared.model

import kotlinx.serialization.Serializable
import kotlin.math.sqrt

@Serializable
enum class AnnotationLayerType {
    Markers,
    Regions,
    AIDetections,
    TextLabels,
    MeasureLines,
    Arrows,
    Heatmap,
}

@Serializable
data class TextAnnotation(
    val id: String,
    val normalizedPosition: NormalizedPoint,
    val text: String,
    val fontSize: Double = 16.0,
    val colorHex: String = "#FFFFFF",
)

@Serializable
data class MeasureLine(
    val id: String,
    val startPoint: NormalizedPoint,
    val endPoint: NormalizedPoint,
    val colorHex: String = "#FFFF00",
) {
    val normalizedLength: Double
        get() {
            val dx = endPoint.x - startPoint.x
            val dy = endPoint.y - startPoint.y
            return sqrt(dx * dx + dy * dy)
        }

    val midPoint: NormalizedPoint
        get() = NormalizedPoint(
            x = (startPoint.x + endPoint.x) / 2.0,
            y = (startPoint.y + endPoint.y) / 2.0,
        )
}

@Serializable
data class ArrowAnnotation(
    val id: String,
    val tailPoint: NormalizedPoint,
    val headPoint: NormalizedPoint,
    val colorHex: String = "#FF0000",
)
