package com.opencount.shared.service

import com.opencount.shared.model.CountSession
import com.opencount.shared.model.CountMarker
import com.opencount.shared.model.ObjectType
import kotlinx.datetime.Instant
import kotlinx.serialization.Serializable
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json

/** Serializable DTO for persisting a [CountSession] to crash recovery storage. */
@Serializable
data class SessionExportDTO(
    val id: String,
    val name: String,
    val createdAt: Instant,
    val objectTypeNames: Map<String, String>,
    val markers: List<MarkerDTO>,
) {
    /** Constructs a DTO from a [CountSession], flattening object types and markers. */
    constructor(session: CountSession) : this(
        id = session.id,
        name = session.name,
        createdAt = session.createdAt,
        objectTypeNames = session.objectTypes.associate { it.id to it.name },
        markers = session.markers.map { MarkerDTO(it) },
    )
}

/** Serializable DTO for a single marker within a [SessionExportDTO]. */
@Serializable
data class MarkerDTO(
    val id: String,
    val normalizedX: Double,
    val normalizedY: Double,
    val objectTypeId: String,
    val isAIDerived: Boolean,
    val createdAt: Instant,
) {
    /** Constructs a DTO from a [CountMarker]. */
    constructor(marker: CountMarker) : this(
        id = marker.id,
        normalizedX = marker.normalizedX,
        normalizedY = marker.normalizedY,
        objectTypeId = marker.objectTypeId,
        isAIDerived = marker.isAIDerived,
        createdAt = marker.createdAt,
    )
}

/** Platform-specific file storage for crash recovery data. */
interface FileStorage {
    /** Writes [data] to a file identified by [filename]. */
    fun write(filename: String, data: String)
    /** Reads the contents of [filename], or null if it does not exist. */
    fun read(filename: String): String?
    /** Deletes the file identified by [filename], if it exists. */
    fun delete(filename: String)
}

/** Platform-specific implementation of [FileStorage] created via expect/actual. */
expect class NativeFileStorage() : FileStorage

/**
 * Service for persisting and restoring in-progress counting sessions across app crashes.
 * Writes to a fixed recovery file; call [saveRecovery] periodically and [loadRecovery] on startup.
 */
object CrashRecoveryService {
    private const val RECOVERY_FILE = "recovery.opencount"
    private val json = Json { prettyPrint = true }

    /** Saves the current [session] to crash recovery storage, overwriting any prior recovery data. */
    fun saveRecovery(session: CountSession, storage: FileStorage) {
        val dto = SessionExportDTO(session)
        storage.write(RECOVERY_FILE, json.encodeToString(dto))
    }

    /**
     * Loads a previously saved recovery session, if one exists.
     * @return the recovered DTO, or null if no recovery data is available or it is corrupt
     */
    fun loadRecovery(storage: FileStorage): SessionExportDTO? {
        val data = storage.read(RECOVERY_FILE) ?: return null
        return try { json.decodeFromString<SessionExportDTO>(data) } catch (_: Exception) { null }
    }

    /** Deletes any saved recovery data. Call after a session has been fully restored or discarded. */
    fun clearRecovery(storage: FileStorage) {
        storage.delete(RECOVERY_FILE)
    }
}
