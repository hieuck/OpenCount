package com.opencount.shared.service

import com.opencount.shared.i18n.Strings
import com.opencount.shared.model.CountSession
import com.opencount.shared.util.Counter
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json

enum class ExportFormat {
    CSV,
    JSON,
}

class ExportService {
    private val json = Json { prettyPrint = true }

    fun exportToJson(session: CountSession): String = json.encodeToString(session)

    fun exportToJson(sessions: List<CountSession>): String = json.encodeToString(sessions)

    fun exportToCsv(session: CountSession): String {
        val tally = Counter.tallyByType(session)
        val sb = StringBuilder()
        sb.appendLine("${Strings.categoryName},${Strings.totalCount}")
        for ((typeName, count) in tally.entries.sortedBy { it.key }) {
            sb.appendLine("$typeName,$count")
        }
        return sb.toString()
    }

    fun exportToCsv(sessions: List<CountSession>): String {
        val sb = StringBuilder()
        sb.appendLine("${Strings.sessions},${Strings.categoryName},${Strings.totalCount}")
        for (session in sessions) {
            val tally = Counter.tallyByType(session)
            for ((typeName, count) in tally.entries.sortedBy { it.key }) {
                sb.appendLine("${session.name},$typeName,$count")
            }
        }
        return sb.toString()
    }
}
