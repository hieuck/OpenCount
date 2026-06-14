package com.opencount.shared.service

import com.opencount.shared.model.CountSession
import com.opencount.shared.model.ObjectType
import kotlinx.datetime.Instant
import kotlinx.serialization.Serializable
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json

@Serializable
data class SessionTemplate(
    val id: String,
    val name: String,
    val description: String = "",
    val createdAt: Instant,
    val objectTypeData: List<TemplateObjectTypeData>,
)

@Serializable
data class TemplateObjectTypeData(
    val name: String,
    val colorHex: String,
    val iconName: String,
)

class TemplateLibraryService(private val storage: StorageBackend) {
    private val json = Json { prettyPrint = true }

    private val templatesKey = "templates_metadata"

    fun saveAsTemplate(name: String, description: String, session: CountSession) {
        val template = SessionTemplate(
            id = kotlinx.datetime.Clock.System.now().toEpochMilliseconds().toString(),
            name = name,
            description = description,
            createdAt = kotlinx.datetime.Clock.System.now(),
            objectTypeData = session.objectTypes.map {
                TemplateObjectTypeData(name = it.name, colorHex = it.colorHex, iconName = it.iconName)
            },
        )
        val all = loadAll().toMutableList()
        all.add(template)
        saveAllMetadata(all)
    }

    fun loadAll(): List<SessionTemplate> {
        // Load from storage
        return emptyList() // placeholder - real impl needs separate template storage
    }

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

    private fun saveAllMetadata(templates: List<SessionTemplate>) {
        // Persist template metadata
    }
}
