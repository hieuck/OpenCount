package com.opencount.shared.service

import com.opencount.shared.model.CountSession
import com.opencount.shared.model.CountMarker
import com.opencount.shared.model.ObjectType
import kotlinx.datetime.Instant
import kotlinx.serialization.Serializable
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json

@Serializable
data class SessionExportDTO(
    val id: String,
    val name: String,
    val createdAt: Instant,
    val objectTypeNames: Map<String, String>,
    val markers: List<MarkerDTO>,
) {
    constructor(session: CountSession) : this(
        id = session.id,
        name = session.name,
        createdAt = session.createdAt,
        objectTypeNames = session.objectTypes.associate { it.id to it.name },
        markers = session.markers.map { MarkerDTO(it) },
    )
}

@Serializable
data class MarkerDTO(
    val id: String,
    val normalizedX: Double,
    val normalizedY: Double,
    val objectTypeId: String,
    val isAIDerived: Boolean,
    val createdAt: Instant,
) {
    constructor(marker: CountMarker) : this(
        id = marker.id,
        normalizedX = marker.normalizedX,
        normalizedY = marker.normalizedY,
        objectTypeId = marker.objectTypeId,
        isAIDerived = marker.isAIDerived,
        createdAt = marker.createdAt,
    )
}

interface FileStorage {
    fun write(filename: String, data: String)
    fun read(filename: String): String?
    fun delete(filename: String)
}

expect class NativeFileStorage() : FileStorage

object CrashRecoveryService {
    private const val RECOVERY_FILE = "recovery.opencount"
    private val json = Json { prettyPrint = true }

    fun saveRecovery(session: CountSession, storage: FileStorage) {
        val dto = SessionExportDTO(session)
        storage.write(RECOVERY_FILE, json.encodeToString(dto))
    }

    fun loadRecovery(storage: FileStorage): SessionExportDTO? {
        val data = storage.read(RECOVERY_FILE) ?: return null
        return try { json.decodeFromString<SessionExportDTO>(data) } catch (_: Exception) { null }
    }

    fun clearRecovery(storage: FileStorage) {
        storage.delete(RECOVERY_FILE)
    }
}
