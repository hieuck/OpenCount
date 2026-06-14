package com.opencount.shared.i18n

actual fun currentLanguageCode(): String {
    val nav = js("navigator") as? dynamic
    return (nav?.language as? String)?.substringBefore("-") ?: "en"
}
