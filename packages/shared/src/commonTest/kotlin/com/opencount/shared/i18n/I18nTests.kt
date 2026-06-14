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
    fun testFrench() {
        Strings.language = "fr"
        assertEquals("Ajouter un marqueur", Strings.addMarker)
        assertEquals("Paramètres", Strings.settings)
        assertEquals("Tout effacer", Strings.clearAll)
    }

    @Test
    fun testGerman() {
        Strings.language = "de"
        assertEquals("Marker hinzufügen", Strings.addMarker)
        assertEquals("Einstellungen", Strings.settings)
        assertEquals("Stapelexport", Strings.bulkExport)
    }

    @Test
    fun testSpanish() {
        Strings.language = "es"
        assertEquals("Agregar marcador", Strings.addMarker)
        assertEquals("Configuración", Strings.settings)
        assertEquals("Exportación masiva", Strings.bulkExport)
    }

    @Test
    fun testFallbackToEnglish() {
        Strings.language = "unknown"
        assertEquals("OpenCount", Strings.appName)
    }

    @Test
    fun testAllLanguagesHaveKeySets() {
        val languages = listOf("en", "vi", "ja", "ko", "zh", "fr", "de", "es")
        val keyProviders = listOf(
            { Strings.appName }, { Strings.addMarker }, { Strings.removeMarker },
            { Strings.totalCount }, { Strings.aiDetect }, { Strings.voiceCount },
            { Strings.sessions }, { Strings.newSession }, { Strings.deleteSession },
            { Strings.export }, { Strings.exportCSV }, { Strings.exportJSON },
            { Strings.settings }, { Strings.languageLabel }, { Strings.about },
            { Strings.addCategory }, { Strings.categoryName },
            { Strings.addRegion }, { Strings.regionName },
            { Strings.aiProcessing }, { Strings.aiConfidence },
            { Strings.errorGeneric }, { Strings.errorSave }, { Strings.errorExport },
        )
        for (lang in languages) {
            Strings.language = lang
            for (provider in keyProviders) {
                assertTrue(provider().isNotEmpty(), "Empty string for language: $lang")
            }
        }
    }
}
