package com.opencount.shared.model

import kotlinx.datetime.Instant
import kotlinx.serialization.Serializable

@Serializable
data class SessionTag(
    val id: String,
    val name: String,
    val colorHex: String = "#3498DB",
    val emoji: String = "\uD83C\uDFF7\uFE0F",
    val createdAt: Instant,
) {
    companion object {
        val predefinedTags: List<Triple<String, String, String>> = listOf(
            Triple("Wildlife", "#2ECC71", "\uD83E\uDD81"),
            Triple("Inventory", "#3498DB", "\uD83D\uDCE6"),
            Triple("Research", "#9B59B6", "\uD83D\uDD2C"),
            Triple("Agriculture", "#F39C12", "\uD83C\uDF3E"),
            Triple("Urban", "#E74C3C", "\uD83C\uDFD9\uFE0F"),
            Triple("Marine", "#1ABC9C", "\uD83D\uDC20"),
            Triple("Aerial", "#34495E", "\u2708\uFE0F"),
            Triple("Medical", "#E67E22", "\uD83C\uDFE5"),
            Triple("Sports", "#F1C40F", "\u26BD"),
            Triple("Education", "#16A085", "\uD83D\uDCDA"),
        )
    }
}
