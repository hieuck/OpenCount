package com.opencount.shared

import com.opencount.shared.model.*
import com.opencount.shared.service.*
import com.opencount.shared.util.Counter
import com.opencount.shared.util.DuplicateDetector
import kotlin.test.Test
import kotlin.test.*

class AdditionalEdgeCaseTests {
    @Test fun serializeSessionAllNullFields() {
        val s = CountSession.create("Minimal")
        val json = kotlinx.serialization.json.Json { ignoreUnknownKeys = true }
        val encoded = json.encodeToString(CountSession.serializer(), s)
        val decoded = json.decodeFromString(CountSession.serializer(), encoded)
        assertEquals(s.name, decoded.name)
    }

    @Test fun countMarkersSameCoordinates() {
        val type = ObjectType.create("Same")
        val markers = (1..10).map { CountMarker.create(0.5, 0.5, type.id) }
        val session = CountSession.create("Duplicates").copy(
            objectTypes = listOf(type), markers = markers,
        )
        assertEquals(10, Counter.totalCount(session))
    }

    @Test fun regionNoPoints() {
        val r = CountRegion(id = "r1", name = "Empty", shapeType = RegionShapeType.Rectangle)
        assertFalse(r.contains(NormalizedPoint(0.5, 0.5)))
    }

    @Test fun exportServiceNullDescription() {
        val s = CountSession.create("Null Desc").copy(sessionDescription = null)
        val export = ExportService()
        val json = export.exportToJson(s)
        assertTrue(json.contains("Null Desc"))
    }

    @Test fun nmsIdenticalBoxes() {
        val d1 = AIDetection("1", NormalizedRect(0.0, 0.0, 1.0, 1.0), "a", 0.9f)
        val d2 = AIDetection("2", NormalizedRect(0.0, 0.0, 1.0, 1.0), "b", 0.8f)
        val result = NMS.nonMaximumSuppression(listOf(d1, d2), iouThreshold = 0.5f)
        assertEquals(1, result.size)
        assertEquals("1", result[0].id)
    }

    @Test fun iouEdgeCases() {
        assertEquals(0f, NMS.iou(NormalizedRect(0.0, 0.0, 0.0, 0.0), NormalizedRect(0.5, 0.5, 0.1, 0.1)))
        assertEquals(0f, NMS.iou(NormalizedRect(0.5, 0.5, 0.1, 0.1), NormalizedRect(0.0, 0.0, 0.0, 0.0)))
    }

    @Test fun smartSuggestionsEmptyNames() {
        val service = SmartSuggestionsService()
        val sessions = listOf(CountSession.create("S").copy(
            objectTypes = listOf(ObjectType.create(""), ObjectType.create("Named"))
        ))
        val suggestions = service.suggestions(sessions)
        assertTrue(suggestions.any { it.name == "Named" })
    }

    @Test fun velocityTrackerRapid() {
        val tracker = CountingVelocityTracker(windowSeconds = 60)
        repeat(100) { tracker.recordMarker() }
        assertTrue(tracker.markersPerMinute() > 0)
    }

    @Test fun templateLibraryEmptySession() {
        val lib = TemplateLibraryService()
        val session = CountSession.create("Empty")
        lib.saveAsTemplate("Empty Template", "", session)
        assertEquals(1, lib.count)
        val loaded = lib.loadAll()
        assertEquals(0, loaded[0].objectTypeData.size)
    }

    @Test fun storageServiceReSave() {
        val fake = FakePlatformStorage()
        val storage = StorageService(fake)
        val s = CountSession.create("Original")
        storage.save(s)
        val s2 = s.copy(name = "Updated")
        storage.save(s2)
        val loaded = storage.load(s.id)
        assertNotNull(loaded)
        assertEquals("Updated", loaded.name)
    }

    @Test fun countByTypeUnknownIDs() {
        val session = CountSession.create("Test").copy(
            markers = listOf(CountMarker.create(0.5, 0.5, "non-existent-id")),
        )
        val tally = Counter.tallyByType(session)
        assertEquals(1, tally["Unknown"])
    }

    @Test fun detectClustersSamePoint() {
        val service = SmartCountService()
        val markers = (1..20).map { CountMarker.create(0.5, 0.5, "t1") }
        val clusters = service.detectClusters(markers, clusterRadius = 0.01)
        assertEquals(1, clusters.size)
        assertEquals(20, clusters[0].size)
    }

    @Test fun formulaUnicodeNames() {
        val formula = CountFormula(id = "f1", name = "U", expression = "Carrés + Trüks")
        val result = FormulaEvaluator.evaluate(formula, mapOf("Carrés" to 5, "Trüks" to 3))
        assertEquals(8.0, result)
    }

    @Test fun countByRegionUnassigned() {
        val type = ObjectType.create("Item")
        val region = CountRegion(id = "r1", name = "Zone", shapeType = RegionShapeType.Rectangle,
            normalizedPoints = listOf(NormalizedPoint(0.0, 0.0), NormalizedPoint(0.5, 0.5)))
        val markers = listOf(
            CountMarker.create(0.1, 0.1, type.id, regionId = "r1"),
            CountMarker.create(0.9, 0.9, type.id),
        )
        val session = CountSession.create("Mixed").copy(
            objectTypes = listOf(type), regions = listOf(region), markers = markers,
        )
        val byRegion = Counter.tallyByRegion(session)
        assertEquals(1, byRegion["Zone"]?.get("Item"))
        assertTrue(byRegion.containsKey("None") || byRegion.size == 2)
    }

    @Test fun panoramaTilerNoOverlap() {
        val tiles = PanoramaTiler.tile(100.0, 100.0)
        assertEquals(1, tiles.size)
        assertEquals(0.0, tiles[0].offsetX)
        assertEquals(0.0, tiles[0].offsetY)
    }
}
