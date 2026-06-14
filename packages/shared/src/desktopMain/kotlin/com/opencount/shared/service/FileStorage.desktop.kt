package com.opencount.shared.service

import java.io.File

actual class NativeFileStorage : FileStorage {
    private val baseDir = File(System.getProperty("user.home"), ".opencount")
    init { baseDir.mkdirs() }

    override fun write(filename: String, data: String) {
        File(baseDir, filename).writeText(data)
    }

    override fun read(filename: String): String? {
        val file = File(baseDir, filename)
        return if (file.exists()) file.readText() else null
    }

    override fun delete(filename: String) {
        File(baseDir, filename).delete()
    }
}
