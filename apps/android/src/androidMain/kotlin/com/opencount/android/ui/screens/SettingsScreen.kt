package com.opencount.android.ui.screens

import androidx.compose.foundation.layout.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import com.opencount.shared.i18n.Strings

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun SettingsScreen(modifier: Modifier = Modifier) {
    val languages = listOf("en" to "English", "vi" to "Tiếng Việt", "ja" to "日本語",
        "ko" to "한국어", "zh" to "中文", "fr" to "Français", "de" to "Deutsch", "es" to "Español")
    var selectedLang by remember { mutableStateOf(Strings.language) }

    Scaffold(
        modifier = modifier,
        topBar = { TopAppBar(title = { Text(Strings.settings) }) }
    ) { padding ->
        Column(modifier = Modifier.fillMaxSize().padding(padding).padding(16.dp)) {
            Text(Strings.languageLabel, style = MaterialTheme.typography.titleMedium)
            Spacer(Modifier.height(8.dp))
            languages.forEach { (code, name) ->
                Row(modifier = Modifier.fillMaxWidth().padding(vertical = 2.dp),
                    verticalAlignment = androidx.compose.ui.Alignment.CenterVertically) {
                    RadioButton(
                        selected = selectedLang == code,
                        onClick = { selectedLang = code; Strings.language = code }
                    )
                    Spacer(Modifier.width(8.dp))
                    Text(name)
                }
            }
            Spacer(Modifier.height(16.dp))
            HorizontalDivider()
            Spacer(Modifier.height(16.dp))
            Text(Strings.about, style = MaterialTheme.typography.titleMedium)
            Text("${Strings.appName} v${com.opencount.shared.OpenCountSDK.VERSION}")
            Spacer(Modifier.height(8.dp))
            Text(Strings.feedback)
        }
    }
}
