package com.opencount.shared.model

import kotlinx.datetime.Instant
import kotlinx.serialization.Serializable

@Serializable
data class SessionImage(
    val id: String,
    val filename: String,
    val thumbnailFilename: String? = null,
    val optimizedFilename: String? = null,
    val importedAt: Instant,
) {
    companion object {
        fun create(
            filename: String,
            thumbnailFilename: String? = null,
            optimizedFilename: String? = null,
        ): SessionImage = SessionImage(
            id = uuid(),
            filename = filename,
            thumbnailFilename = thumbnailFilename,
            optimizedFilename = optimizedFilename,
            importedAt = kotlinx.datetime.Clock.System.now(),
        )
    }
}
