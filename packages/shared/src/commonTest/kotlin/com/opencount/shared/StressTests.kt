package com.opencount.shared

import com.opencount.shared.model.*
import com.opencount.shared.service.*
import com.opencount.shared.util.Counter
import com.opencount.shared.util.DuplicateDetector
import kotlin.test.Test
import kotlin.test.*

class StressTests {
    @Test
    fun largeSessionWith10000Markers() {
        val type = ObjectType.create("Items")
        val markers = (1..10000).map { i ->
            CountMarker.create(i.toDouble() / 10000, (i % 100).toDouble() / 100, type.id)
        }
        val session = CountSession.create("Large Test").copy(
            objectTypes = listOf(type),
            markers = markers,
        )
        assertEquals(10000, Counter.totalCount(session))
        val tally = Counter.tallyByType(session)
        assertEquals(10000, tally["Items"])
    }

    @Test
    fun largeSessionWithManyTypes() {
        val types = (1..100).map { ObjectType.create("Type $it") }
        val markers = types.flatMap { type ->
            (1..10).map { CountMarker.create(0.5, 0.5, type.id) }
        }
        val session = CountSession.create("Many Types").copy(
            objectTypes = types,
            markers = markers,
        )
        assertEquals(1000, Counter.totalCount(session))
        val tally = Counter.tallyByType(session)
        assertEquals(100, tally.size)
        assertTrue(tally.values.all { it == 10 })
    }

    @Test
    fun duplicateDetectionOn5000Markers() {
        val markers = (1..5000).map { i ->
            CountMarker.create(i.toDouble() / 5000, i.toDouble() / 5000, "t1")
        }
        val dups = DuplicateDetector.findDuplicates(markers, threshold = 0.001)
        assertTrue(dups.isNotEmpty())
    }

    @Test
    fun stressFormulaEvaluation() {
        val formula = CountFormula(id = "f1", name = "Complex", expression = "a + b * c - d / e")
        val tally = mapOf("a" to 100, "b" to 200, "c" to 300, "d" to 400, "e" to 500)
        val results = (1..1000).map { FormulaEvaluator.evaluate(formula, tally) }
        assertTrue(results.all { it != null })
        assertEquals(1, results.toSet().size)
    }

    @Test
    fun regionTallyWith1000Markers() {
        val type = ObjectType.create("Items")
        val region = CountRegion(
            id = "r1", name = "Zone", shapeType = RegionShapeType.Rectangle,
            normalizedPoints = listOf(NormalizedPoint(0.0, 0.0), NormalizedPoint(1.0, 1.0)),
        )
        val markers = (1..1000).map { i ->
            CountMarker.create(i.toDouble() / 1000, 0.5, type.id, regionId = "r1")
        }
        val session = CountSession.create("Stress").copy(
            objectTypes = listOf(type),
            regions = listOf(region),
            markers = markers,
        )
        val byRegion = Counter.tallyByRegion(session)
        assertEquals(1000, byRegion["Zone"]?.get("Items"))
    }

    @Test
    fun exportLargeSession() {
        val cars = ObjectType.create("Cars")
        val trucks = ObjectType.create("Trucks")
        val markers = (1..500).map { i ->
            val t = if (i % 2 == 0) cars else trucks
            CountMarker.create(i.toDouble() / 500, 0.5, t.id)
        }
        val session = CountSession.create("Export Test").copy(
            objectTypes = listOf(cars, trucks),
            markers = markers,
        )
        val export = ExportService()
        val json = export.exportToJson(session)
        assertTrue(json.length > 1000)
        val csv = export.exportToCsv(session)
        assertTrue(csv.lines().size >= 3)
    }

    @Test
    fun storageFakeWith1000Sessions() {
        val fake = FakePlatformStorage()
        val storage = StorageService(fake)
        (1..1000).forEach { i ->
            storage.save(CountSession.create("Session $i"))
        }
        assertEquals(1000, storage.loadAll().size)
        (1..1000).forEach { i ->
            if (i % 2 == 0) storage.delete(storage.loadAll().first().id)
        }
        assertEquals(500, storage.loadAll().size)
    }

    @Test
    fun largeMarkerWithAiDerivedMix() {
        val type = ObjectType.create("Items")
        val markers = (1..2000).map { i ->
            CountMarker.create(0.5, 0.5, type.id, isAIDerived = i % 3 == 0)
        }
        val session = CountSession.create("AI Mix").copy(
            objectTypes = listOf(type),
            markers = markers,
        )
        val (manual, ai) = Counter.countByAIDerived(session)
        assertEquals(2000, manual + ai)
        assertTrue(ai > 0)
    }
}
