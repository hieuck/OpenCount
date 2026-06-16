package com.opencount.shared

import com.opencount.shared.model.*
import com.opencount.shared.service.*
import com.opencount.shared.util.Counter
import com.opencount.shared.util.DuplicateDetector
import kotlin.test.Test
import kotlin.test.*

class AdvancedIntegrationTests {
    @Test
    fun smartCountAndCounterIntegration() {
        val smart = SmartCountService(duplicateRadius = 0.05)
        val type = ObjectType.create("Cells")
        val markers = (1..20).map { i ->
            CountMarker.create(i * 0.04, i * 0.04, type.id)
        }
        val session = CountSession.create("Lab").copy(
            objectTypes = listOf(type),
            markers = markers,
        )
        val clusters = smart.detectClusters(session.markers, clusterRadius = 0.1)
        assertTrue(clusters.isNotEmpty())
        assertEquals(20, Counter.totalCount(session))
    }

    @Test
    fun exportAndReimportWorkflow() {
        val type = ObjectType.create("Items")
        val session = CountSession.create("Export Cycle").copy(
            objectTypes = listOf(type),
            markers = listOf(
                CountMarker.create(0.1, 0.1, type.id),
                CountMarker.create(0.2, 0.2, type.id),
            ),
        )
        val export = ExportService()
        val json = export.exportToJson(session)
        val fake = FakePlatformStorage()
        val storage = StorageService(fake)
        val restored = storage.fromJson(json)
        assertEquals(session.name, restored.name)
        assertEquals(session.markers.size, restored.markers.size)
    }

    @Test
    fun templateApplyAndCount() {
        val template = SessionTemplate(
            id = "t1", name = "Demo", description = "",
            createdAt = kotlinx.datetime.Clock.System.now(),
            objectTypeData = listOf(
                TemplateObjectTypeData("A", "#111", "a"),
                TemplateObjectTypeData("B", "#222", "b"),
            ),
        )
        val lib = TemplateLibraryService()
        val session = CountSession.create("Original")
        val updated = lib.applyTemplate(template, session)
        val tally = Counter.tallyByType(updated)
        assertEquals(0, tally.values.sum())
        assertEquals(2, updated.objectTypes.size)
    }

    @Test
    fun seedThenSmartSuggest() {
        val suggest = SmartSuggestionsService()
        val session = SampleSessionSeeder.createSampleSession()
        val suggestions = suggest.suggestions(listOf(session), limit = 3)
        assertTrue(suggestions.isNotEmpty())
        assertTrue(suggestions.any { it.name in listOf("Cars", "People", "Trees") })
    }

    @Test
    fun crashRecoveryWithSessionExport() {
        val fs = FakeFileStorage()
        val type = ObjectType.create("Widgets")
        val session = CountSession.create("Recovery").copy(
            objectTypes = listOf(type),
            markers = listOf(
                CountMarker.create(0.3, 0.4, type.id),
                CountMarker.create(0.5, 0.6, type.id),
            ),
        )
        CrashRecoveryService.saveRecovery(session, fs)
        val loaded = CrashRecoveryService.loadRecovery(fs)
        assertNotNull(loaded)
        assertEquals("Recovery", loaded.name)
        assertEquals(2, loaded.markers.size)
    }

    @Test
    fun fullWorkflowWithRegionsAndFormulas() {
        val cars = ObjectType.create("Cars")
        val trucks = ObjectType.create("Trucks")
        val region = CountRegion(
            id = "z1", name = "Zone 1", shapeType = RegionShapeType.Rectangle,
            normalizedPoints = listOf(NormalizedPoint(0.0, 0.0), NormalizedPoint(0.5, 1.0)),
        )
        val formula = CountFormula(id = "f1", name = "Total", expression = "Cars + Trucks")
        val markers = listOf(
            CountMarker.create(0.1, 0.2, cars.id, regionId = "z1"),
            CountMarker.create(0.2, 0.3, cars.id, regionId = "z1"),
            CountMarker.create(0.4, 0.5, trucks.id),
        )
        val session = CountSession.create("Full Workflow").copy(
            objectTypes = listOf(cars, trucks),
            regions = listOf(region),
            formulas = listOf(formula),
            markers = markers,
        )
        val tally = Counter.tallyByType(session)
        val formulaResult = FormulaEvaluator.evaluate(formula, tally)
        assertEquals(3, Counter.totalCount(session))
        assertNotNull(formulaResult)
        assertEquals(3.0, formulaResult)
        val regionTally = Counter.tallyByRegion(session)
        assertEquals(2, regionTally["Zone 1"]?.get("Cars"))
    }

    @Test
    fun velocityFatigueIntegration() {
        val tracker = CountingVelocityTracker(windowSeconds = 10)
        val count = 15
        repeat(count) { tracker.recordMarker() }
        assertTrue(tracker.markersPerMinute() > 0)
    }

    @Test
    fun smartCountGridSuggestion() {
        val smart = SmartCountService()
        val density = smart.suggestGridDensity(1920.0, 1080.0)
        assertTrue(density in 3..20)
    }

    @Test
    fun multipleSessionExportWorkflow() {
        val typeA = ObjectType.create("A")
        val typeB = ObjectType.create("B")
        val s1 = CountSession.create("S1").copy(
            objectTypes = listOf(typeA),
            markers = listOf(CountMarker.create(0.5, 0.5, typeA.id)),
        )
        val s2 = CountSession.create("S2").copy(
            objectTypes = listOf(typeB),
            markers = listOf(
                CountMarker.create(0.5, 0.5, typeB.id),
                CountMarker.create(0.6, 0.6, typeB.id),
            ),
        )
        val export = ExportService()
        val csv = export.exportToCsv(listOf(s1, s2))
        assertTrue(csv.contains("\"S1\""))
        assertTrue(csv.contains("\"S2\""))
        assertTrue(csv.contains("\"B\",2"))
    }
}
