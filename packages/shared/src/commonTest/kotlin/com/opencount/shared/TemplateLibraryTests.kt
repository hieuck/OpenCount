package com.opencount.shared

import com.opencount.shared.model.CountSession
import com.opencount.shared.model.ObjectType
import com.opencount.shared.service.TemplateLibraryService
import kotlin.test.Test
import kotlin.test.*

class TemplateLibraryTests {
    private val fake = FakePlatformStorage()
    private val service = TemplateLibraryService(fake)

    @Test
    fun testPreviewObjectTypes() {
        val session = CountSession.create("Test").copy(
            objectTypes = listOf(
                ObjectType.create("Cars", colorHex = "#FF0000"),
                ObjectType.create("People", colorHex = "#00FF00"),
            ),
        )
        service.saveAsTemplate("Traffic", "Count vehicles", session)
        // Template is created but save is a no-op for now
    }

    @Test
    fun testApplyTemplate() {
        val template = com.opencount.shared.service.SessionTemplate(
            id = "t1",
            name = "Test Template",
            createdAt = kotlinx.datetime.Clock.System.now(),
            objectTypeData = listOf(
                com.opencount.shared.service.TemplateObjectTypeData("Cars", "#FF0000", "car.fill"),
                com.opencount.shared.service.TemplateObjectTypeData("Trucks", "#0000FF", "truck.fill"),
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
        val template = com.opencount.shared.service.SessionTemplate(
            id = "t2",
            name = "Preview Test",
            createdAt = kotlinx.datetime.Clock.System.now(),
            objectTypeData = listOf(
                com.opencount.shared.service.TemplateObjectTypeData("A", "#111", "a"),
            ),
        )
        val preview = service.previewObjectTypes(template)
        assertEquals(1, preview.size)
        assertEquals("A", preview[0].name)
    }
}
