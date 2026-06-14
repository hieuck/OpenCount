// LazyImageLoader.swift
import Foundation
import UIKit
import SwiftUI

@MainActor
final class LazyImageLoader: ObservableObject {
    @Published var thumbnails: [UUID: UIImage] = [:]

    private var loadingIDs: Set<UUID> = []
    private let thumbnailCache = ThumbnailCacheManager.shared
    private let thumbnailSize = CGSize(width: 52, height: 52)

    func loadThumbnail(for sessionID: UUID, from session: CountSession) {
        guard thumbnails[sessionID] == nil, !loadingIDs.contains(sessionID) else { return }
        loadingIDs.insert(sessionID)

        Task {
            let image = await loadImageAsync(for: sessionID, from: session)
            loadingIDs.remove(sessionID)
            if let image {
                thumbnails[sessionID] = image
            }
        }
    }

    private func loadImageAsync(for sessionID: UUID, from session: CountSession) async -> UIImage? {
        guard let firstImage = session.images.sorted(by: { $0.importedAt < $1.importedAt }).first else {
            return nil
        }

        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let imagesDir = docs
            .appendingPathComponent("images")
            .appendingPathComponent(sessionID.uuidString)

        // Try thumbnail file first
        if let thumbName = firstImage.thumbnailFilename {
            let thumbURL = imagesDir.appendingPathComponent(thumbName)
            if FileManager.default.fileExists(atPath: thumbURL.path) {
                return await withCheckedContinuation { continuation in
                    thumbnailCache.thumbnail(
                        for: thumbURL,
                        cacheKey: "\(sessionID.uuidString)_\(firstImage.id.uuidString)",
                        size: thumbnailSize
                    ) { image in
                        continuation.resume(returning: image)
                    }
                }
            }
        }

        // Fall back to full image
        let fullURL = imagesDir.appendingPathComponent(firstImage.filename)
        guard FileManager.default.fileExists(atPath: fullURL.path) else { return nil }

        return await withCheckedContinuation { continuation in
            thumbnailCache.thumbnail(
                for: fullURL,
                cacheKey: "\(sessionID.uuidString)_\(firstImage.id.uuidString)",
                size: thumbnailSize
            ) { image in
                continuation.resume(returning: image)
            }
        }
    }
}
