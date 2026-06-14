package com.opencount.shared.service

import com.opencount.shared.model.CountSession
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json
import java.io.File

actual class PlatformStorage : StorageBackend {
    private val json = Json { ignoreUnknownKeys = true; isLenient = true }
    private val sessionDir: File = File(System.getProperty("user.home"), ".opencount/sessions")

    init { sessionDir.mkdirs() }

    override fun saveSession(session: CountSession) {
        File(sessionDir, "${session.id}.json").writeText(json.encodeToString(session))
    }

    override fun loadSession(id: String): CountSession? {
        val file = File(sessionDir, "$id.json")
        if (!file.exists()) return null
        return try { json.decodeFromString<CountSession>(file.readText()) } catch (_: Exception) { null }
    }

    override fun loadAllSessions(): List<CountSession> {
        if (!sessionDir.exists()) return emptyList()
        return sessionDir.listFiles()
            ?.filter { it.extension == "json" }
            ?.mapNotNull { file ->
                try { json.decodeFromString<CountSession>(file.readText()) } catch (_: Exception) { null }
            } ?: emptyList()
    }

    override fun deleteSession(id: String) { File(sessionDir, "$id.json").delete() }
    override fun sessionExists(id: String): Boolean = File(sessionDir, "$id.json").exists()
}
