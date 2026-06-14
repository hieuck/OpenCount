package com.opencount.shared

import com.opencount.shared.model.*
import com.opencount.shared.service.*
import kotlin.test.Test
import kotlin.test.*

class PlatformModelTests {
    @Test
    fun testSessionImageDefaults() {
        val img = SessionImage.create(filename = "test.jpg")
        assertEquals("test.jpg", img.filename)
        assertNull(img.thumbnailFilename)
        assertNull(img.optimizedFilename)
    }

    @Test
    fun testSessionImageWithThumbnail() {
        val img = SessionImage.create("test.jpg", thumbnailFilename = "thumb.jpg")
        assertEquals("thumb.jpg", img.thumbnailFilename)
    }

    @Test
    fun testVideoFrameCountEmpty() {
        val frame = VideoFrameCount(id = "v1", timestampSeconds = 0.0)
        assertTrue(frame.markerIds.isEmpty())
    }

    @Test
    fun testObjectTypeWithTarget() {
        val type = ObjectType.create("Count", targetCount = 100)
        assertEquals(100, type.targetCount)
    }

    @Test
    fun testObjectTypeWithoutTarget() {
        val type = ObjectType.create("Count")
        assertNull(type.targetCount)
    }

    @Test
    fun testNormalizedRectEquality() {
        val a = NormalizedRect(0.1, 0.2, 0.3, 0.4)
        val b = NormalizedRect(0.1, 0.2, 0.3, 0.4)
        assertEquals(a, b)
    }

    @Test
    fun testNormalizedRectZeroSize() {
        val r = NormalizedRect(0.0, 0.0, 0.0, 0.0)
        assertEquals(0.0, r.midX)
        assertEquals(0.0, r.midY)
    }

    @Test
    fun testCountFormulaDefaults() {
        val f = CountFormula(id = "f1", name = "Test", expression = "1+1")
        assertEquals("", f.unit)
        assertEquals(0, f.sortOrder)
    }

    @Test
    fun testSerializationRoundTripCountMarker() {
        val marker = CountMarker.create(0.5, 0.5, "type-1")
        val json = kotlinx.serialization.json.Json { prettyPrint = true }
        val encoded = json.encodeToString(CountMarker.serializer(), marker)
        val decoded = json.decodeFromString(CountMarker.serializer(), encoded)
        assertEquals(marker.id, decoded.id)
        assertEquals(marker.normalizedX, decoded.normalizedX)
        assertEquals(marker.objectTypeId, decoded.objectTypeId)
    }

    @Test
    fun testSerializationRoundTripObjectType() {
        val type = ObjectType.create("Test", colorHex = "#AABBCC")
        val json = kotlinx.serialization.json.Json { prettyPrint = true }
        val encoded = json.encodeToString(ObjectType.serializer(), type)
        val decoded = json.decodeFromString(ObjectType.serializer(), encoded)
        assertEquals(type.name, decoded.name)
        assertEquals(type.colorHex, decoded.colorHex)
    }

    @Test
    fun testNativeFileStorageDesktop() {
        val storage = NativeFileStorage()
        storage.write("test.txt", "hello")
        assertEquals("hello", storage.read("test.txt"))
        storage.delete("test.txt")
        assertNull(storage.read("test.txt"))
    }

    @Test
    fun testSessionExportDTOConversion() {
        val type = ObjectType.create("Cars")
        val marker = CountMarker.create(0.5, 0.5, type.id)
        val session = CountSession.create("DTO Test").copy(
            objectTypes = listOf(type),
            markers = listOf(marker),
        )
        val dto = SessionExportDTO(session)
        assertEquals(session.name, dto.name)
        assertEquals(session.markers.size, dto.markers.size)
        assertEquals(1, dto.objectTypeNames.size)
        assertTrue(dto.objectTypeNames.containsValue("Cars"))
    }

    @Test
    fun testMarkerDTOConversion() {
        val marker = CountMarker.create(0.5, 0.5, "type-1")
        val dto = MarkerDTO(marker)
        assertEquals(marker.id, dto.id)
        assertEquals(marker.normalizedX, dto.normalizedX)
        assertEquals(marker.objectTypeId, dto.objectTypeId)
    }

    @Test
    fun testSampleSessionJSON() {
        val json = SampleSessionSeeder.sampleJSON()
        assertTrue(json.isNotBlank())
        assertTrue(json.contains("\"name\""))
    }
}
