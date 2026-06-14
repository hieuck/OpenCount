package com.opencount.shared.service

import com.opencount.shared.model.CountSession
import com.opencount.shared.model.ObjectType
import kotlinx.datetime.Clock
import kotlinx.serialization.Serializable
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json

@Serializable
data class SessionTemplate(
    val id: String,
    val name: String,
    val description: String = "",
    val createdAt: kotlinx.datetime.Instant,
    val objectTypeData: List<TemplateObjectTypeData>,
)

@Serializable
data class TemplateObjectTypeData(
    val name: String,
    val colorHex: String,
    val iconName: String,
)

class TemplateLibraryService {
    private val json = Json { prettyPrint = true }
    private val templates = mutableListOf<SessionTemplate>()

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

    fun loadAll(): List<SessionTemplate> = templates.toList()

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

    fun previewObjectTypes(template: SessionTemplate): List<TemplateObjectTypeData> = template.objectTypeData

    fun exportToJson(): String = json.encodeToString(templates)

    fun importFromJson(jsonStr: String): List<SessionTemplate> {
        val imported = try { json.decodeFromString<List<SessionTemplate>>(jsonStr) } catch (_: Exception) { emptyList<SessionTemplate>() }
        templates.clear()
        templates.addAll(imported)
        return imported
    }

    fun clear() { templates.clear() }
    val count: Int get() = templates.size
}
