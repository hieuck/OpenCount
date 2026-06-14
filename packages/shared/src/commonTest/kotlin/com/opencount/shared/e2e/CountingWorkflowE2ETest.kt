package com.opencount.shared.e2e

import com.opencount.shared.model.*
import com.opencount.shared.service.ExportService
import com.opencount.shared.util.Counter
import com.opencount.shared.util.DuplicateDetector
import kotlinx.serialization.json.Json
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNotNull
import kotlin.test.assertTrue

/**
 * End-to-end test simulating a real user workflow:
 * 1. Create session → 2. Add categories → 3. Count manually
 * 4. AI-assisted counting → 5. Region-based counting
 * 6. Export → 7. JSON round-trip → 8. Verify data integrity
 */
class CountingWorkflowE2ETest {
    private val json = Json {
        ignoreUnknownKeys = true
        isLenient = true
        prettyPrint = true
    }

    @Test
    fun `user_counts_objects_and_exports_end_to_end`() {
        // Step 1: User creates a new counting session
        val session = CountSession.create("Warehouse Day 1")
        assertEquals("Warehouse Day 1", session.name)
        assertNotNull(session.id)
        assertEquals(0, Counter.totalCount(session))

        // Step 2: User adds object categories
        val boxes = ObjectType.create("Cardboard Boxes", colorHex = "#FF6B35", targetCount = 50)
        val pallets = ObjectType.create("Pallets", colorHex = "#004E89", targetCount = 10)
        val barrels = ObjectType.create("Barrels", colorHex = "#1A936F")
        val sessionWithTypes = session.copy(objectTypes = listOf(boxes, pallets, barrels))
        assertEquals(3, sessionWithTypes.objectTypes.size)

        // Step 3: User manually counts objects
        val manualMarkers = listOf(
            CountMarker.create(0.1, 0.2, boxes.id),
            CountMarker.create(0.15, 0.25, boxes.id),
            CountMarker.create(0.2, 0.3, boxes.id),
            CountMarker.create(0.3, 0.1, pallets.id),
            CountMarker.create(0.35, 0.15, pallets.id),
            CountMarker.create(0.5, 0.5, barrels.id),
        )
        val sessionWithMarkers = sessionWithTypes.copy(markers = manualMarkers)
        assertEquals(6, Counter.totalCount(sessionWithMarkers))

        // Step 4: AI adds detections
        val aiMarkers = listOf(
            CountMarker.create(0.4, 0.4, boxes.id, isAIDerived = true),
            CountMarker.create(0.45, 0.45, boxes.id, isAIDerived = true),
            CountMarker.create(0.6, 0.6, pallets.id, isAIDerived = true),
        )
        val sessionWithAI = sessionWithMarkers.copy(markers = sessionWithMarkers.markers + aiMarkers)
        assertEquals(9, Counter.totalCount(sessionWithAI))

        // Step 5: User adds regions
        val zoneA = CountRegion(
            id = "zone-a", name = "Zone A",
            shapeType = RegionShapeType.Rectangle,
            normalizedPoints = listOf(NormalizedPoint(0.0, 0.0), NormalizedPoint(0.5, 0.5)),
        )
        val zoneB = CountRegion(
            id = "zone-b", name = "Zone B",
            shapeType = RegionShapeType.Rectangle,
            normalizedPoints = listOf(NormalizedPoint(0.5, 0.0), NormalizedPoint(1.0, 0.5)),
        )
        val sessionWithRegions = sessionWithAI.copy(regions = listOf(zoneA, zoneB))
        val zonedMarkers = sessionWithRegions.markers.mapIndexed { index, marker ->
            if (index < 3) marker.copy(regionId = "zone-a")
            else if (index < 6) marker.copy(regionId = "zone-b")
            else marker
        }
        val finalSession = sessionWithRegions.copy(markers = zonedMarkers)

        // Step 6: Verify counts
        val tallyByType = Counter.tallyByType(finalSession)
        assertEquals(5, tallyByType["Cardboard Boxes"])
        assertEquals(3, tallyByType["Pallets"])
        assertEquals(1, tallyByType["Barrels"])

        val tallyByRegion = Counter.tallyByRegion(finalSession)
        assertTrue(tallyByRegion.containsKey("Zone A"))
        assertTrue(tallyByRegion.containsKey("Zone B"))

        // Step 7: Export
        val exportService = ExportService()
        val jsonExport = exportService.exportToJson(finalSession)
        assertTrue(jsonExport.contains("Warehouse Day 1"))
        assertTrue(jsonExport.contains("Cardboard Boxes"))
        assertTrue(jsonExport.contains("Zone A"))

        val csvExport = exportService.exportToCsv(finalSession)
        assertTrue(csvExport.contains("Cardboard Boxes"))
        assertTrue(csvExport.contains("5"))

        // Step 8: Formula evaluation
        val totalFormula = CountFormula(
            id = "f1", name = "Total",
            expression = "Cardboard Boxes + Pallets + Barrels",
        )
        val formulaResult = FormulaEvaluator.evaluate(
            totalFormula,
            mapOf("Cardboard Boxes" to 5, "Pallets" to 3, "Barrels" to 1),
        )
        assertNotNull(formulaResult)
        assertEquals(9.0, formulaResult)

        // Step 9: Duplicate detection - add close markers to test
        val closeMarkers = listOf(
            CountMarker.create(0.101, 0.201, boxes.id),
            CountMarker.create(0.102, 0.202, boxes.id),
        )
        val allBoxMarkers = finalSession.markers.filter { it.objectTypeId == boxes.id } + closeMarkers
        val duplicates = DuplicateDetector.findDuplicates(allBoxMarkers, threshold = 0.05)
        assertTrue(duplicates.isNotEmpty(), "Expected duplicate markers within threshold")

        // Step 10: JSON serialization round-trip
        val serialized = json.encodeToString(CountSession.serializer(), finalSession)
        val restored = json.decodeFromString(CountSession.serializer(), serialized)
        assertEquals(finalSession.name, restored.name)
        assertEquals(finalSession.markers.size, restored.markers.size)
        assertEquals(finalSession.objectTypes.size, restored.objectTypes.size)
    }

    @Test
    fun `user_toggles_between_counting_modes`() {
        val type = ObjectType.create("Items")
        val tallyModeMarkers = (1..10).map {
            CountMarker.create(0.1 * it, 0.1 * it, type.id)
        }

        var session = CountSession.create("Mixed Counting").copy(
            objectTypes = listOf(type),
            markers = tallyModeMarkers,
        )
        assertEquals(10, Counter.totalCount(session))

        val aiMarkers = (1..5).map {
            CountMarker.create(0.05 * it, 0.05 * it, type.id, isAIDerived = true)
        }
        session = session.copy(markers = session.markers + aiMarkers)
        assertEquals(15, Counter.totalCount(session))

        val (manualCount, aiCount) = Counter.countByAIDerived(session)
        assertEquals(10, manualCount)
        assertEquals(5, aiCount)
    }
}
