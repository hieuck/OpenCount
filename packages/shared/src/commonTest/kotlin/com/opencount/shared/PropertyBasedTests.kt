package com.opencount.shared

import com.opencount.shared.model.*
import com.opencount.shared.util.Counter
import com.opencount.shared.util.DuplicateDetector
import kotlin.test.Test
import kotlin.test.*

class PropertyBasedTests {
    @Test
    fun tallyTotalEqualsMarkerCount() {
        val type = ObjectType.create("Items")
        val markers = (1..50).map { CountMarker.create(it * 0.01, it * 0.01, type.id) }
        val session = CountSession.create("Test").copy(
            objectTypes = listOf(type),
            markers = markers,
        )
        val tally = Counter.tallyByType(session)
        assertEquals(50, tally.values.sum())
        assertEquals(50, Counter.totalCount(session))
    }

    @Test
    fun markerCountSumsToManualPlusAi() {
        val type = ObjectType.create("Items")
        val markers = (1..30).map {
            CountMarker.create(it * 0.01, it * 0.01, type.id, isAIDerived = it % 2 == 0)
        }
        val session = CountSession.create("Test").copy(
            objectTypes = listOf(type),
            markers = markers,
        )
        val (manual, ai) = Counter.countByAIDerived(session)
        assertEquals(30, manual + ai)
    }

    @Test
    fun addingMarkerToEmptySession() {
        val type = ObjectType.create("Items")
        val marker = CountMarker.create(0.5, 0.5, type.id)
        val session = CountSession.create("Test").copy(
            objectTypes = listOf(type),
            markers = listOf(marker),
        )
        assertEquals(1, Counter.totalCount(session))
        assertEquals(1, Counter.tallyByType(session).values.sum())
    }

    @Test
    fun duplicateThresholdProperty() {
        val markers = (1..10).map { CountMarker.create(it * 0.1, it * 0.1, "t1") }
        // Within threshold 0.15, consecutive markers may be duplicates
        val withClose = markers + CountMarker.create(0.101, 0.101, "t1")
        val dups = DuplicateDetector.findDuplicates(withClose, threshold = 0.15)
        assertTrue(dups.isNotEmpty())
    }

    @Test
    fun duplicateDetectionSymmetric() {
        val a = CountMarker.create(0.5, 0.5, "t1")
        val b = CountMarker.create(0.51, 0.51, "t1")
        val existing = listOf(a)
        assertTrue(DuplicateDetector.isDuplicate(b, existing, threshold = 0.05))
    }

    @Test
    fun countByRegionDistributesCorrectly() {
        val type = ObjectType.create("Items")
        val regionA = CountRegion(id = "ra", name = "A", shapeType = RegionShapeType.Rectangle,
            normalizedPoints = listOf(NormalizedPoint(0.0, 0.0), NormalizedPoint(0.3, 0.3)))
        val regionB = CountRegion(id = "rb", name = "B", shapeType = RegionShapeType.Rectangle,
            normalizedPoints = listOf(NormalizedPoint(0.7, 0.7), NormalizedPoint(1.0, 1.0)))
        val markers = listOf(
            CountMarker.create(0.1, 0.1, type.id, regionId = "ra"),
            CountMarker.create(0.2, 0.2, type.id, regionId = "ra"),
            CountMarker.create(0.8, 0.8, type.id, regionId = "rb"),
            CountMarker.create(0.5, 0.5, type.id),
        )
        val session = CountSession.create("Test").copy(
            objectTypes = listOf(type),
            regions = listOf(regionA, regionB),
            markers = markers,
        )
        val byRegion = Counter.tallyByRegion(session)
        assertEquals(2, byRegion["A"]?.get("Items"))
        assertEquals(1, byRegion["B"]?.get("Items"))
    }

    @Test
    fun formulaCommutativeProperty() {
        val ab = mapOf("a" to 5, "b" to 3)
        val ba = mapOf("b" to 3, "a" to 5)
        val formula = CountFormula(id = "f", name = "Sum", expression = "a + b")
        assertEquals(
            FormulaEvaluator.evaluate(formula, ab),
            FormulaEvaluator.evaluate(formula, ba),
        )
    }

    @Test
    fun formulaIdentity() {
        val cases = listOf(
            CountFormula(id = "f1", name = "Zero", expression = "0") to 0.0,
            CountFormula(id = "f2", name = "One", expression = "1") to 1.0,
            CountFormula(id = "f3", name = "Neg", expression = "-5") to -5.0,
            CountFormula(id = "f4", name = "Dec", expression = "3.14") to 3.14,
        )
        for ((formula, expected) in cases) {
            assertEquals(expected, FormulaEvaluator.evaluate(formula, emptyMap()))
        }
    }

    @Test
    fun tallyAfterDeleteProperty() {
        val type = ObjectType.create("Items")
        val markers = (1..20).map { CountMarker.create(it * 0.01, it * 0.01, type.id) }
        val kept = markers.drop(5)
        val session = CountSession.create("Test").copy(
            objectTypes = listOf(type),
            markers = kept,
        )
        assertEquals(15, Counter.totalCount(session))
        assertEquals(15, Counter.tallyByType(session).values.sum())
    }
}
