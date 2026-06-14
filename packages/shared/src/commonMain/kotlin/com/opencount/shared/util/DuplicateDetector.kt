package com.opencount.shared.util

import com.opencount.shared.model.CountMarker
import kotlin.math.sqrt

object DuplicateDetector {
    fun findDuplicates(
        markers: List<CountMarker>,
        threshold: Double = 0.05,
    ): List<Pair<CountMarker, CountMarker>> {
        val duplicates = mutableListOf<Pair<CountMarker, CountMarker>>()
        for (i in markers.indices) {
            for (j in i + 1 until markers.size) {
                val a = markers[i]
                val b = markers[j]
                if (a.objectTypeId != b.objectTypeId) continue
                val dx = a.normalizedX - b.normalizedX
                val dy = a.normalizedY - b.normalizedY
                val distance = sqrt(dx * dx + dy * dy)
                if (distance < threshold) {
                    duplicates.add(Pair(a, b))
                }
            }
        }
        return duplicates
    }

    fun isDuplicate(
        newMarker: CountMarker,
        existingMarkers: List<CountMarker>,
        threshold: Double = 0.05,
    ): Boolean {
        for (marker in existingMarkers) {
            if (marker.objectTypeId != newMarker.objectTypeId) continue
            val dx = marker.normalizedX - newMarker.normalizedX
            val dy = marker.normalizedY - newMarker.normalizedY
            val distance = sqrt(dx * dx + dy * dy)
            if (distance < threshold) return true
        }
        return false
    }
}
