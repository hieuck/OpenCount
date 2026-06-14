package com.opencount.web

import com.opencount.shared.i18n.Strings
import com.opencount.shared.OpenCountSDK
import org.w3c.dom.HTMLButtonElement
import org.w3c.dom.HTMLDivElement
import org.w3c.dom.HTMLElement
import kotlinx.browser.document
import kotlinx.browser.window

private var count = 0

fun main() {
    val root = document.getElementById("root") as HTMLDivElement
    root.innerHTML = buildUI()
    wireEvents(root)
}

private fun buildUI(): String = """
    <div style="font-family: -apple-system, BlinkMacSystemFont, sans-serif; max-width: 400px; margin: 40px auto; text-align: center;">
        <h1 style="color: #333;">${Strings.appName}</h1>
        <div id="counter-display" style="font-size: 72px; font-weight: bold; color: #1a73e8; margin: 24px 0;">0</div>
        <div style="color: #666; margin-bottom: 24px;">${Strings.totalCount}: <span id="total-display">0</span></div>
        <div style="display: flex; gap: 12px; justify-content: center; margin-bottom: 16px;">
            <button id="btn-add" style="padding: 12px 32px; font-size: 18px; background: #1a73e8; color: white; border: none; border-radius: 8px; cursor: pointer;">${Strings.addMarker}</button>
            <button id="btn-remove" style="padding: 12px 32px; font-size: 18px; background: #eee; color: #333; border: 1px solid #ccc; border-radius: 8px; cursor: pointer;">${Strings.removeMarker}</button>
        </div>
        <button id="btn-clear" style="padding: 8px 24px; font-size: 14px; background: transparent; color: #d32f2f; border: 1px solid #d32f2f; border-radius: 8px; cursor: pointer;">${Strings.clearAll}</button>
        <hr style="margin: 24px 0;">
        <div style="color: #999; font-size: 12px;">
            <p>${OpenCountSDK.NAME} v${OpenCountSDK.VERSION}</p>
            <p>${Strings.sessions}</p>
            <p>${Strings.aiDetect} &bull; ${Strings.liveCount} &bull; ${Strings.voiceCount}</p>
        </div>
    </div>
""".trimIndent()

private fun wireEvents(root: HTMLElement) {
    root.querySelector("#btn-add")?.let {
        (it as HTMLButtonElement).addEventListener("click", { count++ ; updateDisplay(root) })
    }
    root.querySelector("#btn-remove")?.let {
        (it as HTMLButtonElement).addEventListener("click", { if (count > 0) count-- ; updateDisplay(root) })
    }
    root.querySelector("#btn-clear")?.let {
        (it as HTMLButtonElement).addEventListener("click", { count = 0 ; updateDisplay(root) })
    }
}

private fun updateDisplay(root: HTMLElement) {
    root.querySelector("#counter-display")?.textContent = count.toString()
    root.querySelector("#total-display")?.textContent = count.toString()
}
