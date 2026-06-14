package com.opencount.shared

import com.opencount.shared.model.*
import com.opencount.shared.service.*
import com.opencount.shared.util.Counter
import com.opencount.shared.util.DuplicateDetector
import kotlin.test.Test
import kotlin.test.*

class EdgeCaseTests {
    @Test
    fun `region contains polygon with 2 points`() {
        val region = CountRegion(id = "r1", name = "Bad", shapeType = RegionShapeType.Polygon,
            normalizedPoints = listOf(NormalizedPoint(0.1, 0.1), NormalizedPoint(0.9, 0.9)))
        assertFalse(region.contains(NormalizedPoint(0.5, 0.5)))
    }

    @Test
    fun `region contains ellipse with 1 point`() {
        val region = CountRegion(id = "r1", name = "Bad", shapeType = RegionShapeType.Ellipse,
            normalizedPoints = listOf(NormalizedPoint(0.5, 0.5)))
        assertFalse(region.contains(NormalizedPoint(0.5, 0.5)))
    }

    @Test
    fun `duplicate detection empty list`() {
        assertTrue(DuplicateDetector.findDuplicates(emptyList()).isEmpty())
    }

    @Test
    fun `duplicate detection single marker`() {
        val marker = CountMarker.create(0.5, 0.5, "t1")
        assertTrue(DuplicateDetector.findDuplicates(listOf(marker)).isEmpty())
    }

    @Test
    fun `counter empty session`() {
        val session = CountSession.create("Empty")
        assertEquals(0, Counter.totalCount(session))
        assertTrue(Counter.tallyByType(session).isEmpty())
        assertTrue(Counter.tallyByRegion(session).isEmpty())
        assertEquals(Pair(0, 0), Counter.countByAIDerived(session))
    }

    @Test
    fun `export empty session`() {
        val session = CountSession.create("Empty")
        val export = ExportService()
        val csv = export.exportToCsv(session)
        assertTrue(csv.contains("Empty") || csv.isNotEmpty())
        val json = export.exportToJson(session)
        assertTrue(json.contains("Empty"))
    }

    @Test
    fun `nms with single detection`() {
        val d = AIDetection("1", NormalizedRect(0.0, 0.0, 0.5, 0.5), "obj", 0.9f)
        val result = NMS.nonMaximumSuppression(listOf(d))
        assertEquals(1, result.size)
    }

    @Test
    fun `nms with zero confidence`() {
        val d = AIDetection("1", NormalizedRect(0.0, 0.0, 0.5, 0.5), "obj", 0.0f)
        val result = NMS.nonMaximumSuppression(listOf(d))
        assertTrue(result.isEmpty())
    }

    @Test
    fun `session with special characters in name`() {
        val session = CountSession.create("Test: \"Quoted\", <Tag> & More!")
        assertEquals("Test: \"Quoted\", <Tag> & More!", session.name)
    }

    @Test
    fun `object type with empty name`() {
        val type = ObjectType.create("")
        assertEquals("", type.name)
    }

    @Test
    fun `counter respects object type boundaries`() {
        val a = ObjectType.create("A")
        val b = ObjectType.create("B")
        val markers = listOf(
            CountMarker.create(0.1, 0.1, a.id),
            CountMarker.create(0.2, 0.2, b.id),
        )
        val session = CountSession.create("Test").copy(
            objectTypes = listOf(a, b),
            markers = markers,
        )
        val tally = Counter.tallyByType(session)
        assertEquals(1, tally["A"])
        assertEquals(1, tally["B"])
    }

    @Test
    fun `duplicate detection across type boundaries`() {
        val a = CountMarker.create(0.5, 0.5, "typeA")
        val b = CountMarker.create(0.51, 0.51, "typeB")
        assertFalse(DuplicateDetector.isDuplicate(b, listOf(a), threshold = 0.05))
    }

    @Test
    fun `region boundary contains`() {
        val region = CountRegion(id = "r1", name = "R", shapeType = RegionShapeType.Rectangle,
            normalizedPoints = listOf(NormalizedPoint(0.0, 0.0), NormalizedPoint(0.5, 0.5)))
        assertFalse(region.contains(NormalizedPoint(0.5, 0.5)))
        assertFalse(region.contains(NormalizedPoint(-0.1, 0.1)))
    }

    @Test
    fun `storage round trip with all fields`() {
        val fake = FakePlatformStorage()
        val storage = StorageService(fake)
        val type = ObjectType.create("Test")
        val region = CountRegion(id = "r1", name = "Region", shapeType = RegionShapeType.Rectangle,
            normalizedPoints = listOf(NormalizedPoint(0.0, 0.0), NormalizedPoint(1.0, 1.0)))
        val marker = CountMarker.create(0.5, 0.5, type.id, regionId = "r1")
        val session = CountSession.create("Full").copy(
            objectTypes = listOf(type),
            regions = listOf(region),
            markers = listOf(marker),
            sessionDescription = "A full test session",
        )
        storage.save(session)
        val loaded = storage.load(session.id)
        assertNotNull(loaded)
        assertEquals(session.name, loaded.name)
        assertEquals(session.objectTypes.size, loaded.objectTypes.size)
        assertEquals(session.regions.size, loaded.regions.size)
        assertEquals(session.markers.size, loaded.markers.size)
        assertEquals(session.sessionDescription, loaded.sessionDescription)
    }
}
