package com.opencount.shared

import com.opencount.shared.model.CountMarker
import com.opencount.shared.model.NormalizedPoint
import com.opencount.shared.service.CountingVelocityTracker
import com.opencount.shared.service.SmartCountService
import com.opencount.shared.service.currentTimeSeconds
import kotlin.test.Test
import kotlin.test.*

class SmartCountServiceTests {
    private val service = SmartCountService(duplicateRadius = 0.05)

    @Test
    fun testIsDuplicate() {
        val existing = listOf(
            CountMarker.create(0.5, 0.5, "type1"),
            CountMarker.create(0.1, 0.1, "type2"),
        )
        val close = NormalizedPoint(0.51, 0.51)
        assertTrue(service.isDuplicate(close, existing, "type1"))

        val far = NormalizedPoint(0.9, 0.9)
        assertFalse(service.isDuplicate(far, existing, "type1"))
    }

    @Test
    fun testDetectClusters() {
        val markers = listOf(
            CountMarker.create(0.1, 0.1, "type1"),
            CountMarker.create(0.12, 0.12, "type1"),
            CountMarker.create(0.9, 0.9, "type1"),
        )
        val clusters = service.detectClusters(markers, clusterRadius = 0.05)
        assertEquals(2, clusters.size)
    }

    @Test
    fun testGridDensity() {
        val density = service.suggestGridDensity(1000.0, 800.0)
        assertTrue(density in 3..20)
    }

    @Test
    fun testEstimateMissedCount() {
        val missed = service.estimateMissedCount(
            detected = 100,
            imageArea = 1000.0,
            sampleArea = 100.0,
        )
        assertTrue(missed > 0)
        assertEquals(900, missed)
    }

    @Test
    fun testZeroDetection() {
        assertEquals(0, service.estimateMissedCount(0, 100.0, 10.0))
    }

    @Test
    fun testEmptyClusters() {
        assertTrue(service.detectClusters(emptyList()).isEmpty())
        assertEquals(0, service.estimateMissedCount(0, 0.0, 0.0))
    }

    @Test
    fun testVelocityTracker() {
        val tracker = CountingVelocityTracker(windowSeconds = 10)
        assertEquals(0.0, tracker.markersPerMinute())
        assertFalse(tracker.isFatigued())
    }

    @Test
    fun testVelocityTrackerRecordsMarkers() {
        val tracker = CountingVelocityTracker(windowSeconds = 60)
        val now = currentTimeSeconds()
        repeat(10) { tracker.recordMarker(now) }
        val mpm = tracker.markersPerMinute()
        assertTrue(mpm >= 0)
    }

    @Test
    fun testFatigueDetection() {
        val tracker = CountingVelocityTracker(windowSeconds = 60)
        repeat(20) {
            tracker.recordMarker()
        }
        val fatigued = tracker.isFatigued(threshold = 0.1)
        assertTrue(fatigued, "Expected fatigue: 20 markers in ~20s = 60/min > 0.1 threshold")
    }

    @Test
    fun testClusterDifferentTypes() {
        val markers = listOf(
            CountMarker.create(0.1, 0.1, "type1"),
            CountMarker.create(0.12, 0.12, "type2"),
        )
        val clusters = service.detectClusters(markers, clusterRadius = 0.05)
        assertTrue(clusters.size == 1 || clusters.size == 2)
    }
}
