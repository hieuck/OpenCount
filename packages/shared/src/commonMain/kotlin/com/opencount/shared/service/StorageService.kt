package com.opencount.shared.service

import com.opencount.shared.model.CountSession
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json

expect class PlatformStorage {
    fun saveSession(session: CountSession)
    fun loadSession(id: String): CountSession?
    fun loadAllSessions(): List<CountSession>
    fun deleteSession(id: String)
    fun sessionExists(id: String): Boolean
}

class StorageService(private val platform: PlatformStorage) {
    private val json = Json {
        prettyPrint = true
        ignoreUnknownKeys = true
        isLenient = true
    }

    fun save(session: CountSession) {
        platform.saveSession(session)
    }

    fun load(id: String): CountSession? = platform.loadSession(id)

    fun loadAll(): List<CountSession> = platform.loadAllSessions()

    fun delete(id: String) = platform.deleteSession(id)

    fun exists(id: String): Boolean = platform.sessionExists(id)

    fun toJson(session: CountSession): String = json.encodeToString(session)

    fun fromJson(jsonString: String): CountSession = json.decodeFromString<CountSession>(jsonString)
}
