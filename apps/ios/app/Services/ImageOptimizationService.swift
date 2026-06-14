// ImageOptimizationService.swift
import Foundation
import UIKit
import CoreGraphics
import ImageIO

final class ImageOptimizationService {
    static let shared = ImageOptimizationService()
    private init() {}

    // Max dimension for AI inference
    static let maxInferenceDimension: CGFloat = 1920

    // Whether an image exceeds the inference threshold and should be downsampled
    func shouldDownsample(dimensions: CGSize) -> Bool {
        dimensions.width > Self.maxInferenceDimension || dimensions.height > Self.maxInferenceDimension
    }

    // Optimize an image for AI inference: downsample if too large
    func optimizeForInference(_ image: UIImage) -> UIImage {
        let maxDim = Self.maxInferenceDimension
        let size = image.size
        guard size.width > maxDim || size.height > maxDim else { return image }
        let scale = maxDim / max(size.width, size.height)
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        return image.resized(to: newSize) ?? image
    }

    // Generate thumbnail from file URL
    func optimizeForThumbnail(sourceURL: URL, size: CGSize, completion: @escaping (UIImage?) -> Void) {
        DispatchQueue.global(qos: .utility).async {
            guard let imageSource = CGImageSourceCreateWithURL(sourceURL as CFURL, nil) else {
                DispatchQueue.main.async { completion(nil) }
                return
            }
            let options: [CFString: Any] = [
                kCGImageSourceThumbnailMaxPixelSize: max(size.width, size.height),
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true
            ]
            guard let cgImage = CGImageSourceCreateThumbnailAtIndex(imageSource, 0, options as CFDictionary) else {
                DispatchQueue.main.async { completion(nil) }
                return
            }
            let thumbnail = UIImage(cgImage: cgImage)
            DispatchQueue.main.async { completion(thumbnail) }
        }
    }

    // Compress image for storage (JPEG, 0.8 quality, max 4096px)
    func optimizeForStorage(sourceURL: URL, completion: @escaping (Data?) -> Void) {
        DispatchQueue.global(qos: .utility).async {
            guard let imageSource = CGImageSourceCreateWithURL(sourceURL as CFURL, nil) else {
                DispatchQueue.main.async { completion(nil) }
                return
            }
            let options: [CFString: Any] = [
                kCGImageSourceThumbnailMaxPixelSize: 4096,
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true
            ]
            guard let cgImage = CGImageSourceCreateThumbnailAtIndex(imageSource, 0, options as CFDictionary) else {
                DispatchQueue.main.async { completion(nil) }
                return
            }
            let image = UIImage(cgImage: cgImage)
            let data = image.jpegData(compressionQuality: 0.80)
            DispatchQueue.main.async { completion(data) }
        }
    }
}

private extension UIImage {
    func resized(to targetSize: CGSize) -> UIImage? {
        let renderer = UIGraphicsImageRenderer(size: targetSize)
        return renderer.image { _ in
            self.draw(in: CGRect(origin: .zero, size: targetSize))
        }
    }
}
