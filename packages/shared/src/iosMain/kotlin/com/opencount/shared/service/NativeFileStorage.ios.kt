package com.opencount.shared.service

import platform.Foundation.*

actual class NativeFileStorage : FileStorage {
    private val fileManager = NSFileManager.defaultManager
    private val docsDir: String
        get() {
            val paths = NSSearchPathForDirectoriesInDomains(
                NSDocumentDirectory, NSUserDomainMask, true
            )
            return (paths.firstOrNull() as? String) ?: ""
        }

    override fun write(filename: String, data: String) {
        val path = "$docsDir/$filename"
        (data as NSString).writeToFile(path, atomically = true, encoding = NSUTF8StringEncoding, error = null)
    }

    override fun read(filename: String): String? {
        val path = "$docsDir/$filename"
        return NSString.stringWithContentsOfFile(path, encoding = NSUTF8StringEncoding, error = null)
    }

    override fun delete(filename: String) {
        val path = "$docsDir/$filename"
        fileManager.removeItemAtPath(path, error = null)
    }
}
