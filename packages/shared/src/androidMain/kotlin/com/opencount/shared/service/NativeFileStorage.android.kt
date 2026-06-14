package com.opencount.shared.service

import android.content.Context
import java.io.File

actual class NativeFileStorage : FileStorage {
    companion object {
        private var appContext: Context? = null
        fun init(context: Context) { appContext = context }
    }

    private val baseDir: File?
        get() = appContext?.filesDir

    override fun write(filename: String, data: String) {
        val dir = baseDir ?: return
        dir.mkdirs()
        File(dir, filename).writeText(data)
    }

    override fun read(filename: String): String? {
        val dir = baseDir ?: return null
        val file = File(dir, filename)
        return if (file.exists()) file.readText() else null
    }

    override fun delete(filename: String) {
        val dir = baseDir ?: return
        File(dir, filename).delete()
    }
}
