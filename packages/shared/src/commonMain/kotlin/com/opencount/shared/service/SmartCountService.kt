package com.opencount.shared.service

import com.opencount.shared.model.CountMarker
import com.opencount.shared.model.NormalizedPoint
import kotlin.math.*

class SmartCountService(private val duplicateRadius: Double = 0.05) {

    fun isDuplicate(
        newPoint: NormalizedPoint,
        existingMarkers: List<CountMarker>,
        objectTypeId: String,
    ): Boolean {
        for (marker in existingMarkers) {
            if (marker.objectTypeId != objectTypeId) continue
            val dx = marker.normalizedX - newPoint.x
            val dy = marker.normalizedY - newPoint.y
            if (sqrt(dx * dx + dy * dy) < duplicateRadius) return true
        }
        return false
    }

    fun detectClusters(
        markers: List<CountMarker>,
        clusterRadius: Double = 0.1,
    ): List<List<CountMarker>> {
        val unvisited = markers.toMutableList()
        val clusters = mutableListOf<List<CountMarker>>()

        while (unvisited.isNotEmpty()) {
            val seed = unvisited.removeFirst()
            val cluster = mutableListOf(seed)
            val queue = ArrayDeque(listOf(seed))

            while (queue.isNotEmpty()) {
                val current = queue.removeFirst()
                val neighbors = unvisited.filter { marker ->
                    val dx = current.normalizedX - marker.normalizedX
                    val dy = current.normalizedY - marker.normalizedY
                    sqrt(dx * dx + dy * dy) < clusterRadius
                }
                for (neighbor in neighbors) {
                    unvisited.remove(neighbor)
                    cluster.add(neighbor)
                    queue.addLast(neighbor)
                }
            }
            clusters.add(cluster)
        }
        return clusters
    }

    fun suggestGridDensity(canvasWidth: Double, canvasHeight: Double): Int {
        val area = canvasWidth * canvasHeight
        return sqrt(area).toInt().coerceAtLeast(3).coerceAtMost(20)
    }

    fun estimateMissedCount(
        detected: Int,
        imageArea: Double,
        sampleArea: Double,
    ): Int {
        if (imageArea <= 0 || sampleArea <= 0 || detected <= 0) return 0
        val density = detected.toDouble() / sampleArea
        val estimated = (density * imageArea).roundToInt()
        return (estimated - detected).coerceAtLeast(0)
    }
}

class CountingVelocityTracker(private val windowSeconds: Long = 120) {
    private val events = ArrayDeque<Pair<Long, Int>>()

    fun recordMarker(timestamp: Long = currentTimeSeconds()) {
        prune(timestamp)
        events.addLast(Pair(timestamp, 1))
    }

    fun markersPerMinute(): Double {
        val now = currentTimeSeconds()
        prune(now)
        if (events.isEmpty()) return 0.0
        val span = now - (events.first().first).coerceAtLeast(1)
        val total = events.sumOf { it.second }
        return total.toDouble() / span.toDouble() * 60.0
    }

    fun isFatigued(threshold: Double = 60.0): Boolean {
        return markersPerMinute() > threshold
    }

    private fun prune(now: Long) {
        while (events.isNotEmpty() && now - events.first().first > windowSeconds) {
            events.removeFirst()
        }
    }
}

internal fun currentTimeSeconds(): Long =
    kotlinx.datetime.Clock.System.now().toEpochMilliseconds() / 1000
