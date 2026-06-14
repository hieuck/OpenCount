package com.opencount.shared.service

import kotlinx.browser.localStorage

actual fun persistFlag(key: String, value: Boolean) {
    localStorage.setItem(key, if (value) "1" else "0")
}

actual fun readFlag(key: String): Boolean {
    return localStorage.getItem(key) == "1"
}
