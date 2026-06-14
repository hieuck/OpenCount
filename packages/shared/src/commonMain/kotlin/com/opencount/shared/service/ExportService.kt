package com.opencount.shared.service

import com.opencount.shared.i18n.Strings
import com.opencount.shared.model.CountSession
import com.opencount.shared.util.Counter
import kotlinx.serialization.Serializable
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json

enum class ExportFormat {
    CSV,
    JSON,
    COCO,
}

@Serializable
data class COCOInfo(val description: String, val version: String = "1.0")

@Serializable
data class COCOCategory(val id: Int, val name: String, val supercategory: String = "object")

@Serializable
data class COCOAnnotation(
    val id: Int,
    val image_id: Int,
    val category_id: Int,
    val bbox: List<Double>,
    val area: Double,
    val iscrowd: Int = 0,
)

@Serializable
data class COCOImage(val id: Int, val file_name: String, val width: Int, val height: Int)

@Serializable
data class COCODataset(
    val info: COCOInfo,
    val images: List<COCOImage>,
    val annotations: List<COCOAnnotation>,
    val categories: List<COCOCategory>,
)

class ExportService {
    private val json = Json { prettyPrint = true }

    fun exportToJson(session: CountSession): String = json.encodeToString(session)

    fun exportToJson(sessions: List<CountSession>): String = json.encodeToString(sessions)

    fun exportToCsv(session: CountSession): String {
        val tally = Counter.tallyByType(session)
        val sb = StringBuilder()
        sb.appendLine("${Strings.categoryName},${Strings.totalCount}")
        for ((typeName, count) in tally.entries.sortedBy { it.key }) {
            sb.appendLine("\"$typeName\",$count")
        }
        return sb.toString()
    }

    fun exportToCsv(sessions: List<CountSession>): String {
        val sb = StringBuilder()
        sb.appendLine("${Strings.sessions},${Strings.categoryName},${Strings.totalCount}")
        for (session in sessions) {
            val tally = Counter.tallyByType(session)
            for ((typeName, count) in tally.entries.sortedBy { it.key }) {
                sb.appendLine("\"${session.name}\",\"$typeName\",$count")
            }
        }
        return sb.toString()
    }

    fun exportToCoco(session: CountSession): String {
        val categories = session.objectTypes.mapIndexed { i, ot ->
            COCOCategory(id = i + 1, name = ot.name)
        }
        val typeToId = categories.associate { it.name to it.id }
        val annotations = session.markers.mapIndexed { i, marker ->
            val typeName = session.objectTypes.find { it.id == marker.objectTypeId }?.name ?: "Unknown"
            val catId = typeToId[typeName] ?: 0
            COCOAnnotation(
                id = i + 1,
                image_id = 1,
                category_id = catId,
                bbox = listOf(
                    (marker.normalizedX - 0.02).coerceAtLeast(0.0),
                    (marker.normalizedY - 0.02).coerceAtLeast(0.0),
                    0.04, 0.04,
                ),
                area = 0.0016,
            )
        }
        val dataset = COCODataset(
            info = COCOInfo(description = session.name),
            images = listOf(COCOImage(id = 1, file_name = session.images.firstOrNull()?.filename ?: "unknown", width = 1920, height = 1080)),
            annotations = annotations,
            categories = categories,
        )
        return json.encodeToString(dataset)
    }

    fun plainTextSummary(session: CountSession): String {
        val tally = Counter.tallyByType(session)
        val sb = StringBuilder()
        sb.appendLine("=== ${session.name} ===")
        sb.appendLine("${Strings.totalCount}: ${Counter.totalCount(session)}")
        for ((typeName, count) in tally.entries.sortedByDescending { it.value }) {
            sb.appendLine("  $typeName: $count")
        }
        return sb.toString()
    }
}
