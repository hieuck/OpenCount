package com.opencount.shared

import com.opencount.shared.model.AIDetection
import com.opencount.shared.model.NormalizedRect
import com.opencount.shared.service.NMS
import kotlin.test.Test
import kotlin.test.*

class AIServiceTests {
    @Test
    fun testNMSEmpty() {
        assertTrue(NMS.nonMaximumSuppression(emptyList()).isEmpty())
    }

    @Test
    fun testNMSNoOverlap() {
        val detections = listOf(
            AIDetection("1", NormalizedRect(0.0, 0.0, 0.1, 0.1), "a", 0.9f),
            AIDetection("2", NormalizedRect(0.5, 0.5, 0.1, 0.1), "b", 0.8f),
        )
        val result = NMS.nonMaximumSuppression(detections)
        assertEquals(2, result.size)
    }

    @Test
    fun testNMSRemovesOverlapping() {
        val detections = listOf(
            AIDetection("1", NormalizedRect(0.0, 0.0, 0.5, 0.5), "a", 0.9f),
            AIDetection("2", NormalizedRect(0.1, 0.1, 0.5, 0.5), "b", 0.5f),
        )
        val result = NMS.nonMaximumSuppression(detections, iouThreshold = 0.3f)
        assertEquals(1, result.size)
        assertEquals("1", result[0].id)
    }

    @Test
    fun testNMSKeepsDifferentLabels() {
        val detections = listOf(
            AIDetection("1", NormalizedRect(0.0, 0.0, 0.5, 0.5), "person", 0.9f),
            AIDetection("2", NormalizedRect(0.0, 0.0, 0.5, 0.5), "car", 0.85f),
        )
        val result = NMS.nonMaximumSuppression(detections)
        assertEquals(1, result.size)
    }

    @Test
    fun testIoU() {
        val a = NormalizedRect(0.0, 0.0, 1.0, 1.0)
        val b = NormalizedRect(0.5, 0.0, 1.0, 1.0)
        val iou = NMS.iou(a, b)
        assertTrue(iou > 0f)
        assertTrue(iou < 1f)
    }

    @Test
    fun testIoUZero() {
        val a = NormalizedRect(0.0, 0.0, 0.1, 0.1)
        val b = NormalizedRect(0.9, 0.9, 0.1, 0.1)
        assertEquals(0f, NMS.iou(a, b))
    }

    @Test
    fun testIoUIdentical() {
        val a = NormalizedRect(0.0, 0.0, 1.0, 1.0)
        assertEquals(1f, NMS.iou(a, a))
    }

    @Test
    fun testNMSFiltersLowConfidence() {
        val detections = listOf(
            AIDetection("1", NormalizedRect(0.0, 0.0, 0.1, 0.1), "a", 0.05f),
        )
        val result = NMS.nonMaximumSuppression(detections)
        assertTrue(result.isEmpty())
    }

    @Test
    fun testNMSWithManyDetections() {
        val detections = (1..100).map { i ->
            val x = (i % 10) * 0.1
            val y = (i / 10) * 0.1
            AIDetection("d$i", NormalizedRect(x, y, 0.6, 0.6), "obj", 0.7f)
        }
        val result = NMS.nonMaximumSuppression(detections, iouThreshold = 0.3f)
        assertTrue(result.size < 50)
        assertTrue(result.isNotEmpty())
    }
}
