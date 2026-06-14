package com.opencount.shared.service

import android.content.Context

actual fun persistFlag(key: String, value: Boolean) {
    SampleSessionSeeder_android.context?.let { ctx ->
        ctx.getSharedPreferences("opencount_prefs", Context.MODE_PRIVATE)
            .edit().putBoolean(key, value).apply()
    }
}

actual fun readFlag(key: String): Boolean {
    return SampleSessionSeeder_android.context?.let { ctx ->
        ctx.getSharedPreferences("opencount_prefs", Context.MODE_PRIVATE)
            .getBoolean(key, false)
    } ?: false
}

object SampleSessionSeeder_android {
    var context: Context? = null
    fun init(ctx: Context) { context = ctx }
}
