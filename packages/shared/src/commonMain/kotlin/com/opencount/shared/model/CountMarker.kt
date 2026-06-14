package com.opencount.shared.model

import kotlinx.datetime.Instant
import kotlinx.serialization.Serializable

@Serializable
data class CountMarker(
    val id: String,
    val normalizedX: Double,
    val normalizedY: Double,
    val objectTypeId: String,
    val isAIDerived: Boolean = false,
    val createdAt: Instant,
    val regionId: String? = null,
) {
    companion object {
        fun create(
            normalizedX: Double,
            normalizedY: Double,
            objectTypeId: String,
            isAIDerived: Boolean = false,
            regionId: String? = null,
        ): CountMarker = CountMarker(
            id = uuid(),
            normalizedX = normalizedX,
            normalizedY = normalizedY,
            objectTypeId = objectTypeId,
            isAIDerived = isAIDerived,
            createdAt = kotlinx.datetime.Clock.System.now(),
            regionId = regionId,
        )
    }
}
