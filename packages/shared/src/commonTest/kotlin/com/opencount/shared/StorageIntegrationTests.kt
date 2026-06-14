package com.opencount.shared

import com.opencount.shared.model.CountMarker
import com.opencount.shared.model.CountSession
import com.opencount.shared.model.ObjectType
import com.opencount.shared.service.StorageService
import kotlin.test.Test
import kotlin.test.*

class StorageIntegrationTests {
    @Test
    fun `save and load session`() {
        val fake = FakePlatformStorage()
        val storage = StorageService(fake)
        val session = CountSession.create("Test 1")

        storage.save(session)
        assertTrue(storage.exists(session.id))

        val loaded = storage.load(session.id)
        assertNotNull(loaded)
        assertEquals(session.name, loaded.name)
    }

    @Test
    fun `save and load multiple sessions`() {
        val fake = FakePlatformStorage()
        val storage = StorageService(fake)

        val s1 = CountSession.create("Session 1")
        val s2 = CountSession.create("Session 2")
        storage.save(s1)
        storage.save(s2)

        assertEquals(2, storage.loadAll().size)
    }

    @Test
    fun `delete session`() {
        val fake = FakePlatformStorage()
        val storage = StorageService(fake)
        val session = CountSession.create("To Delete")

        storage.save(session)
        assertTrue(storage.exists(session.id))

        storage.delete(session.id)
        assertFalse(storage.exists(session.id))
        assertEquals(0, storage.loadAll().size)
    }

    @Test
    fun `save overwrites existing`() {
        val fake = FakePlatformStorage()
        val storage = StorageService(fake)
        val session = CountSession.create("Original")

        storage.save(session)
        val updated = session.copy(name = "Updated")
        storage.save(updated)

        val loaded = storage.load(session.id)
        assertNotNull(loaded)
        assertEquals("Updated", loaded.name)
    }

    @Test
    fun `load non-existent returns null`() {
        val fake = FakePlatformStorage()
        val storage = StorageService(fake)

        assertNull(storage.load("non-existent"))
        assertFalse(storage.exists("non-existent"))
    }

    @Test
    fun `json serialization round trip`() {
        val fake = FakePlatformStorage()
        val storage = StorageService(fake)
        val typeA = ObjectType.create("Cars")
        val session = CountSession.create("JSON Test").copy(
            objectTypes = listOf(typeA),
            markers = listOf(CountMarker.create(0.5, 0.5, typeA.id)),
        )

        val json = storage.toJson(session)
        assertTrue(json.contains("JSON Test"))

        val restored = storage.fromJson(json)
        assertEquals(session.name, restored.name)
        assertEquals(session.markers.size, restored.markers.size)
    }

    @Test
    fun `fake platform tracks operations`() {
        val fake = FakePlatformStorage()
        val storage = StorageService(fake)

        assertEquals(0, fake.count)

        val s1 = CountSession.create("A")
        val s2 = CountSession.create("B")
        storage.save(s1)
        storage.save(s2)
        assertEquals(2, fake.count)

        storage.delete(s1.id)
        assertEquals(1, fake.count)
    }

    @Test
    fun `empty storage returns empty list`() {
        val fake = FakePlatformStorage()
        val storage = StorageService(fake)

        assertTrue(storage.loadAll().isEmpty())
    }

    @Test
    fun `bulk operations with many sessions`() {
        val fake = FakePlatformStorage()
        val storage = StorageService(fake)

        val sessions = (1..50).map { i ->
            CountSession.create("Session $i").also { storage.save(it) }
        }

        assertEquals(50, storage.loadAll().size)

        // Delete every other session
        sessions.filterIndexed { i, _ -> i % 2 == 0 }.forEach { storage.delete(it.id) }

        assertEquals(25, storage.loadAll().size)
    }
}
