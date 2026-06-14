package com.opencount.shared.service

import android.content.Context
import com.opencount.shared.model.CountSession
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json

actual class PlatformStorage {
    private val json = Json { ignoreUnknownKeys = true; isLenient = true }

    companion object {
        private var appContext: Context? = null
        fun init(context: Context) { appContext = context }
    }

    private fun getDir() = appContext?.filesDir?.resolve("sessions")

    actual fun saveSession(session: CountSession) {
        val dir = getDir() ?: return
        dir.mkdirs()
        val file = dir.resolve("${session.id}.json")
        file.writeText(json.encodeToString(session))
    }

    actual fun loadSession(id: String): CountSession? {
        val file = getDir()?.resolve("$id.json") ?: return null
        if (!file.exists()) return null
        return try { json.decodeFromString<CountSession>(file.readText()) } catch (_: Exception) { null }
    }

    actual fun loadAllSessions(): List<CountSession> {
        val dir = getDir() ?: return emptyList()
        if (!dir.exists()) return emptyList()
        return dir.listFiles()
            ?.filter { it.extension == "json" }
            ?.mapNotNull { file ->
                try { json.decodeFromString<CountSession>(file.readText()) } catch (_: Exception) { null }
            } ?: emptyList()
    }

    actual fun deleteSession(id: String) {
        getDir()?.resolve("$id.json")?.delete()
    }

    actual fun sessionExists(id: String): Boolean =
        getDir()?.resolve("$id.json")?.exists() ?: false
}
