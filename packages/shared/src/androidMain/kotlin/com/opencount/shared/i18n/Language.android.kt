package com.opencount.shared.i18n

import java.util.Locale

actual fun currentLanguageCode(): String = Locale.getDefault().language
