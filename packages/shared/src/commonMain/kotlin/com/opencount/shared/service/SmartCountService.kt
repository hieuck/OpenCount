package com.opencount.shared.service

import com.opencount.shared.model.CountMarker
import com.opencount.shared.model.NormalizedPoint
import kotlin.math.*

/**
 * Service providing smart counting utilities: duplicate detection, clustering, grid density suggestions,
 * and missed-count estimation based on area sampling.
 */
class SmartCountService(private val duplicateRadius: Double = 0.05) {

    /**
     * Checks whether a new marker point is a duplicate of existing markers of the same type.
     * Uses Euclidean distance in normalized coordinates.
     * @return true if a marker of the same [objectTypeId] exists within [duplicateRadius]
     */
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

    /**
     * Groups nearby markers into spatial clusters using a flood-fill approach.
     * @param clusterRadius the maximum normalized distance between markers in the same cluster
     * @return list of clusters, each containing a group of nearby markers
     */
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

    /**
     * Suggests an appropriate grid overlay density for a canvas of the given dimensions.
     * @return a grid count between 3 and 20, proportional to the square root of the canvas area
     */
    fun suggestGridDensity(canvasWidth: Double, canvasHeight: Double): Int {
        val area = canvasWidth * canvasHeight
        return sqrt(area).toInt().coerceAtLeast(3).coerceAtMost(20)
    }

    /**
     * Estimates the number of missed counts by extrapolating from a sampled area to the full image.
     * @param detected number of objects detected in the sampled area
     * @param imageArea total area of the full image
     * @param sampleArea area that was actually sampled
     * @return estimated count of undetected objects (always >= 0); returns 0 if inputs are invalid
     */
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

/**
 * Tracks the rate of marker placement over a rolling time window.
 * Useful for detecting user fatigue (rapid, potentially erroneous tapping) during counting sessions.
 */
class CountingVelocityTracker(private val windowSeconds: Long = 120) {
    private val events = ArrayDeque<Pair<Long, Int>>()

    /** Records a marker placement event at the given [timestamp] (epoch seconds). */
    fun recordMarker(timestamp: Long = currentTimeSeconds()) {
        prune(timestamp)
        events.addLast(Pair(timestamp, 1))
    }

    /**
     * Calculates the current marker placement rate in markers per minute.
     * Based on events within the rolling time window.
     */
    fun markersPerMinute(): Double {
        val now = currentTimeSeconds()
        prune(now)
        if (events.isEmpty()) return 0.0
        val span = now - (events.first().first).coerceAtLeast(1)
        val total = events.sumOf { it.second }
        return total.toDouble() / span.toDouble() * 60.0
    }

    /** Returns true if the user is placing markers faster than the [threshold] (markers per minute). */
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
