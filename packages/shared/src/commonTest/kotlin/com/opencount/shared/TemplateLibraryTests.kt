package com.opencount.shared

import com.opencount.shared.model.CountSession
import com.opencount.shared.model.ObjectType
import com.opencount.shared.service.TemplateLibraryService
import com.opencount.shared.service.SessionTemplate
import com.opencount.shared.service.TemplateObjectTypeData
import kotlin.test.Test
import kotlin.test.*

class TemplateLibraryTests {
    private val service = TemplateLibraryService()

    @Test
    fun testSaveAndLoad() {
        val session = CountSession.create("Test").copy(
            objectTypes = listOf(
                ObjectType.create("Cars", colorHex = "#FF0000"),
                ObjectType.create("People", colorHex = "#00FF00"),
            ),
        )
        service.saveAsTemplate("Traffic", "Count vehicles", session)
        assertEquals(1, service.count)

        val loaded = service.loadAll()
        assertEquals(1, loaded.size)
        assertEquals("Traffic", loaded[0].name)
    }

    @Test
    fun testApplyTemplate() {
        val template = SessionTemplate(
            id = "t1",
            name = "Test Template",
            description = "A test",
            createdAt = kotlinx.datetime.Clock.System.now(),
            objectTypeData = listOf(
                TemplateObjectTypeData("Cars", "#FF0000", "car.fill"),
                TemplateObjectTypeData("Trucks", "#0000FF", "truck.fill"),
            ),
        )
        val session = CountSession.create("Original")
        val updated = service.applyTemplate(template, session)

        assertEquals(2, updated.objectTypes.size)
        assertEquals("Cars", updated.objectTypes[0].name)
        assertEquals("Trucks", updated.objectTypes[1].name)
    }

    @Test
    fun testPreviewReturnsTypes() {
        val template = SessionTemplate(
            id = "t2",
            name = "Preview Test",
            createdAt = kotlinx.datetime.Clock.System.now(),
            objectTypeData = listOf(
                TemplateObjectTypeData("A", "#111", "a"),
            ),
        )
        val preview = service.previewObjectTypes(template)
        assertEquals(1, preview.size)
        assertEquals("A", preview[0].name)
    }

    @Test
    fun testJSONRoundTrip() {
        val session = CountSession.create("S1").copy(
            objectTypes = listOf(ObjectType.create("Cars"))
        )
        service.saveAsTemplate("Test", "", session)

        val json = service.exportToJson()
        service.clear()
        assertEquals(0, service.count)

        val imported = service.importFromJson(json)
        assertEquals(1, imported.size)
        assertEquals("Test", imported[0].name)
    }

    @Test
    fun testMultipleTemplates() {
        val session = CountSession.create("S1")
        service.saveAsTemplate("T1", "", session)
        service.saveAsTemplate("T2", "", session)
        service.saveAsTemplate("T3", "", session)

        assertEquals(3, service.count)
        assertEquals(3, service.loadAll().size)
    }

    @Test
    fun testClear() {
        val session = CountSession.create("S1")
        service.saveAsTemplate("T1", "", session)
        service.clear()
        assertEquals(0, service.count)
    }

    @Test
    fun testImportInvalidJSON() {
        val imported = service.importFromJson("not valid json")
        assertTrue(imported.isEmpty())
    }
}
