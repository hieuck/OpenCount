package com.opencount.shared.service

import com.opencount.shared.model.CountSession
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json

interface StorageBackend {
    fun saveSession(session: CountSession)
    fun loadSession(id: String): CountSession?
    fun loadAllSessions(): List<CountSession>
    fun deleteSession(id: String)
    fun sessionExists(id: String): Boolean
}

expect class PlatformStorage() : StorageBackend

class StorageService(private val backend: StorageBackend) {
    private val json = Json {
        prettyPrint = true
        ignoreUnknownKeys = true
        isLenient = true
    }

    fun save(session: CountSession) { backend.saveSession(session) }
    fun load(id: String): CountSession? = backend.loadSession(id)
    fun loadAll(): List<CountSession> = backend.loadAllSessions()
    fun delete(id: String) = backend.deleteSession(id)
    fun exists(id: String): Boolean = backend.sessionExists(id)
    fun toJson(session: CountSession): String = json.encodeToString(session)
    fun fromJson(jsonString: String): CountSession = json.decodeFromString<CountSession>(jsonString)
}
