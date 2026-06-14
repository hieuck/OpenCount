package com.opencount.shared.model

import kotlinx.serialization.Serializable

@Serializable
enum class RegionShapeType {
    Rectangle,
    Ellipse,
    Polygon,
}

@Serializable
data class NormalizedPoint(
    val x: Double,
    val y: Double,
)

@Serializable
data class CountRegion(
    val id: String,
    val name: String,
    val colorHex: String = "#3399FF",
    val shapeType: RegionShapeType = RegionShapeType.Rectangle,
    val normalizedPoints: List<NormalizedPoint> = emptyList(),
) {
    fun contains(normalizedPoint: NormalizedPoint): Boolean = when (shapeType) {
        RegionShapeType.Rectangle -> containsRectangle(normalizedPoint)
        RegionShapeType.Ellipse -> containsEllipse(normalizedPoint)
        RegionShapeType.Polygon -> containsPolygon(normalizedPoint)
    }

    private fun containsRectangle(point: NormalizedPoint): Boolean {
        if (normalizedPoints.size < 2) return false
        val xs = normalizedPoints.map { it.x }
        val ys = normalizedPoints.map { it.y }
        return point.x > (xs.minOrNull() ?: 0.0) && point.x < (xs.maxOrNull() ?: 0.0)
            && point.y > (ys.minOrNull() ?: 0.0) && point.y < (ys.maxOrNull() ?: 0.0)
    }

    private fun containsEllipse(point: NormalizedPoint): Boolean {
        if (normalizedPoints.size < 2) return false
        val xs = normalizedPoints.map { it.x }
        val ys = normalizedPoints.map { it.y }
        val cx = ((xs.minOrNull() ?: 0.0) + (xs.maxOrNull() ?: 0.0)) / 2.0
        val cy = ((ys.minOrNull() ?: 0.0) + (ys.maxOrNull() ?: 0.0)) / 2.0
        val rx = ((xs.maxOrNull() ?: 0.0) - (xs.minOrNull() ?: 0.0)) / 2.0
        val ry = ((ys.maxOrNull() ?: 0.0) - (ys.minOrNull() ?: 0.0)) / 2.0
        if (rx <= 0.0 || ry <= 0.0) return false
        val dx = (point.x - cx) / rx
        val dy = (point.y - cy) / ry
        return (dx * dx + dy * dy) < 1.0
    }

    private fun containsPolygon(point: NormalizedPoint): Boolean {
        if (normalizedPoints.size < 3) return false
        var inside = false
        var j = normalizedPoints.size - 1
        for (i in normalizedPoints.indices) {
            val pi = normalizedPoints[i]
            val pj = normalizedPoints[j]
            if ((pi.y > point.y) != (pj.y > point.y) &&
                point.x < (pj.x - pi.x) * (point.y - pi.y) / (pj.y - pi.y) + pi.x
            ) {
                inside = !inside
            }
            j = i
        }
        return inside
    }
}
