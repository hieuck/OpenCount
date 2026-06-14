package com.opencount.web

import com.opencount.shared.i18n.Strings
import com.opencount.shared.OpenCountSDK

fun main() {
    val root = js("document.getElementById('root')")
    root.innerHTML = """
        <div style="font-family: sans-serif; max-width: 600px; margin: 40px auto; text-align: center;">
            <h1>${Strings.appName} Web</h1>
            <p>${Strings.appVersion}: ${OpenCountSDK.VERSION}</p>
            <p>${Strings.liveCount} — ${Strings.aiDetect} — ${Strings.voiceCount}</p>
            <p>${Strings.sessions}</p>
        </div>
    """.trimIndent()
}
