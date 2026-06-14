package com.opencount.shared.service

import platform.Foundation.NSUserDefaults

actual fun persistFlag(key: String, value: Boolean) {
    NSUserDefaults.standardUserDefaults.setBool(value, forKey = key)
}

actual fun readFlag(key: String): Boolean {
    return NSUserDefaults.standardUserDefaults.boolForKey(key)
}
