package com.opencount.shared

import com.opencount.shared.model.AIDetection
import com.opencount.shared.model.NormalizedRect
import com.opencount.shared.service.PanoramaTiler
import com.opencount.shared.service.TileDescriptor
import kotlin.test.Test
import kotlin.test.*

class PanoramaTilerTests {
    @Test
    fun testNoTilingForSmallImage() {
        assertFalse(PanoramaTiler.requiresTiling(1000.0, 800.0))
    }

    @Test
    fun testTilingForLargeImage() {
        assertTrue(PanoramaTiler.requiresTiling(5000.0, 4000.0))
    }

    @Test
    fun testSingleTileForSmallImage() {
        val tiles = PanoramaTiler.tile(1000.0, 800.0)
        assertEquals(1, tiles.size)
        assertEquals(0, tiles[0].tileX)
        assertEquals(0, tiles[0].tileY)
    }

    @Test
    fun testMultipleTilesForLargeImage() {
        val tiles = PanoramaTiler.tile(5000.0, 4000.0)
        assertTrue(tiles.size > 1)
    }

    @Test
    fun testTileCoordinateTransform() {
        val tile = TileDescriptor(
            tileX = 0, tileY = 0,
            tileWidth = 0.5, tileHeight = 0.5,
            offsetX = 0.0, offsetY = 0.0,
        )
        val fullPoint = tile.toFullImageNormalized(
            com.opencount.shared.model.NormalizedPoint(0.5, 0.5)
        )
        assertEquals(0.25, fullPoint.x)
        assertEquals(0.25, fullPoint.y)
    }

    @Test
    fun testTileRectTransform() {
        val tile = TileDescriptor(
            tileX = 0, tileY = 0,
            tileWidth = 0.5, tileHeight = 0.5,
            offsetX = 0.5, offsetY = 0.5,
        )
        val fullRect = tile.toFullImageNormalized(
            NormalizedRect(0.0, 0.0, 0.5, 0.5)
        )
        assertEquals(0.5, fullRect.x)
        assertEquals(0.5, fullRect.y)
        assertEquals(0.25, fullRect.width)
        assertEquals(0.25, fullRect.height)
    }

    @Test
    fun testNMSDelegation() {
        val detections = listOf(
            AIDetection("1", NormalizedRect(0.0, 0.0, 0.5, 0.5), "a", 0.9f),
            AIDetection("2", NormalizedRect(0.1, 0.1, 0.5, 0.5), "b", 0.5f),
        )
        val result = PanoramaTiler.nonMaximumSuppression(detections, iouThreshold = 0.3f)
        assertEquals(1, result.size)
    }

    @Test
    fun testTilingForVeryWideImage() {
        val tiles = PanoramaTiler.tile(8000.0, 1000.0)
        assertTrue(tiles.isNotEmpty())
    }

    @Test
    fun testTilingForVeryTallImage() {
        val tiles = PanoramaTiler.tile(1000.0, 8000.0)
        assertTrue(tiles.isNotEmpty())
    }
}
