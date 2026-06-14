package com.opencount.android.ui.screens

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import com.opencount.android.viewmodel.SessionViewModel
import com.opencount.shared.i18n.Strings

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun SessionListScreen(
    onSessionSelected: (String) -> Unit,
    modifier: Modifier = Modifier,
    viewModel: SessionViewModel = viewModel(),
) {
    val sessions by viewModel.sessions.collectAsStateWithLifecycle()
    var showNewDialog by remember { mutableStateOf(false) }

    LaunchedEffect(Unit) { viewModel.loadSessions() }

    Scaffold(
        modifier = modifier,
        topBar = {
            TopAppBar(
                title = { Text(Strings.sessions) },
                actions = {
                    IconButton(onClick = { showNewDialog = true }) {
                        Icon(Icons.Default.Add, contentDescription = Strings.newSession)
                    }
                }
            )
        }
    ) { padding ->
        if (sessions.isEmpty()) {
            Box(
                modifier = Modifier.fillMaxSize().padding(padding),
                contentAlignment = Alignment.Center,
            ) {
                Column(horizontalAlignment = Alignment.CenterHorizontally) {
                    Text(Strings.newSession, style = MaterialTheme.typography.titleLarge)
                    Spacer(Modifier.height(8.dp))
                    Button(onClick = { showNewDialog = true }) {
                        Text(Strings.addCategory)
                    }
                }
            }
        } else {
            LazyColumn(modifier = Modifier.fillMaxSize().padding(padding).padding(16.dp)) {
                items(sessions, key = { it.id }) { session ->
                    Card(
                        modifier = Modifier.fillMaxWidth().padding(vertical = 4.dp)
                            .clickable { onSessionSelected(session.id) },
                    ) {
                        Row(
                            modifier = Modifier.padding(16.dp).fillMaxWidth(),
                            horizontalArrangement = Arrangement.SpaceBetween,
                            verticalAlignment = Alignment.CenterVertically,
                        ) {
                            Text(session.name, style = MaterialTheme.typography.titleMedium)
                            IconButton(onClick = { viewModel.deleteSession(session.id) }) {
                                Icon(Icons.Default.Delete, contentDescription = Strings.deleteSession)
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
                        viewModel.createSession(name)
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
