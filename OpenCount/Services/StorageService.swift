import Foundation

// MARK: - StorageServiceProtocol (Enhanced)

protocol StorageServiceProtocol {
    func save(_ session: CountSession) async throws
    func delete(_ session: CountSession) async throws
    func fetchAllSessions() async throws -> [CountSession]
    func fetchSessions(matching query: String) async throws -> [CountSession]
}

// MARK: - StorageService (JSON file-based with image optimization, iOS 16+)

/// Persists sessions as individual JSON files in Documents/sessions/.
/// Enhanced with intelligent image handling:
/// - Automatic optimization of imported images
/// - Downsampling for processing pipelines
/// - Cached thumbnail generation
/// - Memory-efficient lazy loading
///
/// Each session is stored as <uuid>.json with associated images in Documents/images/<uuid>/
final class StorageService: StorageServiceProtocol {

    // MARK: - Singleton
    static let shared = StorageService()

    // MARK: - Dependencies
    private let imageOptimizer = ImageOptimizationService.shared
    private let thumbnailCache = ThumbnailCacheManager.shared

    // MARK: - Directory structure
    private var sessionsDir: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dir = docs.appendingPathComponent("sessions", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private var imagesBaseDir: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dir = docs.appendingPathComponent("images", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private func imagesDir(for sessionID: UUID) -> URL {
        let dir = imagesBaseDir.appendingPathComponent(sessionID.uuidString, isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private func fileURL(for session: CountSession) -> URL {
        sessionsDir.appendingPathComponent("\(session.id.uuidString).json")
    }

    // MARK: - Encoders/Decoders
    private var encoder: JSONEncoder {
        let e = JSONEncoder()
        e.outputFormatting = [.sortedKeys]
        e.dateEncodingStrategy = .iso8601
        return e
    }

    private var decoder: JSONDecoder {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }

    // MARK: - StorageServiceProtocol

    func save(_ session: CountSession) async throws {
        let data = try encoder.encode(session)
        try data.write(to: fileURL(for: session), options: .atomic)

        // Asynchronously optimize and cache session images
        await optimizeSessionImages(session)
    }

    func delete(_ session: CountSession) async throws {
        let url = fileURL(for: session)
        if FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }

        // Remove session images directory
        let sessionImagesDir = imagesDir(for: session.id)
        try? FileManager.default.removeItem(at: sessionImagesDir)

        // Clear thumbnail cache for this session
        for image in session.images {
            thumbnailCache.removeThumbnail(for: "\(session.id.uuidString)_\(image.id.uuidString)")
        }
    }

    func fetchAllSessions() async throws -> [CountSession] {
        let files = (try? FileManager.default.contentsOfDirectory(
            at: sessionsDir, includingPropertiesForKeys: nil)) ?? []
        var sessions: [CountSession] = []

        for file in files where file.pathExtension == "json" {
            if let data = try? Data(contentsOf: file),
               let session = try? decoder.decode(CountSession.self, from: data) {
                sessions.append(session)
            }
        }

        return sessions.sorted { $0.modifiedAt > $1.modifiedAt }
    }

    func fetchSessions(matching query: String) async throws -> [CountSession] {
        let all = try await fetchAllSessions()
        guard !query.isEmpty else { return all }
        return all.filter { $0.name.localizedStandardContains(query) }
    }

    // MARK: - Image optimization

    /// Optimize all images in a session for efficient storage and processing.
    /// - Generates thumbnails for list display
    /// - Downsamples large images
    /// - Caches for fast retrieval
    private func optimizeSessionImages(_ session: CountSession) async {
        let sessionImagesDir = imagesDir(for: session.id)

        for image in session.images {
            let fullImageURL = sessionImagesDir.appendingPathComponent(image.filename)

            guard FileManager.default.fileExists(atPath: fullImageURL.path) else {
                continue
            }

            // Asynchronously generate and cache thumbnail
            await generateAndCacheThumbnail(
                imageURL: fullImageURL,
                sessionID: session.id,
                imageID: image.id,
                sessionImagesDir: sessionImagesDir,
                image: image
            )

            // Optimize for storage if not already done
            if image.optimizedFilename == nil {
                await optimizeForStorage(
                    imageURL: fullImageURL,
                    sessionID: session.id,
                    imageID: image.id
                )
            }
        }
    }

    private func generateAndCacheThumbnail(
        imageURL: URL,
        sessionID: UUID,
        imageID: UUID,
        sessionImagesDir: URL,
        image: SessionImage
    ) async {
        let cacheKey = "\(sessionID.uuidString)_\(imageID.uuidString)"
        let thumbnailSize = CGSize(width: 52, height: 52)

        await withCheckedContinuation { continuation in
            imageOptimizer.optimizeForThumbnail(
                sourceURL: imageURL,
                size: thumbnailSize
            ) { [weak self] thumbnail in
                if let thumbnail = thumbnail {
                    // Cache in ThumbnailCacheManager
                    self?.thumbnailCache.preloadThumbnail(
                        for: imageURL,
                        cacheKey: cacheKey,
                        size: thumbnailSize
                    )

                    // Optionally save thumbnail file for offline access
                    let thumbFilename = "\(imageID.uuidString)_thumb.jpg"
                    let thumbURL = sessionImagesDir.appendingPathComponent(thumbFilename)
                    if let jpegData = thumbnail.jpegData(compressionQuality: 0.85) {
                        try? jpegData.write(to: thumbURL, options: .atomic)
                    }
                }
                continuation.resume()
            }
        }
    }

    private func optimizeForStorage(
        imageURL: URL,
        sessionID: UUID,
        imageID: UUID
    ) async {
        await withCheckedContinuation { continuation in
            imageOptimizer.optimizeForStorage(sourceURL: imageURL) { data in
                if let optimizedData = data {
                    let optimizedFilename = "\(imageID.uuidString)_optimized.jpg"
                    let sessionImagesDir = self.imagesDir(for: sessionID)
                    let optimizedURL = sessionImagesDir.appendingPathComponent(optimizedFilename)

                    try? optimizedData.write(to: optimizedURL, options: .atomic)
                }
                continuation.resume()
            }
        }
    }

    /// Preload images for a session to enable faster display when opened.
    /// - Parameters:
    ///   - sessionID: Session to preload images for
    func preloadSessionImages(_ sessionID: UUID) async {
        guard let session = try? await fetchAllSessions()
            .first(where: { $0.id == sessionID }) else {
            return
        }

        await optimizeSessionImages(session)
    }

    /// Get the thumbnail for a session's first image, with lazy loading support.
    /// - Parameters:
    ///   - sessionID: Session identifier
    ///   - completion: Called with thumbnail image or nil
    func loadSessionThumbnail(
        for sessionID: UUID,
        completion: @escaping (UIImage?) -> Void
    ) {
        Task {
            guard let session = try? await fetchAllSessions()
                    .first(where: { $0.id == sessionID }),
                  let firstImage = session.images.sorted(by: { $0.importedAt < $1.importedAt }).first else {
                completion(nil)
                return
            }

            let sessionImagesDir = imagesDir(for: sessionID)
            let cacheKey = "\(sessionID.uuidString)_\(firstImage.id.uuidString)"
            let thumbnailSize = CGSize(width: 52, height: 52)

            // First try thumbnail file
            if let thumbName = firstImage.thumbnailFilename {
                let thumbURL = sessionImagesDir.appendingPathComponent(thumbName)
                if FileManager.default.fileExists(atPath: thumbURL.path) {
                    thumbnailCache.thumbnail(
                        for: thumbURL,
                        cacheKey: cacheKey,
                        size: thumbnailSize,
                        completion: completion
                    )
                    return
                }
            }

            // Fall back to full image
            let fullURL = sessionImagesDir.appendingPathComponent(firstImage.filename)
            thumbnailCache.thumbnail(
                for: fullURL,
                cacheKey: cacheKey,
                size: thumbnailSize,
                completion: completion
            )
        }
    }
}

// MARK: - TagStorageService (unchanged)

/// Persists SessionTags as a single JSON file in Documents/tags.json
final class TagStorageService {
    static let shared = TagStorageService()

    private var tagsURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("tags.json")
    }

    private var encoder: JSONEncoder {
        let e = JSONEncoder(); e.dateEncodingStrategy = .iso8601; return e
    }
    private var decoder: JSONDecoder {
        let d = JSONDecoder(); d.dateDecodingStrategy = .iso8601; return d
    }

    func loadAll() -> [SessionTag] {
        guard let data = try? Data(contentsOf: tagsURL),
              let tags = try? decoder.decode([SessionTag].self, from: data) else { return [] }
        return tags
    }

    func saveAll(_ tags: [SessionTag]) {
        if let data = try? encoder.encode(tags) {
            try? data.write(to: tagsURL, options: .atomic)
        }
    }

    /// Returns tag IDs assigned to a session (stored in UserDefaults)
    func assignedTagIDs(for sessionID: UUID) -> [UUID] {
        let key = "session_tags_\(sessionID.uuidString)"
        guard let data = UserDefaults.standard.data(forKey: key),
              let ids = try? JSONDecoder().decode([UUID].self, from: data) else { return [] }
        return ids
    }

    func setAssignedTagIDs(_ ids: [UUID], for sessionID: UUID) {
        let key = "session_tags_\(sessionID.uuidString)"
        if let data = try? JSONEncoder().encode(ids) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    func assignedTags(for sessionID: UUID) -> [SessionTag] {
        let ids = Set(assignedTagIDs(for: sessionID))
        return loadAll().filter { ids.contains($0.id) }
    }
}
