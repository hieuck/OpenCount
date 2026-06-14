package com.opencount.shared.service

import com.opencount.shared.model.CountSession
import kotlinx.browser.localStorage
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json

actual class PlatformStorage : StorageBackend {
    private val json = Json { ignoreUnknownKeys = true; isLenient = true }
    private val storageKey = "opencount_sessions"

    override fun saveSession(session: CountSession) {
        val sessions = loadAllRaw().toMutableList()
        val entry = json.encodeToString(session)
        val index = sessions.indexOfFirst { it.contains("\"${session.id}\"") }
        if (index >= 0) sessions[index] = entry else sessions.add(entry)
        setAll(sessions)
    }

    override fun loadSession(id: String): CountSession? = loadAll().find { it.id == id }

    override fun loadAllSessions(): List<CountSession> = loadAll()

    override fun deleteSession(id: String) {
        val sessions = loadAll().filter { it.id != id }
        setAll(sessions.map { json.encodeToString(it) })
    }

    override fun sessionExists(id: String): Boolean = loadAll().any { it.id == id }

    private fun loadAll(): List<CountSession> {
        return loadAllRaw().mapNotNull { raw ->
            try { json.decodeFromString<CountSession>(raw) } catch (_: Exception) { null }
        }
    }

    private fun loadAllRaw(): List<String> {
        val stored = localStorage.getItem(storageKey) ?: return emptyList()
        return try {
            @Suppress("UNCHECKED_CAST")
            (JSON.parse<Array<*>>(stored) as Array<*>).filterIsInstance<String>()
        } catch (_: Exception) { emptyList() }
    }

    private fun setAll(sessions: List<String>) {
        localStorage.setItem(storageKey, JSON.stringify(sessions.toTypedArray()))
    }
}
