package com.opencount.shared

import com.opencount.shared.service.SampleSessionSeeder
import com.opencount.shared.util.Counter
import kotlin.test.Test
import kotlin.test.*

class SampleSessionSeederTests {
    @Test
    fun testCreateSampleSession() {
        val session = SampleSessionSeeder.createSampleSession()
        assertEquals("Sample Count", session.name)
        assertEquals(3, session.objectTypes.size)
        assertEquals(6, Counter.totalCount(session))
        assertEquals(1, session.regions.size)
        assertNotNull(session.sessionDescription)
    }

    @Test
    fun testSampleObjectTypes() {
        val session = SampleSessionSeeder.createSampleSession()
        val names = session.objectTypes.map { it.name }
        assertTrue(names.contains("Cars"))
        assertTrue(names.contains("People"))
        assertTrue(names.contains("Trees"))
    }

    @Test
    fun testSampleMarkersExist() {
        val session = SampleSessionSeeder.createSampleSession()
        assertEquals(6, session.markers.size)
        val (manual, ai) = Counter.countByAIDerived(session)
        assertEquals(6, manual)
        assertEquals(0, ai)
    }

    @Test
    fun testSampleHasRegion() {
        val session = SampleSessionSeeder.createSampleSession()
        assertEquals("Parking Lot", session.regions[0].name)
    }

    @Test
    fun testSampleJSON() {
        val json = SampleSessionSeeder.sampleJSON()
        assertTrue(json.contains("Sample Count"))
        assertTrue(json.contains("Cars"))
        assertTrue(json.contains("Parking Lot"))
    }

    @Test
    fun testSeedAndReload() {
        val fake = FakePlatformStorage()
        val storage = com.opencount.shared.service.StorageService(fake)
        SampleSessionSeeder.seedIfNeeded(storage)
        val sessions = storage.loadAll()
        assertEquals(1, sessions.size)
        assertEquals("Sample Count", sessions[0].name)
    }
}
