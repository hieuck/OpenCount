package com.opencount.shared.model

import kotlinx.serialization.Serializable

@Serializable
data class ObjectType(
    val id: String,
    val name: String,
    val colorHex: String = "#FF5733",
    val iconName: String = "circle.fill",
    val sortOrder: Int = 0,
    val targetCount: Int? = null,
) {
    companion object {
        fun create(
            name: String,
            colorHex: String = "#FF5733",
            iconName: String = "circle.fill",
            targetCount: Int? = null,
        ): ObjectType = ObjectType(
            id = uuid(),
            name = name,
            colorHex = colorHex,
            iconName = iconName,
            targetCount = targetCount,
        )
    }
}
