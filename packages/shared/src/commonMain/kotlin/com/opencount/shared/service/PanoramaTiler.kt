package com.opencount.shared.service

import com.opencount.shared.model.AIDetection
import com.opencount.shared.model.NormalizedPoint
import com.opencount.shared.model.NormalizedRect
import kotlin.math.*

/**
 * Describes a single tile within a larger panorama image.
 * Stores tile grid position and normalized dimensions/offsets relative to the full image.
 */
data class TileDescriptor(
    val tileX: Int,
    val tileY: Int,
    val tileWidth: Double,
    val tileHeight: Double,
    val offsetX: Double,
    val offsetY: Double,
) {
    /**
     * Converts a normalized point from tile-local coordinates to full-image normalized coordinates.
     * Useful for mapping detection results from a tile back to the original image.
     */
    fun toFullImageNormalized(point: NormalizedPoint): NormalizedPoint {
        return NormalizedPoint(
            x = point.x * tileWidth + offsetX,
            y = point.y * tileHeight + offsetY,
        )
    }

    /**
     * Converts a normalized rect from tile-local coordinates to full-image normalized coordinates.
     * Useful for mapping detection bounding boxes from a tile back to the original image.
     */
    fun toFullImageNormalized(rect: NormalizedRect): NormalizedRect {
        return NormalizedRect(
            x = rect.x * tileWidth + offsetX,
            y = rect.y * tileHeight + offsetY,
            width = rect.width * tileWidth,
            height = rect.height * tileHeight,
        )
    }
}

/**
 * Service for splitting large images (panoramas) into overlapping tiles suitable for AI inference.
 * Reconstructs tile-local detections back to full-image coordinates and deduplicates via NMS.
 */
object PanoramaTiler {
    private const val MAX_DIMENSION = 4096
    private const val TILE_SIZE = 1280
    private const val OVERLAP = 0.2

    /** Returns true if the given image dimensions exceed the maximum allowed size and require tiling. */
    fun requiresTiling(width: Double, height: Double): Boolean {
        return width > MAX_DIMENSION || height > MAX_DIMENSION
    }

    /**
     * Splits an image of the given dimensions into a grid of overlapping [TileDescriptor]s.
     * If the image is small enough, returns a single tile covering the full image.
     * @param imageWidth width of the full image in pixels
     * @param imageHeight height of the full image in pixels
     * @return list of tile descriptors with normalized positions and sizes
     */
    fun tile(imageWidth: Double, imageHeight: Double): List<TileDescriptor> {
        if (!requiresTiling(imageWidth, imageHeight)) {
            return listOf(TileDescriptor(
                tileX = 0, tileY = 0,
                tileWidth = 1.0, tileHeight = 1.0,
                offsetX = 0.0, offsetY = 0.0,
            ))
        }

        val tiles = mutableListOf<TileDescriptor>()
        val cols = ceil(imageWidth / TILE_SIZE).toInt()
        val rows = ceil(imageHeight / TILE_SIZE).toInt()
        val stepX = imageWidth / cols
        val stepY = imageHeight / rows

        for (row in 0 until rows) {
            for (col in 0 until cols) {
                val offsetX = col * stepX
                val offsetY = row * stepY
                val tw = min(stepX * (1.0 + OVERLAP), imageWidth - offsetX)
                val th = min(stepY * (1.0 + OVERLAP), imageHeight - offsetY)
                tiles.add(TileDescriptor(
                    tileX = col, tileY = row,
                    tileWidth = tw / imageWidth,
                    tileHeight = th / imageHeight,
                    offsetX = offsetX / imageWidth,
                    offsetY = offsetY / imageHeight,
                ))
            }
        }
        return tiles
    }

    /**
     * Delegates to [NMS.nonMaximumSuppression] to deduplicate overlapping detections
     * after mapping tile-local results back to full-image coordinates.
     */
    fun nonMaximumSuppression(
        detections: List<AIDetection>,
        iouThreshold: Float = 0.5f,
    ): List<AIDetection> = NMS.nonMaximumSuppression(detections, iouThreshold)
}
