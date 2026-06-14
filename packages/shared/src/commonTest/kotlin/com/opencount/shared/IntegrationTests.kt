package com.opencount.shared

import com.opencount.shared.model.*
import com.opencount.shared.service.ExportService
import com.opencount.shared.util.Counter
import com.opencount.shared.util.DuplicateDetector
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNotNull
import kotlin.test.assertTrue

/**
 * Integration tests verifying the core workflow end-to-end:
 * Create session → Add object types → Add markers → Count → Export
 */
class IntegrationTests {
    @Test
    fun `full counting workflow`() {
        // 1. Create session
        val session = CountSession.create("Warehouse Inventory")
        assertEquals("Warehouse Inventory", session.name)

        // 2. Add object types
        val boxes = ObjectType.create("Boxes", colorHex = "#FF5733")
        val pallets = ObjectType.create("Pallets", colorHex = "#33FF57")
        val updatedSession = session.copy(
            objectTypes = listOf(boxes, pallets)
        )
        assertEquals(2, updatedSession.objectTypes.size)

        // 3. Add markers
        val markers = listOf(
            CountMarker.create(0.1, 0.2, boxes.id),
            CountMarker.create(0.3, 0.4, boxes.id),
            CountMarker.create(0.5, 0.6, boxes.id),
            CountMarker.create(0.7, 0.8, pallets.id),
            CountMarker.create(0.9, 0.1, pallets.id),
        )
        val finalSession = updatedSession.copy(markers = markers)
        assertEquals(5, Counter.totalCount(finalSession))

        // 4. Verify tally
        val tally = Counter.tallyByType(finalSession)
        assertEquals(3, tally["Boxes"])
        assertEquals(2, tally["Pallets"])

        // 5. Export to JSON
        val export = ExportService()
        val json = export.exportToJson(finalSession)
        assertTrue(json.contains("Boxes"))
        assertTrue(json.contains("Pallets"))

        // 6. Export to CSV
        val csv = export.exportToCsv(finalSession)
        assertTrue(csv.contains("Boxes,3"))
        assertTrue(csv.contains("Pallets,2"))
    }

    @Test
    fun `duplicate detection integration`() {
        val typeA = ObjectType.create("Type A")
        val markers = listOf(
            CountMarker.create(0.5, 0.5, typeA.id),
            CountMarker.create(0.51, 0.51, typeA.id),
            CountMarker.create(0.52, 0.52, typeA.id),
            CountMarker.create(0.9, 0.9, typeA.id),
        )

        val duplicates = DuplicateDetector.findDuplicates(markers, threshold = 0.05)
        assertTrue(duplicates.isNotEmpty())

        val farAway = CountMarker.create(0.1, 0.1, typeA.id)
        assertTrue(!DuplicateDetector.isDuplicate(farAway, markers, threshold = 0.05))
    }

    @Test
    fun `formula evaluation integration`() {
        val typeA = ObjectType.create("Cars")
        val typeB = ObjectType.create("Trucks")
        val formula = CountFormula(
            id = "f1", name = "Total Vehicles",
            expression = "Cars + Trucks",
        )

        val session = CountSession.create("Traffic Count").copy(
            objectTypes = listOf(typeA, typeB),
            formulas = listOf(formula),
            markers = listOf(
                CountMarker.create(0.1, 0.1, typeA.id),
                CountMarker.create(0.2, 0.2, typeA.id),
                CountMarker.create(0.3, 0.3, typeA.id),
                CountMarker.create(0.4, 0.4, typeB.id),
            ),
        )

        val tally = Counter.tallyByType(session)
        val result = FormulaEvaluator.evaluate(formula, tally)
        assertNotNull(result)
        assertEquals(4.0, result)
    }

    @Test
    fun `region counting integration`() {
        val typeA = ObjectType.create("Items")
        val region = CountRegion(
            id = "r1", name = "Zone A",
            shapeType = RegionShapeType.Rectangle,
            normalizedPoints = listOf(
                NormalizedPoint(0.0, 0.0),
                NormalizedPoint(0.5, 0.5),
            ),
        )

        val markers = listOf(
            CountMarker.create(0.1, 0.1, typeA.id, regionId = "r1"),
            CountMarker.create(0.4, 0.4, typeA.id, regionId = "r1"),
            CountMarker.create(0.8, 0.8, typeA.id), // outside region
        )

        val session = CountSession.create("Zoned Count").copy(
            objectTypes = listOf(typeA),
            regions = listOf(region),
            markers = markers,
        )

        val regionTally = Counter.tallyByRegion(session)
        assertTrue(regionTally.containsKey("Zone A"))
        assertEquals(2, regionTally["Zone A"]?.get("Items"))
    }

    @Test
    fun `AI detection integration`() {
        val rect = NormalizedRect(0.1, 0.1, 0.3, 0.3)
        val detection = AIDetection(
            id = "d1",
            normalizedBoundingBox = rect,
            label = "person",
            confidenceScore = 0.95f,
        )

        assertEquals(0.25, detection.normalizedCentroid.x)
        assertEquals(0.25, detection.normalizedCentroid.y)
    }
}
