package com.opencount.shared.service

import java.util.prefs.Preferences

actual fun persistFlag(key: String, value: Boolean) {
    Preferences.userNodeForPackage(SampleSessionSeeder::class.java).putBoolean(key, value)
}

actual fun readFlag(key: String): Boolean {
    return Preferences.userNodeForPackage(SampleSessionSeeder::class.java).getBoolean(key, false)
}
