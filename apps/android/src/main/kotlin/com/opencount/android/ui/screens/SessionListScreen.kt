package com.opencount.android.ui.screens

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import com.opencount.shared.i18n.Strings
import com.opencount.shared.model.CountSession

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun SessionListScreen(modifier: Modifier = Modifier) {
    var sessions by remember { mutableStateOf(listOf<CountSession>()) }

    Scaffold(
        modifier = modifier,
        topBar = {
            TopAppBar(title = { Text(Strings.sessions) })
        }
    ) { padding ->
        Column(modifier = Modifier.fillMaxSize().padding(padding).padding(16.dp)) {
            if (sessions.isEmpty()) {
                Text(Strings.newSession, style = MaterialTheme.typography.bodyLarge)
            } else {
                LazyColumn {
                    items(sessions) { session ->
                        Card(modifier = Modifier.fillMaxWidth().padding(vertical = 4.dp)) {
                            Text(
                                text = session.name,
                                modifier = Modifier.padding(16.dp),
                                style = MaterialTheme.typography.titleMedium,
                            )
                        }
                    }
                }
            }
        }
    }
}
