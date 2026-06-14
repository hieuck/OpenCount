package com.opencount.shared.service

import com.opencount.shared.i18n.Strings
import com.opencount.shared.model.CountSession
import com.opencount.shared.util.Counter
import kotlinx.serialization.Serializable
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json

/** Supported export formats for session data. */
enum class ExportFormat {
    CSV,
    JSON,
    COCO,
}

/** Metadata info block for COCO JSON export. */
@Serializable
data class COCOInfo(val description: String, val version: String = "1.0")

/** A category entry in COCO format, mapping an object type to an integer ID. */
@Serializable
data class COCOCategory(val id: Int, val name: String, val supercategory: String = "object")

/** An annotation entry in COCO format, representing a single marker as a bounding box. */
@Serializable
data class COCOAnnotation(
    val id: Int,
    val image_id: Int,
    val category_id: Int,
    val bbox: List<Double>,
    val area: Double,
    val iscrowd: Int = 0,
)

/** An image entry in COCO format, referencing the source image. */
@Serializable
data class COCOImage(val id: Int, val file_name: String, val width: Int, val height: Int)

/** Top-level COCO dataset container with info, images, annotations, and categories. */
@Serializable
data class COCODataset(
    val info: COCOInfo,
    val images: List<COCOImage>,
    val annotations: List<COCOAnnotation>,
    val categories: List<COCOCategory>,
)

/**
 * Service for exporting counting session data in various formats (JSON, CSV, COCO).
 * All export methods transform in-memory [CountSession] objects to string representations.
 */
class ExportService {
    private val json = Json { prettyPrint = true }

    /** Exports a single [session] as a pretty-printed JSON string. */
    fun exportToJson(session: CountSession): String = json.encodeToString(session)

    /** Exports a list of [sessions] as a pretty-printed JSON array string. */
    fun exportToJson(sessions: List<CountSession>): String = json.encodeToString(sessions)

    /**
     * Exports a single [session] as a CSV string with category names and total counts per row.
     * Uses localized headers from [Strings].
     */
    fun exportToCsv(session: CountSession): String {
        val tally = Counter.tallyByType(session)
        val sb = StringBuilder()
        sb.appendLine("${Strings.categoryName},${Strings.totalCount}")
        for ((typeName, count) in tally.entries.sortedBy { it.key }) {
            sb.appendLine("\"$typeName\",$count")
        }
        return sb.toString()
    }

    /**
     * Exports multiple [sessions] as a CSV string with session name, category name, and count per row.
     * Useful for cross-session reporting.
     */
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

    /**
     * Exports a session to COCO JSON format, mapping markers to bounding box annotations.
     * Uses placeholder image dimensions (1920x1080) when no image is available.
     */
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

    /**
     * Generates a human-readable plain-text summary of a session with total count
     * and per-category tallies sorted by count descending.
     */
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
