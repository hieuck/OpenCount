package com.opencount.shared.service

import com.opencount.shared.model.CountSession
import com.opencount.shared.model.CountMarker
import com.opencount.shared.model.ObjectType
import com.opencount.shared.model.NormalizedPoint
import com.opencount.shared.model.CountRegion
import com.opencount.shared.model.RegionShapeType
import kotlinx.datetime.Instant

object SampleSessionSeeder {
    private const val SEEN_KEY = "sample_session_seeded"

    fun seedIfNeeded(storage: StorageService, force: Boolean = false) {
        if (!force && hasSeen()) return
        val session = createSampleSession()
        storage.save(session)
        markSeen()
    }

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

    fun sampleJSON(): String {
        val json = kotlinx.serialization.json.Json { prettyPrint = true }
        return json.encodeToString(CountSession.serializer(), createSampleSession())
    }

    private fun hasSeen(): Boolean {
        // In-memory flag for now; platform implementations can persist
        return false
    }

    private fun markSeen() {
        // No-op for KMP; platform implementations can use SharedPreferences/NSUserDefaults
    }
}
