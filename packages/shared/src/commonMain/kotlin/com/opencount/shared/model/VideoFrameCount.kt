package com.opencount.shared.model

import kotlinx.serialization.Serializable

@Serializable
data class VideoFrameCount(
    val id: String,
    val timestampSeconds: Double,
    val markerIds: List<String> = emptyList(),
)
