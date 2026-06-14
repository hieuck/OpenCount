package com.opencount.shared

import com.opencount.shared.model.*
import com.opencount.shared.util.Counter
import kotlin.test.Test
import kotlin.test.*

class AdditionalModelTests {
    @Test
    fun testSessionTagPredefined() {
        assertEquals(10, SessionTag.predefinedTags.size)
        assertEquals("Wildlife", SessionTag.predefinedTags[0].first)
        assertEquals("Education", SessionTag.predefinedTags[9].first)
    }

    @Test
    fun testSessionTagDefaults() {
        val tag = SessionTag(id = "t1", name = "Test", createdAt = kotlinx.datetime.Clock.System.now())
        assertEquals("#3498DB", tag.colorHex)
        assertTrue(tag.emoji.isNotEmpty())
    }

    @Test
    fun testVideoFrameCount() {
        val frame = VideoFrameCount(id = "v1", timestampSeconds = 1.5, markerIds = listOf("m1", "m2"))
        assertEquals(1.5, frame.timestampSeconds)
        assertEquals(2, frame.markerIds.size)
    }

    @Test
    fun testTextAnnotation() {
        val point = NormalizedPoint(0.5, 0.5)
        val annotation = TextAnnotation(id = "a1", normalizedPosition = point, text = "Hello")
        assertEquals("Hello", annotation.text)
        assertEquals(16.0, annotation.fontSize)
    }

    @Test
    fun testMeasureLine() {
        val line = MeasureLine(
            id = "l1",
            startPoint = NormalizedPoint(0.0, 0.0),
            endPoint = NormalizedPoint(3.0, 4.0),
        )
        assertEquals(5.0, line.normalizedLength)
        assertEquals(NormalizedPoint(1.5, 2.0), line.midPoint)
    }

    @Test
    fun testArrowAnnotation() {
        val arrow = ArrowAnnotation(
            id = "ar1",
            tailPoint = NormalizedPoint(0.1, 0.1),
            headPoint = NormalizedPoint(0.9, 0.9),
            colorHex = "#00FF00",
        )
        assertEquals("#00FF00", arrow.colorHex)
    }

    @Test
    fun testAnnotationLayerTypes() {
        val types = AnnotationLayerType.entries
        assertTrue(types.contains(AnnotationLayerType.Markers))
        assertTrue(types.contains(AnnotationLayerType.Heatmap))
        assertEquals(7, types.size)
    }

    @Test
    fun testCountByAIDerived() {
        val typeA = ObjectType.create("A")
        val markers = listOf(
            CountMarker.create(0.1, 0.1, typeA.id, isAIDerived = false),
            CountMarker.create(0.2, 0.2, typeA.id, isAIDerived = true),
            CountMarker.create(0.3, 0.3, typeA.id, isAIDerived = false),
            CountMarker.create(0.4, 0.4, typeA.id, isAIDerived = true),
        )
        val session = CountSession.create("Test").copy(
            objectTypes = listOf(typeA),
            markers = markers,
        )
        val (manual, ai) = Counter.countByAIDerived(session)
        assertEquals(2, manual)
        assertEquals(2, ai)
    }

    @Test
    fun testFormulaEdgeCases() {
        // Division by zero
        val formula = CountFormula(id = "f1", name = "Div", expression = "a / 0")
        val result = FormulaEvaluator.evaluate(formula, mapOf("a" to 5))
        assertNull(result)

        // Invalid expression
        val invalid = CountFormula(id = "f2", name = "Bad", expression = "a + + b")
        val invalidResult = FormulaEvaluator.evaluate(invalid, mapOf("a" to 1, "b" to 2))
        assertNull(invalidResult)

        // Empty expression
        val empty = CountFormula(id = "f3", name = "Empty", expression = "")
        val emptyResult = FormulaEvaluator.evaluate(empty, mapOf("a" to 1))
        assertNull(emptyResult)
    }

    @Test
    fun testCounterEmptySession() {
        val session = CountSession.create("Empty")
        assertEquals(emptyMap(), Counter.tallyByType(session))
        assertEquals(emptyMap(), Counter.tallyByRegion(session))
        assertEquals(Pair(0, 0), Counter.countByAIDerived(session))
    }

    @Test
    fun testTallyHistoryEntry() {
        val entry = TallyHistoryEntry(
            timestamp = kotlinx.datetime.Clock.System.now(),
            objectTypeName = "Cars",
            delta = 5,
        )
        assertEquals("Cars", entry.objectTypeName)
        assertEquals(5, entry.delta)
    }

    @Test
    fun testNormalizedRectMidPoint() {
        val rect = NormalizedRect(x = 0.2, y = 0.3, width = 0.6, height = 0.4)
        assertEquals(0.5, rect.midX)
        assertEquals(0.5, rect.midY)
    }

    @Test
    fun testExportMultipleSessions() {
        val s1 = CountSession.create("Session 1").copy(
            objectTypes = listOf(ObjectType.create("A")),
            markers = listOf(CountMarker.create(0.1, 0.1, "a1")),
        )
        val s2 = CountSession.create("Session 2").copy(
            objectTypes = listOf(ObjectType.create("B")),
            markers = listOf(
                CountMarker.create(0.1, 0.1, "b1"),
                CountMarker.create(0.2, 0.2, "b1"),
            ),
        )
        val export = com.opencount.shared.service.ExportService()
        val csv = export.exportToCsv(listOf(s1, s2))
        assertTrue(csv.contains("Session 1"))
        assertTrue(csv.contains("Session 2"))
    }
}
