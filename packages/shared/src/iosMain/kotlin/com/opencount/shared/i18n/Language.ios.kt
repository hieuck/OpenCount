package com.opencount.shared.i18n

import platform.Foundation.NSLocale

actual fun currentLanguageCode(): String =
    NSLocale.currentLocale.languageCode ?: "en"
