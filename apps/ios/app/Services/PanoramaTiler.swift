import Foundation
import UIKit
import CoreGraphics

// MARK: - TileDescriptor

/// Describes a single tile extracted from a large image.
/// Stores the tile's position in the original image in normalized coordinates
/// so that detections can be mapped back to the full image coordinate space.
struct TileDescriptor {
    /// The tile image (1280×1280 or smaller at edges).
    let image: UIImage
    /// The tile's origin in the full image, in pixels.
    let pixelOrigin: CGPoint
    /// The full image size in pixels.
    let fullImageSize: CGSize

    /// Converts a normalized coordinate within this tile to a normalized
    /// coordinate within the full image.
    func toFullImageNormalized(_ point: CGPoint) -> CGPoint {
        let pixelX = pixelOrigin.x + point.x * image.size.width
        let pixelY = pixelOrigin.y + point.y * image.size.height
        return CGPoint(
            x: pixelX / fullImageSize.width,
            y: pixelY / fullImageSize.height
        )
    }

    /// Converts a normalized bounding box within this tile to a normalized
    /// bounding box within the full image.
    func toFullImageNormalized(_ rect: CGRect) -> CGRect {
        let origin = toFullImageNormalized(CGPoint(x: rect.minX, y: rect.minY))
        let corner = toFullImageNormalized(CGPoint(x: rect.maxX, y: rect.maxY))
        return CGRect(x: origin.x, y: origin.y,
                      width: corner.x - origin.x,
                      height: corner.y - origin.y)
    }
}

// MARK: - PanoramaTiler

/// Splits large images (>4096×4096) into overlapping 1280×1280 tiles for AI inference,
/// then deduplicates detections across tile boundaries using Non-Maximum Suppression.
///
/// Requirements: 25.1, 25.2, 25.5
final class PanoramaTiler {

    // MARK: - Constants

    /// Tile size in pixels.
    static let tileSize: CGFloat = 1280
    /// Overlap fraction between adjacent tiles (20%).
    static let overlapFraction: CGFloat = 0.20
    /// Stride between tile origins = tileSize * (1 - overlap).
    static let tileStride: CGFloat = tileSize * (1.0 - overlapFraction)
    /// Images larger than this threshold in either dimension are tiled.
    static let tilingThreshold: CGFloat = 4096
    /// IoU threshold for NMS deduplication across tile boundaries.
    static let nmsIoUThreshold: Float = 0.5

    // MARK: - Tiling

    /// Returns whether the given image requires tiling.
    static func requiresTiling(_ image: UIImage) -> Bool {
        image.size.width > tilingThreshold || image.size.height > tilingThreshold
    }

    /// Splits `image` into overlapping 1280×1280 tiles with 20% overlap.
    /// If the image is ≤4096×4096, returns a single tile covering the whole image.
    ///
    /// - Parameter image: The source image (may be up to 16384×16384).
    /// - Returns: Array of `TileDescriptor` values covering the full image.
    static func tile(image: UIImage) -> [TileDescriptor] {
        guard let cgImage = image.cgImage else { return [] }

        let fullWidth = image.size.width
        let fullHeight = image.size.height

        // If the image is small enough, return it as a single tile.
        guard requiresTiling(image) else {
            return [TileDescriptor(image: image,
                                   pixelOrigin: .zero,
                                   fullImageSize: image.size)]
        }

        var tiles: [TileDescriptor] = []

        var y: CGFloat = 0
        while y < fullHeight {
            var x: CGFloat = 0
            while x < fullWidth {
                // Clamp tile to image bounds.
                let tileW = min(tileSize, fullWidth - x)
                let tileH = min(tileSize, fullHeight - y)

                let cropRect = CGRect(x: x, y: y, width: tileW, height: tileH)

                if let croppedCG = cgImage.cropping(to: cropRect) {
                    let tileImage = UIImage(cgImage: croppedCG,
                                           scale: image.scale,
                                           orientation: image.imageOrientation)
                    tiles.append(TileDescriptor(
                        image: tileImage,
                        pixelOrigin: CGPoint(x: x, y: y),
                        fullImageSize: image.size
                    ))
                }

                x += tileStride
                if x >= fullWidth { break }
            }
            y += tileStride
            if y >= fullHeight { break }
        }

        return tiles
    }

    // MARK: - AI Inference on Tiles

    /// Runs AI inference on each tile of `image`, maps detections back to full-image
    /// normalized coordinates, and applies NMS to deduplicate overlapping detections
    /// across tile boundaries.
    ///
    /// - Parameters:
    ///   - image: The full panorama/mosaic image.
    ///   - aiService: The AI service to use for per-tile inference.
    ///   - confidenceThreshold: Minimum confidence for returned detections.
    ///   - progressHandler: Called with progress in [0, 1] after each tile completes.
    /// - Returns: Deduplicated `[AIDetection]` in full-image normalized coordinates.
    ///
    /// Requirements: 25.2, 25.5
    static func runAIOnTiles(
        image: UIImage,
        aiService: AIServiceProtocol,
        confidenceThreshold: Float,
        progressHandler: ((Double) -> Void)? = nil
    ) async throws -> [AIDetection] {

        let tiles = tile(image: image)
        guard !tiles.isEmpty else { return [] }

        var allDetections: [AIDetection] = []
        let total = Double(tiles.count)

        for (index, tileDesc) in tiles.enumerated() {
            let tileDetections = try await aiService.detect(
                in: tileDesc.image,
                confidenceThreshold: confidenceThreshold
            )

            // Map each detection's bounding box from tile-local to full-image coordinates.
            let mapped = tileDetections.map { detection -> AIDetection in
                let fullBox = tileDesc.toFullImageNormalized(detection.normalizedBoundingBox)
                return AIDetection(
                    id: detection.id,
                    normalizedBoundingBox: fullBox,
                    label: detection.label,
                    confidenceScore: detection.confidenceScore,
                    isAccepted: detection.isAccepted
                )
            }

            allDetections.append(contentsOf: mapped)
            progressHandler?(Double(index + 1) / total)
        }

        // Deduplicate detections that overlap across tile boundaries.
        return nonMaximumSuppression(detections: allDetections, iouThreshold: nmsIoUThreshold)
    }

    // MARK: - Non-Maximum Suppression

    /// Applies class-aware Non-Maximum Suppression to remove duplicate detections.
    ///
    /// Algorithm:
    /// 1. Sort detections by confidence score descending.
    /// 2. Greedily keep the highest-confidence detection.
    /// 3. Suppress any remaining detection of the same class whose IoU with the
    ///    kept detection exceeds `iouThreshold`.
    ///
    /// - Parameters:
    ///   - detections: Input detections in full-image normalized coordinates.
    ///   - iouThreshold: IoU threshold above which a detection is suppressed (default 0.5).
    /// - Returns: Filtered detections with duplicates removed.
    ///
    /// Requirements: 25.2, 25.5
    static func nonMaximumSuppression(
        detections: [AIDetection],
        iouThreshold: Float = nmsIoUThreshold
    ) -> [AIDetection] {
        guard detections.count > 1 else { return detections }

        // Group by label for class-aware NMS.
        let grouped = Dictionary(grouping: detections, by: { $0.label })
        var kept: [AIDetection] = []

        for (_, classDetections) in grouped {
            // Sort by confidence descending.
            let sorted = classDetections.sorted { $0.confidenceScore > $1.confidenceScore }
            var suppressed = Set<UUID>()

            for i in 0..<sorted.count {
                let candidate = sorted[i]
                guard !suppressed.contains(candidate.id) else { continue }
                kept.append(candidate)

                for j in (i + 1)..<sorted.count {
                    let other = sorted[j]
                    guard !suppressed.contains(other.id) else { continue }
                    if iou(candidate.normalizedBoundingBox, other.normalizedBoundingBox) >= iouThreshold {
                        suppressed.insert(other.id)
                    }
                }
            }
        }

        return kept
    }

    // MARK: - IoU Helper

    /// Computes the Intersection-over-Union of two axis-aligned bounding boxes.
    static func iou(_ a: CGRect, _ b: CGRect) -> Float {
        let intersection = a.intersection(b)
        guard !intersection.isNull else { return 0 }

        let intersectionArea = Float(intersection.width * intersection.height)
        let unionArea = Float(a.width * a.height) + Float(b.width * b.height) - intersectionArea
        guard unionArea > 0 else { return 0 }

        return intersectionArea / unionArea
    }
}
