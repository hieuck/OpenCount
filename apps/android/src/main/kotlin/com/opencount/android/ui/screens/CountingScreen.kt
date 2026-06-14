package com.opencount.android.ui.screens

import androidx.compose.foundation.layout.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import com.opencount.shared.i18n.Strings

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun CountingScreen(modifier: Modifier = Modifier) {
    var count by remember { mutableStateOf(0) }

    Scaffold(
        modifier = modifier,
        topBar = {
            TopAppBar(title = { Text(Strings.tallyMode) })
        }
    ) { padding ->
        Column(
            modifier = Modifier.fillMaxSize().padding(padding),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.Center,
        ) {
            Text(
                text = "$count",
                style = MaterialTheme.typography.displayLarge,
            )
            Spacer(modifier = Modifier.height(32.dp))
            Row(
                horizontalArrangement = Arrangement.spacedBy(16.dp)
            ) {
                Button(onClick = { count++ }) {
                    Text(Strings.addMarker)
                }
                OutlinedButton(onClick = { if (count > 0) count-- }) {
                    Text(Strings.removeMarker)
                }
            }
        }
    }
}
