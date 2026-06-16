package com.opencount.shared

import com.opencount.shared.model.*
import com.opencount.shared.service.*
import com.opencount.shared.util.Counter
import com.opencount.shared.util.DuplicateDetector
import kotlin.test.Test
import kotlin.test.*

class MoreEdgeCaseTests {
    @Test
    fun counterEmptyObjectTypes() {
        val session = CountSession.create("NoTypes").copy(markers = listOf(CountMarker.create(0.5, 0.5, "t1")))
        val tally = Counter.tallyByType(session)
        assertEquals(1, tally["Unknown"])
    }

    @Test
    fun regionPolygonWith3Points() {
        val r = CountRegion(id = "r1", name = "Tri", shapeType = RegionShapeType.Polygon,
            normalizedPoints = listOf(NormalizedPoint(0.0, 0.0), NormalizedPoint(1.0, 0.0), NormalizedPoint(0.0, 1.0)))
        assertTrue(r.contains(NormalizedPoint(0.1, 0.1)))
        assertFalse(r.contains(NormalizedPoint(0.6, 0.6)))
    }

    @Test
    fun tallyHistoryEntrySerialization() {
        val entry = TallyHistoryEntry(timestamp = kotlinx.datetime.Clock.System.now(), objectTypeName = "Cars", delta = 5)
        val json = kotlinx.serialization.json.Json { prettyPrint = true }
        val encoded = json.encodeToString(TallyHistoryEntry.serializer(), entry)
        val decoded = json.decodeFromString(TallyHistoryEntry.serializer(), encoded)
        assertEquals(entry.delta, decoded.delta)
        assertEquals(entry.objectTypeName, decoded.objectTypeName)
    }

    @Test
    fun cocoExportWithMultipleImages() {
        val type = ObjectType.create("Car")
        val session = CountSession.create("COCO Multi").copy(
            objectTypes = listOf(type),
            images = listOf(
                SessionImage.create("img1.jpg"),
                SessionImage.create("img2.jpg"),
            ),
            markers = listOf(CountMarker.create(0.5, 0.5, type.id)),
        )
        val export = ExportService()
        val coco = export.exportToCoco(session)
        assertTrue(coco.contains("img1"))
    }

    @Test
    fun sessionMarkerRegionConsistency() {
        val region = CountRegion(id = "r1", name = "R1", shapeType = RegionShapeType.Rectangle,
            normalizedPoints = listOf(NormalizedPoint(0.0, 0.0), NormalizedPoint(0.5, 0.5)))
        val type = ObjectType.create("T")
        val inside = CountMarker.create(0.25, 0.25, type.id, regionId = "r1")
        val outside = CountMarker.create(0.75, 0.75, type.id)
        assertTrue(region.contains(NormalizedPoint(inside.normalizedX, inside.normalizedY)))
        assertFalse(region.contains(NormalizedPoint(outside.normalizedX, outside.normalizedY)))
    }

    @Test
    fun duplicateDetectionDifferentThreshold() {
        val a = CountMarker.create(0.5, 0.5, "t1")
        val b = CountMarker.create(0.55, 0.55, "t1")
        assertTrue(DuplicateDetector.findDuplicates(listOf(a, b), threshold = 0.1).isNotEmpty())
        assertTrue(DuplicateDetector.findDuplicates(listOf(a, b), threshold = 0.01).isEmpty())
    }

    @Test
    fun sessionCountAfterFiltering() {
        val type = ObjectType.create("X")
        val markers = (1..100).map { CountMarker.create(0.5, 0.5, type.id) }
        val filtered = markers.filterIndexed { i, _ -> i % 2 == 0 }
        val session = CountSession.create("Filtered").copy(
            objectTypes = listOf(type), markers = filtered,
        )
        assertEquals(50, Counter.totalCount(session))
    }

    @Test
    fun polygonContainsPointOnEdge() {
        val r = CountRegion(id = "r1", name = "R", shapeType = RegionShapeType.Polygon,
            normalizedPoints = listOf(NormalizedPoint(0.0, 0.0), NormalizedPoint(1.0, 0.0),
                NormalizedPoint(1.0, 1.0), NormalizedPoint(0.0, 1.0)))
        assertTrue(r.contains(NormalizedPoint(0.0, 0.5)), "Point on left edge should be inside")
    }

    @Test
    fun nmsOrderPreservation() {
        val detections = listOf(
            AIDetection("a", NormalizedRect(0.0, 0.0, 0.1, 0.1), "x", 0.9f),
            AIDetection("b", NormalizedRect(0.0, 0.0, 0.1, 0.1), "x", 0.8f),
        )
        val result = NMS.nonMaximumSuppression(detections)
        assertEquals("a", result[0].id)
    }

    @Test
    fun sampleSessionHasCorrectMarkerCount() {
        val s = SampleSessionSeeder.createSampleSession()
        assertEquals(6, Counter.totalCount(s))
        assertEquals(3, Counter.tallyByType(s).size)
    }

    @Test
    fun sessionWithDescriptionRoundtrip() {
        val s = CountSession.create("Test").copy(sessionDescription = "Hello World")
        val export = ExportService()
        val json = export.exportToJson(s)
        val fake = FakePlatformStorage()
        val storage = StorageService(fake)
        val restored = storage.fromJson(json)
        assertEquals("Hello World", restored.sessionDescription)
    }

    @Test
    fun autoNamingAfterManySessions() {
        val fake = FakePlatformStorage()
        val storage = StorageService(fake)
        (1..25).forEach { storage.save(CountSession.create("S$it")) }
        assertEquals(25, storage.loadAll().size)
    }

    @Test
    fun sessionImageWithoutExtension() {
        val img = SessionImage.create("test")
        assertNotNull(img.id)
        assertEquals("test", img.filename)
    }
}
