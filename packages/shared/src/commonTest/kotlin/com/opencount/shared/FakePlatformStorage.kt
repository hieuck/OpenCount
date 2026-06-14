package com.opencount.shared

import com.opencount.shared.model.CountSession
import com.opencount.shared.service.StorageBackend

class FakePlatformStorage : StorageBackend {
    private val sessions = mutableMapOf<String, CountSession>()

    override fun saveSession(session: CountSession) {
        sessions[session.id] = session
    }

    override fun loadSession(id: String): CountSession? = sessions[id]

    override fun loadAllSessions(): List<CountSession> = sessions.values.toList()

    override fun deleteSession(id: String) { sessions.remove(id) }

    override fun sessionExists(id: String): Boolean = sessions.containsKey(id)

    fun clear() { sessions.clear() }
    val count: Int get() = sessions.size
}
