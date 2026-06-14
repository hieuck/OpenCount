package com.opencount.shared

import com.opencount.shared.model.*
import com.opencount.shared.service.ExportService
import kotlin.test.Test
import kotlin.test.assertTrue

class ExportServiceTests {
    @Test
    fun testExportJson() {
        val session = CountSession.create("Test")
        val service = ExportService()
        val json = service.exportToJson(session)
        assertTrue(json.contains("Test"))
        assertTrue(json.contains("id"))
    }

    @Test
    fun testExportCsv() {
        val typeA = ObjectType.create("Cars")
        val session = CountSession.create("Test").copy(
            objectTypes = listOf(typeA),
            markers = listOf(
                CountMarker.create(0.1, 0.1, typeA.id),
                CountMarker.create(0.2, 0.2, typeA.id),
            )
        )
        val service = ExportService()
        val csv = service.exportToCsv(session)
        assertTrue(csv.contains("Cars"))
        assertTrue(csv.contains("2"))
    }
}
