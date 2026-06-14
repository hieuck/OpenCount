package com.opencount.shared

import com.opencount.shared.model.CountMarker
import com.opencount.shared.model.CountSession
import com.opencount.shared.model.ObjectType
import com.opencount.shared.service.CrashRecoveryService
import com.opencount.shared.service.FileStorage
import kotlin.test.Test
import kotlin.test.assertNotNull
import kotlin.test.assertEquals
import kotlin.test.assertNull
import kotlin.test.assertTrue

class FakeFileStorage : FileStorage {
    private val files = mutableMapOf<String, String>()
    override fun write(filename: String, data: String) { files[filename] = data }
    override fun read(filename: String): String? = files[filename]
    override fun delete(filename: String) { files.remove(filename) }
}

class CrashRecoveryTests {
    @Test
    fun testSaveAndLoadRecovery() {
        val fileStorage = FakeFileStorage()
        val typeA = ObjectType.create("Cars")
        val session = CountSession.create("Recovery Test").copy(
            objectTypes = listOf(typeA),
            markers = listOf(CountMarker.create(0.5, 0.5, typeA.id)),
        )

        CrashRecoveryService.saveRecovery(session, fileStorage)
        val loaded = CrashRecoveryService.loadRecovery(fileStorage)
        assertNotNull(loaded)
        assertEquals(session.name, loaded.name)
        assertEquals(session.markers.size, loaded.markers.size)
    }

    @Test
    fun testLoadNonExistent() {
        val fileStorage = FakeFileStorage()
        assertNull(CrashRecoveryService.loadRecovery(fileStorage))
    }

    @Test
    fun testClearRecovery() {
        val fileStorage = FakeFileStorage()
        val session = CountSession.create("Clear Test")
        CrashRecoveryService.saveRecovery(session, fileStorage)
        assertNotNull(CrashRecoveryService.loadRecovery(fileStorage))

        CrashRecoveryService.clearRecovery(fileStorage)
        assertNull(CrashRecoveryService.loadRecovery(fileStorage))
    }

    @Test
    fun testSaveOverwritesPrevious() {
        val fileStorage = FakeFileStorage()
        CrashRecoveryService.saveRecovery(CountSession.create("Version 1"), fileStorage)
        CrashRecoveryService.saveRecovery(CountSession.create("Version 2"), fileStorage)

        val loaded = CrashRecoveryService.loadRecovery(fileStorage)
        assertNotNull(loaded)
        assertEquals("Version 2", loaded.name)
    }

    @Test
    fun testSessionExportDTORoundTrip() {
        val fileStorage = FakeFileStorage()
        val typeA = ObjectType.create("Cars")
        val typeB = ObjectType.create("Trucks")
        val session = CountSession.create("Export DTO Test").copy(
            objectTypes = listOf(typeA, typeB),
            markers = listOf(
                CountMarker.create(0.1, 0.2, typeA.id),
                CountMarker.create(0.3, 0.4, typeB.id),
            ),
        )

        CrashRecoveryService.saveRecovery(session, fileStorage)
        val loaded = CrashRecoveryService.loadRecovery(fileStorage)
        assertNotNull(loaded)
        assertEquals(2, loaded.markers.size)
        assertEquals(2, loaded.objectTypeNames.size)
        assertTrue(loaded.objectTypeNames.containsValue("Cars"))
    }
}
