package com.opencount.shared.i18n

actual fun currentLanguageCode(): String {
    val lang: String? = js("typeof navigator !== 'undefined' ? navigator.language : null")
    return lang?.substringBefore("-") ?: "en"
}
