package com.opencount.android.ui

import androidx.compose.foundation.layout.padding
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.Home
import androidx.compose.material.icons.filled.Settings
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.lifecycle.viewmodel.compose.viewModel
import androidx.navigation.NavDestination.Companion.hierarchy
import androidx.navigation.NavGraph.Companion.findStartDestination
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.currentBackStackEntryAsState
import androidx.navigation.compose.rememberNavController
import com.opencount.android.ui.screens.CountingScreen
import com.opencount.android.ui.screens.SessionListScreen
import com.opencount.android.ui.screens.SettingsScreen
import com.opencount.android.viewmodel.SessionViewModel

sealed class Screen(val route: String, val label: String, val icon: ImageVector) {
    data object Sessions : Screen("sessions", "Sessions", Icons.Default.Home)
    data object Counting : Screen("counting", "Count", Icons.Default.Add)
    data object Settings : Screen("settings", "Settings", Icons.Default.Settings)
}

@Composable
fun OpenCountApp() {
    val navController = rememberNavController()
    val sessionViewModel: SessionViewModel = viewModel()
    val navBackStackEntry by navController.currentBackStackEntryAsState()
    val currentDestination = navBackStackEntry?.destination
    val items = listOf(Screen.Sessions, Screen.Counting, Screen.Settings)

    Scaffold(
        bottomBar = {
            NavigationBar {
                items.forEach { screen ->
                    NavigationBarItem(
                        icon = { Icon(screen.icon, contentDescription = screen.label) },
                        label = { Text(screen.label) },
                        selected = currentDestination?.hierarchy?.any { it.route == screen.route } == true,
                        onClick = {
                            navController.navigate(screen.route) {
                                popUpTo(navController.graph.findStartDestination().id) { saveState = true }
                                launchSingleTop = true
                                restoreState = true
                            }
                        },
                    )
                }
            }
        }
    ) { padding ->
        NavHost(
            navController = navController,
            startDestination = Screen.Sessions.route,
            modifier = Modifier.padding(padding),
        ) {
            composable(Screen.Sessions.route) {
                SessionListScreen(
                    onSessionSelected = { id ->
                        sessionViewModel.selectSessionById(id)
                        navController.navigate(Screen.Counting.route)
                    },
                    viewModel = sessionViewModel,
                )
            }
            composable(Screen.Counting.route) {
                CountingScreen(viewModel = sessionViewModel)
            }
            composable(Screen.Settings.route) {
                SettingsScreen()
            }
        }
    }
}
