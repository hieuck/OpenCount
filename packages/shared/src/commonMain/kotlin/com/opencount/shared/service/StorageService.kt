package com.opencount.shared.service

import com.opencount.shared.model.CountSession
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json

/** Platform-specific storage backend for persisting and retrieving [CountSession]s. */
interface StorageBackend {
    /** Persists a [session], overwriting any existing session with the same ID. */
    fun saveSession(session: CountSession)
    /** Loads the session with the given [id], or null if not found. */
    fun loadSession(id: String): CountSession?
    /** Returns all stored sessions. */
    fun loadAllSessions(): List<CountSession>
    /** Deletes the session with the given [id]. */
    fun deleteSession(id: String)
    /** Returns true if a session with the given [id] exists. */
    fun sessionExists(id: String): Boolean
}

/** Platform-specific implementation of [StorageBackend] created via expect/actual. */
expect class PlatformStorage() : StorageBackend

/**
 * High-level service wrapping a [StorageBackend] with JSON serialization utilities.
 * Provides a convenient API for saving, loading, and deleting sessions.
 */
class StorageService(private val backend: StorageBackend) {
    private val json = Json {
        prettyPrint = true
        ignoreUnknownKeys = true
        isLenient = true
    }

    /** Saves a session to the storage backend. */
    fun save(session: CountSession) { backend.saveSession(session) }
    /** Loads a session by [id], or null if not found. */
    fun load(id: String): CountSession? = backend.loadSession(id)
    /** Returns all saved sessions. */
    fun loadAll(): List<CountSession> = backend.loadAllSessions()
    /** Deletes the session with the given [id]. */
    fun delete(id: String) = backend.deleteSession(id)
    /** Returns true if a session with the given [id] exists. */
    fun exists(id: String): Boolean = backend.sessionExists(id)
    /** Serializes a [session] to a pretty-printed JSON string. */
    fun toJson(session: CountSession): String = json.encodeToString(session)
    /** Deserializes a [CountSession] from a JSON string. */
    fun fromJson(jsonString: String): CountSession = json.decodeFromString<CountSession>(jsonString)
}
