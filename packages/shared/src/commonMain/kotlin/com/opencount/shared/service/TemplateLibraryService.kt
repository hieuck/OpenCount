package com.opencount.shared.service

import com.opencount.shared.model.CountSession
import com.opencount.shared.model.ObjectType
import kotlinx.datetime.Clock
import kotlinx.serialization.Serializable
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json

/** A saved session template containing object type definitions that can be reapplied to new sessions. */
@Serializable
data class SessionTemplate(
    val id: String,
    val name: String,
    val description: String = "",
    val createdAt: kotlinx.datetime.Instant,
    val objectTypeData: List<TemplateObjectTypeData>,
)

/** Serializable object type definition within a [SessionTemplate]. Holds name, color, and icon. */
@Serializable
data class TemplateObjectTypeData(
    val name: String,
    val colorHex: String,
    val iconName: String,
)

/**
 * Service for managing session templates — reusable sets of object type definitions
 * that can be saved, applied to new sessions, and exported/imported as JSON.
 */
class TemplateLibraryService {
    private val json = Json { prettyPrint = true }
    private val templates = mutableListOf<SessionTemplate>()

    /**
     * Creates a template from the object types in [session] and adds it to the library.
     * @param name display name for the template
     * @param description optional description of the template's purpose
     * @param session source session whose object types will be captured
     */
    fun saveAsTemplate(name: String, description: String, session: CountSession) {
        val template = SessionTemplate(
            id = Clock.System.now().toEpochMilliseconds().toString(),
            name = name,
            description = description,
            createdAt = Clock.System.now(),
            objectTypeData = session.objectTypes.map {
                TemplateObjectTypeData(name = it.name, colorHex = it.colorHex, iconName = it.iconName)
            },
        )
        templates.add(template)
    }

    /** Returns a copy of all stored templates. */
    fun loadAll(): List<SessionTemplate> = templates.toList()

    /**
     * Applies a [template]'s object types to the given [session], returning a new session
     * with replaced object types. The original session is not modified.
     */
    fun applyTemplate(template: SessionTemplate, session: CountSession): CountSession {
        val types = template.objectTypeData.map { data ->
            ObjectType.create(
                name = data.name,
                colorHex = data.colorHex,
                iconName = data.iconName,
            )
        }
        return session.copy(objectTypes = types)
    }

    /** Returns the object type definitions from a [template] for preview purposes. */
    fun previewObjectTypes(template: SessionTemplate): List<TemplateObjectTypeData> = template.objectTypeData

    /** Exports all templates as a JSON string. */
    fun exportToJson(): String = json.encodeToString(templates)

    /**
     * Imports templates from a JSON string, replacing any existing templates in memory.
     * @return the list of imported templates, or an empty list if parsing fails
     */
    fun importFromJson(jsonStr: String): List<SessionTemplate> {
        val imported = try { json.decodeFromString<List<SessionTemplate>>(jsonStr) } catch (_: Exception) { emptyList<SessionTemplate>() }
        templates.clear()
        templates.addAll(imported)
        return imported
    }

    /** Removes all templates from the library. */
    fun clear() { templates.clear() }
    /** The number of templates currently in the library. */
    val count: Int get() = templates.size
}
