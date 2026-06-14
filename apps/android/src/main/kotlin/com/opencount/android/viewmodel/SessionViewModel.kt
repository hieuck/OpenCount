package com.opencount.android.viewmodel

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.opencount.shared.model.CountSession
import com.opencount.shared.service.ExportService
import com.opencount.shared.service.PlatformStorage
import com.opencount.shared.service.StorageService
import com.opencount.shared.util.Counter
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch

class SessionViewModel : ViewModel() {
    private val storage = StorageService(PlatformStorage())
    private val export = ExportService()

    private val _sessions = MutableStateFlow<List<CountSession>>(emptyList())
    val sessions: StateFlow<List<CountSession>> = _sessions.asStateFlow()

    private val _currentSession = MutableStateFlow<CountSession?>(null)
    val currentSession: StateFlow<CountSession?> = _currentSession.asStateFlow()

    private val _count = MutableStateFlow(0)
    val count: StateFlow<Int> = _count.asStateFlow()

    fun loadSessions() {
        viewModelScope.launch {
            _sessions.value = storage.loadAll()
        }
    }

    fun createSession(name: String) {
        val session = CountSession.create(name)
        storage.save(session)
        _currentSession.value = session
        _count.value = 0
        loadSessions()
    }

    fun selectSession(session: CountSession) {
        _currentSession.value = session
        _count.value = Counter.totalCount(session)
    }

    fun selectSessionById(id: String) {
        val session = storage.load(id)
        if (session != null) selectSession(session)
    }

    fun incrementCount() {
        _count.value = _count.value + 1
    }

    fun decrementCount() {
        if (_count.value > 0) _count.value = _count.value - 1
    }

    fun deleteSession(id: String) {
        storage.delete(id)
        if (_currentSession.value?.id == id) _currentSession.value = null
        loadSessions()
    }

    fun exportSession(id: String): String? {
        val session = storage.load(id) ?: return null
        return export.exportToJson(session)
    }
}
