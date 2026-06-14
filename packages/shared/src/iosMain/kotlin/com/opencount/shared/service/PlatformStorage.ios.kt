package com.opencount.shared.service

import com.opencount.shared.model.CountSession
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json

actual class PlatformStorage {
    private val json = Json { ignoreUnknownKeys = true; isLenient = true }

    actual fun saveSession(session: CountSession) {
        // iOS uses NSDocumentDirectory via Swift bridge
        NativeStorageHelper.save(session.id, json.encodeToString(session))
    }

    actual fun loadSession(id: String): CountSession? {
        val jsonString = NativeStorageHelper.load(id) ?: return null
        return try { json.decodeFromString<CountSession>(jsonString) } catch (_: Exception) { null }
    }

    actual fun loadAllSessions(): List<CountSession> {
        return NativeStorageHelper.loadAll().mapNotNull { jsonString ->
            try { json.decodeFromString<CountSession>(jsonString) } catch (_: Exception) { null }
        }
    }

    actual fun deleteSession(id: String) = NativeStorageHelper.delete(id)
    actual fun sessionExists(id: String): Boolean = NativeStorageHelper.exists(id)
}

// Bridged to Swift native file system via @objc
object NativeStorageHelper {
    private var bridge: StorageBridge? = null
    fun setBridge(b: StorageBridge) { bridge = b }
    fun save(id: String, json: String) { bridge?.save(id, json) }
    fun load(id: String): String? = bridge?.load(id)
    fun loadAll(): List<String> = bridge?.loadAll() ?: emptyList()
    fun delete(id: String) { bridge?.delete(id) }
    fun exists(id: String): Boolean = bridge?.exists(id) ?: false
}

interface StorageBridge {
    fun save(id: String, json: String)
    fun load(id: String): String?
    fun loadAll(): List<String>
    fun delete(id: String)
    fun exists(id: String): Boolean
}
