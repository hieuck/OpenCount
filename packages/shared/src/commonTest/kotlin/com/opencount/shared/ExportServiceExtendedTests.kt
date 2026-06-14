package com.opencount.shared

import com.opencount.shared.model.CountSession
import com.opencount.shared.model.CountMarker
import com.opencount.shared.model.ObjectType
import com.opencount.shared.service.ExportService
import kotlin.test.Test
import kotlin.test.*

class ExportServiceExtendedTests {
    private val export = ExportService()

    @Test
    fun testPlainTextSummary() {
        val typeA = ObjectType.create("Cars")
        val session = CountSession.create("Test").copy(
            objectTypes = listOf(typeA),
            markers = listOf(
                CountMarker.create(0.1, 0.1, typeA.id),
                CountMarker.create(0.2, 0.2, typeA.id),
            )
        )
        val summary = export.plainTextSummary(session)
        assertTrue(summary.contains("Test"))
        assertTrue(summary.contains("2"))
        assertTrue(summary.contains("Cars"))
    }

    @Test
    fun testCocoExport() {
        val cars = ObjectType.create("Cars")
        val trucks = ObjectType.create("Trucks")
        val session = CountSession.create("Traffic").copy(
            objectTypes = listOf(cars, trucks),
            markers = listOf(
                CountMarker.create(0.1, 0.2, cars.id),
                CountMarker.create(0.3, 0.4, trucks.id),
                CountMarker.create(0.5, 0.6, cars.id),
            ),
        )
        val coco = export.exportToCoco(session)
        assertTrue(coco.contains("Traffic"))
        assertTrue(coco.contains("Cars"))
        assertTrue(coco.contains("Trucks"))
        assertTrue(coco.contains("annotations"))
        assertTrue(coco.contains("categories"))
    }

    @Test
    fun testCsvQuotesNames() {
        val typeA = ObjectType.create("Cars, Trucks & SUVs")
        val session = CountSession.create("Test").copy(
            objectTypes = listOf(typeA),
            markers = listOf(CountMarker.create(0.1, 0.1, typeA.id)),
        )
        val csv = export.exportToCsv(session)
        assertTrue(csv.contains("\"Cars, Trucks & SUVs\""))
    }

    @Test
    fun testCsvMultipleSessionsQuoted() {
        val s1 = CountSession.create("Session A").copy(
            objectTypes = listOf(ObjectType.create("A")),
            markers = listOf(CountMarker.create(0.1, 0.1, "a1")),
        )
        val s2 = CountSession.create("Session B").copy(
            objectTypes = listOf(ObjectType.create("B")),
            markers = listOf(CountMarker.create(0.1, 0.1, "b1")),
        )
        val csv = export.exportToCsv(listOf(s1, s2))
        assertTrue(csv.contains("\"Session A\""))
        assertTrue(csv.contains("\"Session B\""))
    }

    @Test
    fun testCocoEmptySession() {
        val session = CountSession.create("Empty")
        val coco = export.exportToCoco(session)
        assertTrue(coco.contains("Empty"))
        assertTrue(coco.contains("\"annotations\": []"))
    }
}
