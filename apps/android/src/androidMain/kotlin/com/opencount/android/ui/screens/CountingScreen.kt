package com.opencount.android.ui.screens

import androidx.compose.foundation.layout.*
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
fun CountingScreen(
    modifier: Modifier = Modifier,
    viewModel: SessionViewModel = viewModel(),
) {
    val count by viewModel.count.collectAsStateWithLifecycle()
    val currentSession by viewModel.currentSession.collectAsStateWithLifecycle()

    Scaffold(
        modifier = modifier,
        topBar = {
            TopAppBar(title = { Text(currentSession?.name ?: Strings.tallyMode) })
        }
    ) { padding ->
        Column(
            modifier = Modifier.fillMaxSize().padding(padding),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.Center,
        ) {
            Text(text = "$count", style = MaterialTheme.typography.displayLarge)
            if (currentSession != null) {
                Text(text = currentSession!!.name, style = MaterialTheme.typography.titleMedium)
            }
            Spacer(modifier = Modifier.height(32.dp))
            Row(horizontalArrangement = Arrangement.spacedBy(16.dp)) {
                Button(onClick = { viewModel.incrementCount() }) {
                    Text(Strings.addMarker)
                }
                OutlinedButton(onClick = { viewModel.decrementCount() }) {
                    Text(Strings.removeMarker)
                }
            }
        }
    }
}
