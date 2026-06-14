package com.opencount.android.ui

import androidx.compose.foundation.layout.padding
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.Home
import androidx.compose.material.icons.filled.Settings
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import com.opencount.android.ui.screens.CountingScreen
import com.opencount.android.ui.screens.SessionListScreen
import com.opencount.android.ui.screens.SettingsScreen

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun OpenCountApp() {
    var currentScreen by remember { mutableStateOf("sessions") }

    Scaffold(
        bottomBar = {
            NavigationBar {
                NavigationBarItem(
                    selected = currentScreen == "sessions",
                    onClick = { currentScreen = "sessions" },
                    icon = { Icon(Icons.Default.Home, contentDescription = "Sessions") },
                    label = { Text("Sessions") },
                )
                NavigationBarItem(
                    selected = currentScreen == "counting",
                    onClick = { currentScreen = "counting" },
                    icon = { Icon(Icons.Default.Add, contentDescription = "Count") },
                    label = { Text("Count") },
                )
                NavigationBarItem(
                    selected = currentScreen == "settings",
                    onClick = { currentScreen = "settings" },
                    icon = { Icon(Icons.Default.Settings, contentDescription = "Settings") },
                    label = { Text("Settings") },
                )
            }
        }
    ) { padding ->
        when (currentScreen) {
            "sessions" -> SessionListScreen(modifier = Modifier.padding(padding))
            "counting" -> CountingScreen(modifier = Modifier.padding(padding))
            "settings" -> SettingsScreen(modifier = Modifier.padding(padding))
        }
    }
}
