// ThumbnailCacheManager.swift
import Foundation
import UIKit
import CoreGraphics
import ImageIO

final class ThumbnailCacheManager {
    static let shared = ThumbnailCacheManager()

    private let cache = NSCache<NSString, UIImage>()
    private let queue = DispatchQueue(label: "com.opencount.thumbnailCache", qos: .utility)

    private init() {
        cache.countLimit = 200
        cache.totalCostLimit = 50 * 1024 * 1024 // 50 MB
    }

    func thumbnail(for url: URL, cacheKey: String, size: CGSize, completion: @escaping (UIImage?) -> Void) {
        let key = NSString(string: cacheKey)
        if let cached = cache.object(forKey: key) {
            completion(cached)
            return
        }
        queue.async { [weak self] in
            let image = self?.generateThumbnail(from: url, size: size)
            if let image {
                self?.cache.setObject(image, forKey: key, cost: Int(size.width * size.height * 4))
            }
            DispatchQueue.main.async { completion(image) }
        }
    }

    func preloadThumbnail(for url: URL, cacheKey: String, size: CGSize) {
        let key = NSString(string: cacheKey)
        guard cache.object(forKey: key) == nil else { return }
        queue.async { [weak self] in
            if let image = self?.generateThumbnail(from: url, size: size) {
                self?.cache.setObject(image, forKey: key, cost: Int(size.width * size.height * 4))
            }
        }
    }

    func removeThumbnail(for cacheKey: String) {
        cache.removeObject(forKey: NSString(string: cacheKey))
    }

    private func generateThumbnail(from url: URL, size: CGSize) -> UIImage? {
        guard let imageSource = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceThumbnailMaxPixelSize: max(size.width, size.height),
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true
        ]
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(imageSource, 0, options as CFDictionary) else { return nil }
        return UIImage(cgImage: cgImage)
    }
}
