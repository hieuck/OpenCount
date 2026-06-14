package com.opencount.android.ui.screens

import androidx.compose.foundation.layout.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import com.opencount.shared.i18n.Strings

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun SettingsScreen(modifier: Modifier = Modifier) {
    var selectedLanguage by remember { mutableStateOf(Strings.language) }

    Scaffold(
        modifier = modifier,
        topBar = {
            TopAppBar(title = { Text(Strings.settings) })
        }
    ) { padding ->
        Column(modifier = Modifier.fillMaxSize().padding(padding).padding(16.dp)) {
            Text(Strings.languageLabel, style = MaterialTheme.typography.titleMedium)
            Spacer(modifier = Modifier.height(8.dp))
            Text(Strings.about, style = MaterialTheme.typography.titleMedium)
            Spacer(modifier = Modifier.height(8.dp))
            Text(Strings.feedback, style = MaterialTheme.typography.titleMedium)
        }
    }
}
