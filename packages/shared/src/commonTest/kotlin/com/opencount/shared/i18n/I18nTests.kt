package com.opencount.shared.i18n

import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertTrue

class I18nTests {
    @Test
    fun testEnglishDefaults() {
        Strings.language = "en"
        assertEquals("OpenCount", Strings.appName)
        assertEquals("Add Marker", Strings.addMarker)
        assertEquals("Sessions", Strings.sessions)
        assertEquals("Export", Strings.export)
    }

    @Test
    fun testVietnamese() {
        Strings.language = "vi"
        assertEquals("Thêm điểm", Strings.addMarker)
        assertEquals("Danh sách phiên", Strings.sessions)
        assertEquals("Cài đặt", Strings.settings)
    }

    @Test
    fun testJapanese() {
        Strings.language = "ja"
        assertEquals("マーカー追加", Strings.addMarker)
        assertEquals("合計", Strings.totalCount)
    }

    @Test
    fun testKorean() {
        Strings.language = "ko"
        assertEquals("마커 추가", Strings.addMarker)
        assertEquals("설정", Strings.settings)
    }

    @Test
    fun testChinese() {
        Strings.language = "zh"
        assertEquals("添加标记", Strings.addMarker)
        assertEquals("导出", Strings.export)
    }

    @Test
    fun testFallbackToEnglish() {
        Strings.language = "unknown"
        assertEquals("OpenCount", Strings.appName)
    }

    @Test
    fun testAllLanguagesHaveKeys() {
        val languages = listOf("en", "vi", "ja", "ko", "zh", "fr", "de", "es")
        val testKeys = listOf(
            "app.name" to { Strings.appName },
            "session.new" to { Strings.newSession },
            "export.title" to { Strings.export },
            "settings.title" to { Strings.settings },
            "counting.total" to { Strings.totalCount },
        )
        for (lang in languages) {
            Strings.language = lang
            for ((_, accessor) in testKeys) {
                assertTrue(accessor().isNotEmpty(), "Missing key for language: $lang")
            }
        }
    }
}
