package com.opencount.shared

import com.opencount.shared.model.CountMarker
import com.opencount.shared.util.DuplicateDetector
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertTrue

class DuplicateDetectorTests {
    @Test
    fun testNoDuplicates() {
        val markers = listOf(
            CountMarker.create(0.1, 0.1, "type1"),
            CountMarker.create(0.5, 0.5, "type1"),
            CountMarker.create(0.9, 0.9, "type1"),
        )
        val duplicates = DuplicateDetector.findDuplicates(markers)
        assertTrue(duplicates.isEmpty())
    }

    @Test
    fun testFindsDuplicates() {
        val markers = listOf(
            CountMarker.create(0.1, 0.1, "type1"),
            CountMarker.create(0.11, 0.11, "type1"),
        )
        val duplicates = DuplicateDetector.findDuplicates(markers)
        assertEquals(1, duplicates.size)
    }

    @Test
    fun testDifferentTypesNotDuplicates() {
        val markers = listOf(
            CountMarker.create(0.1, 0.1, "type1"),
            CountMarker.create(0.11, 0.11, "type2"),
        )
        val duplicates = DuplicateDetector.findDuplicates(markers)
        assertTrue(duplicates.isEmpty())
    }

    @Test
    fun testIsDuplicate() {
        val existing = listOf(CountMarker.create(0.5, 0.5, "type1"))
        val close = CountMarker.create(0.51, 0.51, "type1")
        assertTrue(DuplicateDetector.isDuplicate(close, existing))
    }
}
