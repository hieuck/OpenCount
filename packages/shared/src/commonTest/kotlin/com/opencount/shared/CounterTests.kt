package com.opencount.shared

import com.opencount.shared.model.*
import com.opencount.shared.util.Counter
import kotlin.test.Test
import kotlin.test.assertEquals

class CounterTests {
    private val typeA = ObjectType.create("Type A")
    private val typeB = ObjectType.create("Type B")

    private val testSession: CountSession by lazy {
        CountSession.create("Test").copy(
            objectTypes = listOf(typeA, typeB),
            markers = listOf(
                CountMarker.create(0.1, 0.1, typeA.id),
                CountMarker.create(0.2, 0.2, typeA.id),
                CountMarker.create(0.3, 0.3, typeB.id),
            )
        )
    }

    @Test
    fun testTotalCount() {
        assertEquals(3, Counter.totalCount(testSession))
    }

    @Test
    fun testTallyByType() {
        val tally = Counter.tallyByType(testSession)
        assertEquals(2, tally["Type A"])
        assertEquals(1, tally["Type B"])
    }

    @Test
    fun testEmptySessionCount() {
        val empty = CountSession.create("Empty")
        assertEquals(0, Counter.totalCount(empty))
        assertEquals(emptyMap(), Counter.tallyByType(empty))
    }
}
