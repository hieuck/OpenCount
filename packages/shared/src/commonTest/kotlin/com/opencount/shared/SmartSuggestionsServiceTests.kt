package com.opencount.shared

import com.opencount.shared.model.CountSession
import com.opencount.shared.model.ObjectType
import com.opencount.shared.service.SmartSuggestionsService
import com.opencount.shared.service.ObjectTypeSuggestion
import kotlin.test.Test
import kotlin.test.*

class SmartSuggestionsServiceTests {
    private val service = SmartSuggestionsService()

    @Test
    fun testEmptySessions() {
        val result = service.suggestions(emptyList())
        assertTrue(result.isEmpty())
    }

    @Test
    fun testSuggestsFromSessions() {
        val sessions = listOf(
            CountSession.create("S1").copy(
                objectTypes = listOf(
                    ObjectType.create("Cars"),
                    ObjectType.create("Trucks"),
                )
            ),
            CountSession.create("S2").copy(
                objectTypes = listOf(
                    ObjectType.create("Cars"),
                    ObjectType.create("People"),
                )
            ),
        )
        val result = service.suggestions(sessions, limit = 3)
        assertEquals(3, result.size)
        assertEquals("Cars", result[0].name)
        assertTrue(result[0].frequency >= 2)
    }

    @Test
    fun testExcludesNames() {
        val sessions = listOf(
            CountSession.create("S1").copy(
                objectTypes = listOf(ObjectType.create("Cars"))
            ),
        )
        val result = service.suggestions(sessions, excludingNames = setOf("Cars"))
        assertTrue(result.isEmpty())
    }

    @Test
    fun testDefaultTypes() {
        val types = service.generateDefaultTypes()
        assertEquals(4, types.size)
        assertEquals("People", types[1].name)
    }

    @Test
    fun testIconCategories() {
        val icons = com.opencount.shared.service.iconCategories
        assertTrue(icons.isNotEmpty())
        assertTrue(icons.contains("circle.fill"))
    }

    @Test
    fun testColorPalette() {
        val colors = com.opencount.shared.service.colorPalette
        assertEquals(12, colors.size)
        assertTrue(colors.all { it.startsWith("#") })
    }
}
