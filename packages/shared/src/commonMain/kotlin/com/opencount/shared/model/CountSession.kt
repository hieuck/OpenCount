package com.opencount.shared.model

import kotlinx.datetime.Instant
import kotlin.random.Random
import kotlinx.serialization.Serializable

@Serializable
data class TallyHistoryEntry(
    val timestamp: Instant,
    val objectTypeName: String,
    val delta: Int,
)

@Serializable
data class CountSession(
    val id: String,
    val name: String,
    val sessionDescription: String? = null,
    val createdAt: Instant,
    val modifiedAt: Instant,
    val objectTypes: List<ObjectType> = emptyList(),
    val images: List<SessionImage> = emptyList(),
    val regions: List<CountRegion> = emptyList(),
    val markers: List<CountMarker> = emptyList(),
    val videoTimestamps: List<VideoFrameCount> = emptyList(),
    val formulas: List<CountFormula> = emptyList(),
    val tallyHistory: List<TallyHistoryEntry> = emptyList(),
) {
    companion object {
        fun create(name: String): CountSession = CountSession(
            id = uuid(),
            name = name,
            createdAt = Instant.DISTANT_PAST,
            modifiedAt = Instant.DISTANT_PAST,
        )
    }
}

internal fun uuid(): String {
    val timestamp = kotlinx.datetime.Clock.System.now().toEpochMilliseconds()
    val random = (Random.nextLong() and 0xFFFFFFFFFFFF) or 0x1000000000000
    return "${timestamp}-${random}"
}
