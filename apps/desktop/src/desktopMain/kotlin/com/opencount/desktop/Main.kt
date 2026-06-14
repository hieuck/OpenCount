package com.opencount.desktop

import androidx.compose.foundation.layout.*
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
        state = rememberWindowState(width = 800.dp, height = 600.dp),
    ) {
        MaterialTheme {
            OpenCountDesktopApp()
        }
    }
}

@Composable
fun OpenCountDesktopApp() {
    var count by remember { mutableStateOf(0) }
    var currentView by remember { mutableStateOf("counting") }
    val storage = remember { StorageService(PlatformStorage()) }
    val export = remember { ExportService() }

    Surface(modifier = Modifier.fillMaxSize()) {
        Row {
            NavigationRail {
                NavigationRailItem(
                    selected = currentView == "counting",
                    onClick = { currentView = "counting" },
                    icon = { Text("+") },
                    label = { Text(Strings.tallyMode) },
                )
                NavigationRailItem(
                    selected = currentView == "sessions",
                    onClick = { currentView = "sessions" },
                    icon = { Text("S") },
                    label = { Text(Strings.sessions) },
                )
                NavigationRailItem(
                    selected = currentView == "settings",
                    onClick = { currentView = "settings" },
                    icon = { Text("⚙") },
                    label = { Text(Strings.settings) },
                )
            }
            when (currentView) {
                "counting" -> CountingView(count, { count++ }, { if (count > 0) count-- })
                "sessions" -> SessionListView(storage)
                "settings" -> SettingsView()
            }
        }
    }
}

@Composable
fun CountingView(count: Int, onIncrement: () -> Unit, onDecrement: () -> Unit) {
    Column(
        modifier = Modifier.fillMaxSize().padding(32.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center,
    ) {
        Text(text = "$count", style = MaterialTheme.typography.displayLarge)
        Spacer(Modifier.height(24.dp))
        Row(horizontalArrangement = Arrangement.spacedBy(16.dp)) {
            Button(onClick = onIncrement) { Text(Strings.addMarker) }
            OutlinedButton(onClick = onDecrement) { Text(Strings.removeMarker) }
        }
    }
}

@Composable
fun SessionListView(storage: StorageService) {
    Column(modifier = Modifier.fillMaxSize().padding(16.dp)) {
        Text(Strings.sessions, style = MaterialTheme.typography.headlineMedium)
        Spacer(Modifier.height(16.dp))
        Text(Strings.newSession, style = MaterialTheme.typography.bodyLarge)
    }
}

@Composable
fun SettingsView() {
    Column(modifier = Modifier.fillMaxSize().padding(16.dp)) {
        Text(Strings.settings, style = MaterialTheme.typography.headlineMedium)
        Spacer(Modifier.height(16.dp))
        Text(Strings.languageLabel)
        Text(Strings.about)
        Text(Strings.feedback)
    }
}
