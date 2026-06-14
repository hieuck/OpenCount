package com.opencount.shared.util

import com.opencount.shared.model.CountMarker
import com.opencount.shared.model.CountSession

object Counter {
    fun tallyByType(session: CountSession): Map<String, Int> {
        val typeCounts = mutableMapOf<String, Int>()
        for (marker in session.markers) {
            val type = session.objectTypes.find { it.id == marker.objectTypeId }
            val typeName = type?.name ?: "Unknown"
            typeCounts[typeName] = (typeCounts[typeName] ?: 0) + 1
        }
        return typeCounts
    }

    fun totalCount(session: CountSession): Int = session.markers.size

    fun tallyByRegion(session: CountSession): Map<String, Map<String, Int>> {
        val result = mutableMapOf<String, MutableMap<String, Int>>()
        for (marker in session.markers) {
            val regionName = if (marker.regionId != null) {
                session.regions.find { it.id == marker.regionId }?.name ?: "Unknown"
            } else "None"
            val typeName = session.objectTypes.find { it.id == marker.objectTypeId }?.name ?: "Unknown"
            result.getOrPut(regionName) { mutableMapOf() }
                .let { it[typeName] = (it[typeName] ?: 0) + 1 }
        }
        return result
    }

    fun countByAIDerived(session: CountSession): Pair<Int, Int> {
        val ai = session.markers.count { it.isAIDerived }
        val manual = session.markers.size - ai
        return Pair(manual, ai)
    }
}
