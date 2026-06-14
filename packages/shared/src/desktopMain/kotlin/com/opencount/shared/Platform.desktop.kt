package com.opencount.shared

actual fun getPlatformName(): String = "${System.getProperty("os.name")} ${System.getProperty("os.version")}"
