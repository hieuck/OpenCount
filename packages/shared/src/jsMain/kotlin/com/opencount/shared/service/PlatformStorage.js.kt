package com.opencount.shared.service

import com.opencount.shared.model.CountSession
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json

actual class PlatformStorage {
    private val json = Json { ignoreUnknownKeys = true; isLenient = true }

    actual fun saveSession(session: CountSession) {
        val existing = js("localStorage.getItem('opencount_sessions')") as? String ?: "[]"
        val sessions = mutableListOf<Any>()
        val parsed = try { JSON.parse<Array<Any>>(existing) } catch (_: Exception) { emptyArray() }
        sessions.addAll(parsed.filter { it.asDynamic().id != session.id })
        sessions.add(json.encodeToString(session))
        js("localStorage.setItem('opencount_sessions', JSON.stringify(@))", sessions.toTypedArray())
    }

    actual fun loadSession(id: String): CountSession? {
        val all = loadAll().find { it.id == id }
        return all
    }

    actual fun loadAllSessions(): List<CountSession> {
        return loadAll()
    }

    actual fun deleteSession(id: String) {
        val all = loadAll().filter { it.id != id }
        js("localStorage.setItem('opencount_sessions', JSON.stringify(@))", all.map { json.encodeToString(it) }.toTypedArray())
    }

    actual fun sessionExists(id: String): Boolean = loadAll().any { it.id == id }

    private fun loadAll(): List<CountSession> {
        val existing = js("localStorage.getItem('opencount_sessions')") as? String ?: return emptyList()
        return try {
            JSON.parse<Array<String>>(existing).mapNotNull { str ->
                try { json.decodeFromString<CountSession>(str) } catch (_: Exception) { null }
            }.toList()
        } catch (_: Exception) { emptyList() }
    }
}
