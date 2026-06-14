package com.opencount.shared

import com.opencount.shared.model.*
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNotNull
import kotlin.test.assertTrue

class ModelTests {
    @Test
    fun testCreateCountSession() {
        val session = CountSession.create("Test Session")
        assertEquals("Test Session", session.name)
        assertNotNull(session.id)
    }

    @Test
    fun testCreateObjectType() {
        val type = ObjectType.create("Cars", colorHex = "#FF0000", iconName = "car.fill")
        assertEquals("Cars", type.name)
        assertEquals("#FF0000", type.colorHex)
    }

    @Test
    fun testCreateCountMarker() {
        val marker = CountMarker.create(
            normalizedX = 0.5, normalizedY = 0.5,
            objectTypeId = "type-1"
        )
        assertEquals(0.5, marker.normalizedX)
        assertEquals(0.5, marker.normalizedY)
    }

    @Test
    fun testRegionRectangleContains() {
        val region = CountRegion(
            id = "r1", name = "Rect",
            shapeType = RegionShapeType.Rectangle,
            normalizedPoints = listOf(
                NormalizedPoint(0.1, 0.1),
                NormalizedPoint(0.9, 0.9),
            )
        )
        assertTrue(region.contains(NormalizedPoint(0.5, 0.5)))
    }

    @Test
    fun testFormulaEvaluation() {
        val formula = CountFormula(id = "f1", name = "Total", expression = "cars + trucks")
        val tally = mapOf("cars" to 5, "trucks" to 3)
        val result = FormulaEvaluator.evaluate(formula, tally)
        assertEquals(8.0, result)
    }

    @Test
    fun testFormulaEvaluationComplex() {
        val formula = CountFormula(id = "f2", name = "Complex", expression = "(a + b) * 2")
        val tally = mapOf("a" to 3, "b" to 4)
        val result = FormulaEvaluator.evaluate(formula, tally)
        assertEquals(14.0, result)
    }

    @Test
    fun testSessionTagPredefined() {
        assertEquals(10, SessionTag.predefinedTags.size)
    }

    @Test
    fun testAIDetectionCentroid() {
        val rect = NormalizedRect(x = 0.2, y = 0.3, width = 0.4, height = 0.2)
        val detection = AIDetection(
            id = "d1",
            normalizedBoundingBox = rect,
            label = "person",
            confidenceScore = 0.95f,
        )
        assertEquals(0.4, detection.normalizedCentroid.x)
        assertEquals(0.4, detection.normalizedCentroid.y)
    }
}
