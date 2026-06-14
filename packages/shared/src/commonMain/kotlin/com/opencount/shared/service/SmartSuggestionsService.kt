package com.opencount.shared.service

import com.opencount.shared.model.CountSession
import com.opencount.shared.model.ObjectType

data class ObjectTypeSuggestion(
    val name: String,
    val colorHex: String,
    val iconName: String,
    val frequency: Int = 0,
)

val iconCategories: List<String> = listOf(
    "circle.fill", "square.fill", "triangle.fill", "star.fill",
    "heart.fill", "flag.fill", "tag.fill", "bookmark.fill",
    "bell.fill", "fire.fill", "bolt.fill", "leaf.fill",
    "flame.fill", "drop.fill", "moon.fill", "sun.max.fill",
    "car.fill", "bus.fill", "bicycle", "airplane",
    "house.fill", "building.fill", "cart.fill", "bag.fill",
)

val colorPalette: List<String> = listOf(
    "#FF5733", "#33FF57", "#3357FF", "#FF33F5",
    "#33FFF5", "#F5FF33", "#FF8333", "#8333FF",
    "#33FF83", "#FF3383", "#3383FF", "#83FF33",
)

class SmartSuggestionsService {
    fun suggestions(
        sessions: List<CountSession>,
        limit: Int = 5,
        excludingNames: Set<String> = emptySet(),
    ): List<ObjectTypeSuggestion> {
        val frequencyMap = mutableMapOf<String, Int>()
        val typeMap = mutableMapOf<String, ObjectType>()

        for (session in sessions) {
            for (type in session.objectTypes) {
                if (type.name in excludingNames) continue
                frequencyMap[type.name] = (frequencyMap[type.name] ?: 0) + 1
                typeMap.putIfAbsent(type.name, type)
            }
        }

        return frequencyMap.entries
            .sortedByDescending { it.value }
            .take(limit)
            .map { (name, freq) ->
                val ot = typeMap[name]
                ObjectTypeSuggestion(
                    name = name,
                    colorHex = ot?.colorHex ?: colorPalette[0],
                    iconName = ot?.iconName ?: iconCategories[0],
                    frequency = freq,
                )
            }
    }

    fun generateDefaultTypes(): List<ObjectType> {
        return listOf(
            ObjectType.create("Cars", colorHex = "#FF5733"),
            ObjectType.create("People", colorHex = "#33FF57"),
            ObjectType.create("Trees", colorHex = "#3357FF"),
            ObjectType.create("Animals", colorHex = "#FF33F5"),
        )
    }
}
