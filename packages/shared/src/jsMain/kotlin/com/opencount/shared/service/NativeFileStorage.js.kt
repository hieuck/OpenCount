package com.opencount.shared.service

import kotlinx.browser.localStorage

actual class NativeFileStorage : FileStorage {
    private val prefix = "opencount_file_"

    override fun write(filename: String, data: String) {
        localStorage.setItem("$prefix$filename", data)
    }

    override fun read(filename: String): String? {
        return localStorage.getItem("$prefix$filename")
    }

    override fun delete(filename: String) {
        localStorage.removeItem("$prefix$filename")
    }
}
