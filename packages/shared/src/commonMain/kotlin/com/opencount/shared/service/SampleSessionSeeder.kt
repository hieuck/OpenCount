package com.opencount.shared.service

import com.opencount.shared.model.CountSession
import com.opencount.shared.model.CountMarker
import com.opencount.shared.model.ObjectType
import com.opencount.shared.model.NormalizedPoint
import com.opencount.shared.model.CountRegion
import com.opencount.shared.model.RegionShapeType
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json

expect fun persistFlag(key: String, value: Boolean)
expect fun readFlag(key: String): Boolean

/**
 * Seeds a sample counting session on first launch to demonstrate app functionality.
 * Uses platform-specific persist/read flags to ensure the sample is created only once.
 */
object SampleSessionSeeder {
    private const val SEEN_KEY = "sample_session_seeded"

    /**
     * Creates and saves a sample session if one has not already been created.
     * @param storage the storage service to save into
     * @param force if true, ignores the seen flag and always seeds
     */
    fun seedIfNeeded(storage: StorageService, force: Boolean = false) {
        if (!force && readFlag(SEEN_KEY)) return
        val session = createSampleSession()
        storage.save(session)
        persistFlag(SEEN_KEY, true)
    }

    /**
     * Creates a sample [CountSession] with Cars, People, and Trees object types,
     * several markers across two regions, and a welcome description.
     */
    fun createSampleSession(): CountSession {
        val types = listOf(
            ObjectType.create("Cars", colorHex = "#FF5733"),
            ObjectType.create("People", colorHex = "#33FF57"),
            ObjectType.create("Trees", colorHex = "#3357FF"),
        )
        val markers = listOf(
            CountMarker.create(0.1, 0.2, types[0].id),
            CountMarker.create(0.3, 0.4, types[0].id),
            CountMarker.create(0.5, 0.6, types[0].id),
            CountMarker.create(0.2, 0.3, types[1].id),
            CountMarker.create(0.4, 0.5, types[1].id),
            CountMarker.create(0.6, 0.7, types[2].id),
        )
        val regions = listOf(
            CountRegion(
                id = "sample-region-1",
                name = "Parking Lot",
                shapeType = RegionShapeType.Rectangle,
                normalizedPoints = listOf(NormalizedPoint(0.0, 0.0), NormalizedPoint(0.5, 0.5)),
            ),
        )
        val zonedMarkers = markers.mapIndexed { i, m ->
            if (i < 4) m.copy(regionId = "sample-region-1") else m
        }

        return CountSession.create("Sample Count").copy(
            objectTypes = types,
            markers = zonedMarkers,
            regions = regions,
            sessionDescription = "Welcome to OpenCount! This sample session shows how counting works.",
        )
    }

    /** Returns a pretty-printed JSON representation of the sample session, useful for previews. */
    fun sampleJSON(): String {
        val json = Json { prettyPrint = true }
        return json.encodeToString(CountSession.serializer(), createSampleSession())
    }
}
