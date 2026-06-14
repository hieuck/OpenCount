package com.opencount.desktop

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import androidx.compose.ui.window.Window
import androidx.compose.ui.window.application
import androidx.compose.ui.window.rememberWindowState
import com.opencount.shared.i18n.Strings
import com.opencount.shared.model.CountSession
import com.opencount.shared.service.ExportService
import com.opencount.shared.service.PlatformStorage
import com.opencount.shared.service.StorageService
import com.opencount.shared.util.Counter

fun main() = application {
    Window(
        onCloseRequest = ::exitApplication,
        title = "OpenCount",
        state = rememberWindowState(width = 900.dp, height = 650.dp),
    ) {
        MaterialTheme {
            OpenCountDesktopApp()
        }
    }
}

@Composable
fun OpenCountDesktopApp() {
    val storage = remember { StorageService(PlatformStorage()) }
    val export = remember { ExportService() }
    var currentView by remember { mutableStateOf("counting") }
    var sessions by remember { mutableStateOf(storage.loadAll()) }
    var currentSession by remember { mutableStateOf<CountSession?>(null) }
    var count by remember { mutableStateOf(0) }

    Surface(modifier = Modifier.fillMaxSize()) {
        Row {
            NavigationRail {
                NavigationRailItem(
                    selected = currentView == "counting",
                    onClick = { currentView = "counting" },
                    icon = { Text("+", style = MaterialTheme.typography.titleLarge) },
                    label = { Text(Strings.tallyMode, style = MaterialTheme.typography.labelSmall) },
                )
                NavigationRailItem(
                    selected = currentView == "sessions",
                    onClick = {
                        sessions = storage.loadAll()
                        currentView = "sessions"
                    },
                    icon = { Text("S", style = MaterialTheme.typography.titleLarge) },
                    label = { Text(Strings.sessions, style = MaterialTheme.typography.labelSmall) },
                )
                NavigationRailItem(
                    selected = currentView == "settings",
                    onClick = { currentView = "settings" },
                    icon = { Text("\u2699", style = MaterialTheme.typography.titleLarge) },
                    label = { Text(Strings.settings, style = MaterialTheme.typography.labelSmall) },
                )
            }
            when (currentView) {
                "counting" -> CountingView(
                    count = count,
                    sessionName = currentSession?.name,
                    onIncrement = { count++ },
                    onDecrement = { if (count > 0) count-- },
                    onClear = { count = 0 },
                )
                "sessions" -> SessionListView(
                    sessions = sessions,
                    storage = storage,
                    export = export,
                    onSessionSelected = { session ->
                        currentSession = session
                        count = Counter.totalCount(session)
                        currentView = "counting"
                    },
                    onSessionCreated = {
                        sessions = storage.loadAll()
                    },
                )
                "settings" -> SettingsView()
            }
        }
    }
}

@Composable
fun CountingView(
    count: Int,
    sessionName: String?,
    onIncrement: () -> Unit,
    onDecrement: () -> Unit,
    onClear: () -> Unit,
) {
    Column(
        modifier = Modifier.fillMaxSize().padding(32.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center,
    ) {
        if (sessionName != null) {
            Text(sessionName, style = MaterialTheme.typography.titleMedium)
            Spacer(Modifier.height(16.dp))
        }
        Text(text = "$count", style = MaterialTheme.typography.displayLarge)
        Spacer(Modifier.height(24.dp))
        Row(horizontalArrangement = Arrangement.spacedBy(16.dp)) {
            Button(onClick = onIncrement) { Text(Strings.addMarker) }
            OutlinedButton(onClick = onDecrement) { Text(Strings.removeMarker) }
        }
        Spacer(Modifier.height(16.dp))
        OutlinedButton(onClick = onClear) { Text(Strings.clearAll) }
    }
}

@Composable
fun SessionListView(
    sessions: List<CountSession>,
    storage: StorageService,
    export: ExportService,
    onSessionSelected: (CountSession) -> Unit,
    onSessionCreated: () -> Unit,
) {
    var showNewDialog by remember { mutableStateOf(false) }
    var searchQuery by remember { mutableStateOf("") }

    val filteredSessions = remember(sessions, searchQuery) {
        if (searchQuery.isBlank()) sessions
        else sessions.filter { it.name.contains(searchQuery, ignoreCase = true) }
    }

    Column(modifier = Modifier.fillMaxSize().padding(16.dp)) {
        Text(Strings.sessions, style = MaterialTheme.typography.headlineMedium)
        Spacer(Modifier.height(8.dp))
        OutlinedTextField(
            value = searchQuery,
            onValueChange = { searchQuery = it },
            label = { Text(Strings.searchSessions) },
            modifier = Modifier.fillMaxWidth(),
            singleLine = true,
        )
        Spacer(Modifier.height(8.dp))
        Button(onClick = { showNewDialog = true }) {
            Text(Strings.newSession)
        }
        Spacer(Modifier.height(8.dp))
        if (filteredSessions.isEmpty()) {
            Text(Strings.newSession, style = MaterialTheme.typography.bodyLarge)
        } else {
            LazyColumn(modifier = Modifier.weight(1f)) {
                items(filteredSessions, key = { it.id }) { session ->
                    Card(
                        modifier = Modifier.fillMaxWidth().padding(vertical = 4.dp),
                        onClick = { onSessionSelected(session) },
                    ) {
                        Row(
                            modifier = Modifier.padding(16.dp).fillMaxWidth(),
                            horizontalArrangement = Arrangement.SpaceBetween,
                            verticalAlignment = Alignment.CenterVertically,
                        ) {
                            Column {
                                Text(session.name, style = MaterialTheme.typography.titleMedium)
                                Text(
                                    "${Counter.totalCount(session)} ${Strings.totalCount.lowercase()}",
                                    style = MaterialTheme.typography.bodySmall,
                                )
                            }
                            Row {
                                TextButton(onClick = {
                                    val csv = export.exportToCsv(session)
                                    println("CSV Export:\n$csv")
                                }) {
                                    Text(Strings.exportCSV)
                                }
                                TextButton(onClick = {
                                    storage.delete(session.id)
                                    onSessionCreated()
                                }) {
                                    Text(Strings.deleteSession)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    if (showNewDialog) {
        var name by remember { mutableStateOf("") }
        AlertDialog(
            onDismissRequest = { showNewDialog = false },
            title = { Text(Strings.newSession) },
            text = {
                OutlinedTextField(
                    value = name,
                    onValueChange = { name = it },
                    label = { Text(Strings.renameSession) },
                    singleLine = true,
                )
            },
            confirmButton = {
                TextButton(onClick = {
                    if (name.isNotBlank()) {
                        storage.save(CountSession.create(name))
                        onSessionCreated()
                        showNewDialog = false
                    }
                }) { Text("OK") }
            },
            dismissButton = {
                TextButton(onClick = { showNewDialog = false }) { Text("Cancel") }
            },
        )
    }
}

@Composable
fun SettingsView() {
    val languages = listOf("en" to "English", "vi" to "Tiếng Việt", "ja" to "日本語",
        "ko" to "한국어", "zh" to "中文", "fr" to "Français", "de" to "Deutsch", "es" to "Español")
    var selectedLang by remember { mutableStateOf(Strings.language) }

    Column(modifier = Modifier.fillMaxSize().padding(24.dp)) {
        Text(Strings.settings, style = MaterialTheme.typography.headlineMedium)
        Spacer(Modifier.height(24.dp))
        Card(modifier = Modifier.fillMaxWidth()) {
            Column(modifier = Modifier.padding(16.dp)) {
                Text(Strings.languageLabel, style = MaterialTheme.typography.titleMedium)
                Spacer(Modifier.height(8.dp))
                languages.forEach { (code, name) ->
                    Row(
                        modifier = Modifier.fillMaxWidth().padding(vertical = 2.dp),
                        verticalAlignment = Alignment.CenterVertically,
                    ) {
                        RadioButton(
                            selected = selectedLang == code,
                            onClick = {
                                selectedLang = code
                                Strings.language = code
                            }
                        )
                        Spacer(Modifier.width(8.dp))
                        Text(name)
                    }
                }
                Spacer(Modifier.height(16.dp))
                HorizontalDivider()
                Spacer(Modifier.height(16.dp))
                Text(Strings.about, style = MaterialTheme.typography.titleMedium)
                Spacer(Modifier.height(8.dp))
                Text("${Strings.appName} v${com.opencount.shared.OpenCountSDK.VERSION}")
                Text("${Strings.version}: ${com.opencount.shared.OpenCountSDK.NAME}")
                Spacer(Modifier.height(8.dp))
                Text(Strings.feedback, style = MaterialTheme.typography.titleMedium)
            }
        }
    }
}

private val String.lowercase: String get() = this.lowercase()
