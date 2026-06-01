import Foundation
import CloudKit

// MARK: - MarketplaceObjectTypeData

/// A lightweight, Codable representation of an ObjectType for marketplace templates.
/// This is used instead of the SwiftData @Model class so it can be serialized to/from CloudKit.
struct MarketplaceObjectTypeData: Codable, Identifiable, Equatable {
    var id: UUID
    var name: String
    var colorHex: String
    var iconName: String
    var sortOrder: Int

    init(
        id: UUID = UUID(),
        name: String,
        colorHex: String = "#FF5733",
        iconName: String = "circle.fill",
        sortOrder: Int = 0
    ) {
        self.id = id
        self.name = name
        self.colorHex = colorHex
        self.iconName = iconName
        self.sortOrder = sortOrder
    }

    /// Convenience initializer from a SwiftData ObjectType.
    init(from objectType: ObjectType) {
        self.id = objectType.id
        self.name = objectType.name
        self.colorHex = objectType.colorHex
        self.iconName = objectType.iconName
        self.sortOrder = objectType.sortOrder
    }
}

// MARK: - MarketplaceTemplate

/// A community-shared Object_Type template stored in the CloudKit public database.
///
/// Requirements: 26.1–26.6
struct MarketplaceTemplate: Codable, Identifiable, Equatable {
    /// CloudKit record name (used as stable identifier).
    var id: String
    var name: String
    var templateDescription: String
    var category: TemplateCategory
    var objectTypes: [MarketplaceObjectTypeData]
    var authorName: String
    var downloadCount: Int
    var averageRating: Double
    var ratingCount: Int
    var createdAt: Date
    /// Whether this template has been flagged for review.
    var isFlagged: Bool

    // MARK: - CloudKit record type

    static let recordType = "MarketplaceTemplate"

    // MARK: - CKRecord field keys

    enum RecordKey {
        static let name = "name"
        static let templateDescription = "templateDescription"
        static let category = "category"
        static let objectTypesJSON = "objectTypesJSON"
        static let authorName = "authorName"
        static let downloadCount = "downloadCount"
        static let averageRating = "averageRating"
        static let ratingCount = "ratingCount"
        static let createdAt = "createdAt"
        static let isFlagged = "isFlagged"
    }

    // MARK: - Init from CKRecord

    init?(record: CKRecord) {
        guard
            let name = record[RecordKey.name] as? String,
            let category = record[RecordKey.category] as? String,
            let objectTypesJSON = record[RecordKey.objectTypesJSON] as? String,
            let objectTypesData = objectTypesJSON.data(using: .utf8),
            let objectTypes = try? JSONDecoder().decode([MarketplaceObjectTypeData].self, from: objectTypesData)
        else { return nil }

        self.id = record.recordID.recordName
        self.name = name
        self.templateDescription = record[RecordKey.templateDescription] as? String ?? ""
        self.category = TemplateCategory(rawValue: category) ?? .other
        self.objectTypes = objectTypes
        self.authorName = record[RecordKey.authorName] as? String ?? "Anonymous"
        self.downloadCount = record[RecordKey.downloadCount] as? Int ?? 0
        self.averageRating = record[RecordKey.averageRating] as? Double ?? 0.0
        self.ratingCount = record[RecordKey.ratingCount] as? Int ?? 0
        self.createdAt = record.creationDate ?? Date()
        self.isFlagged = (record[RecordKey.isFlagged] as? Int ?? 0) != 0
    }

    // MARK: - Convert to CKRecord

    func toCKRecord() throws -> CKRecord {
        let recordID = CKRecord.ID(
            recordName: id,
            zoneID: TemplateMarketplaceService.zoneID
        )
        let record = CKRecord(recordType: Self.recordType, recordID: recordID)
        record[RecordKey.name] = name
        record[RecordKey.templateDescription] = templateDescription
        record[RecordKey.category] = category.rawValue
        let objectTypesData = try JSONEncoder().encode(objectTypes)
        record[RecordKey.objectTypesJSON] = String(data: objectTypesData, encoding: .utf8)
        record[RecordKey.authorName] = authorName
        record[RecordKey.downloadCount] = downloadCount
        record[RecordKey.averageRating] = averageRating
        record[RecordKey.ratingCount] = ratingCount
        record[RecordKey.isFlagged] = isFlagged ? 1 : 0
        return record
    }
}

// MARK: - TemplateCategory

/// Browsable categories for marketplace templates.
enum TemplateCategory: String, Codable, CaseIterable, Identifiable {
    case people = "People"
    case vehicles = "Vehicles"
    case animals = "Animals"
    case nature = "Nature"
    case inventory = "Inventory"
    case sports = "Sports"
    case science = "Science"
    case other = "Other"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .people:    return "person.2.fill"
        case .vehicles:  return "car.fill"
        case .animals:   return "pawprint.fill"
        case .nature:    return "leaf.fill"
        case .inventory: return "shippingbox.fill"
        case .sports:    return "sportscourt.fill"
        case .science:   return "flask.fill"
        case .other:     return "square.grid.2x2.fill"
        }
    }
}

// MARK: - ReportReason

/// Reasons a user can select when reporting an inappropriate template.
enum ReportReason: String, CaseIterable, Identifiable {
    case spam = "Spam"
    case inappropriate = "Inappropriate Content"
    case copyright = "Copyright Violation"
    case misleading = "Misleading Information"
    case other = "Other"

    var id: String { rawValue }
}

// MARK: - TemplateMarketplaceService

/// Manages all interactions with the CloudKit public database for the Template Marketplace.
///
/// - Fetches, publishes, installs, rates, and reports templates.
/// - Caches the last-fetched template list in UserDefaults for offline browsing (Req 33.6).
///
/// Requirements: 26.1–26.6, 33.6
@MainActor
final class TemplateMarketplaceService: ObservableObject {

    // MARK: - CloudKit configuration

    /// The CloudKit public database zone for the marketplace.
    static let zoneName = "TemplateMarketplace"
    static let zoneID = CKRecordZone.ID(zoneName: zoneName, ownerName: CKCurrentUserDefaultName)

    private let publicDatabase: CKDatabase
    private let container: CKContainer

    // MARK: - UserDefaults cache key (Req 33.6)

    private static let cacheKey = "com.opencount.templateMarketplace.cachedTemplates"

    // MARK: - Published state

    @Published var templates: [MarketplaceTemplate] = []
    @Published var isLoading: Bool = false
    @Published var error: String?

    // MARK: - Init

    init(containerIdentifier: String = "iCloud.com.opencount.app") {
        self.container = CKContainer(identifier: containerIdentifier)
        self.publicDatabase = container.publicCloudDatabase
        // Load cached templates immediately for offline browsing
        self.templates = Self.loadCachedTemplates()
    }

    // MARK: - Fetch templates (Req 26.2, 26.3)

    /// Fetches templates from the CloudKit public database.
    /// - Parameters:
    ///   - query: Optional text search applied to name and description.
    ///   - category: Optional category filter.
    func fetchTemplates(query: String? = nil, category: TemplateCategory? = nil) async {
        isLoading = true
        error = nil

        do {
            let predicate: NSPredicate
            if let category {
                predicate = NSPredicate(format: "%K == %@", MarketplaceTemplate.RecordKey.category, category.rawValue)
            } else {
                predicate = NSPredicate(value: true)
            }

            let ckQuery = CKQuery(recordType: MarketplaceTemplate.recordType, predicate: predicate)
            ckQuery.sortDescriptors = [NSSortDescriptor(key: MarketplaceTemplate.RecordKey.downloadCount, ascending: false)]

            let (results, _) = try await publicDatabase.records(matching: ckQuery, resultsLimit: 100)

            var fetched: [MarketplaceTemplate] = results.compactMap { _, result in
                guard let record = try? result.get() else { return nil }
                return MarketplaceTemplate(record: record)
            }
            // Filter out flagged templates
            .filter { !$0.isFlagged }

            // Apply client-side text search if provided
            if let query, !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                let lowercased = query.lowercased()
                fetched = fetched.filter {
                    $0.name.lowercased().contains(lowercased) ||
                    $0.templateDescription.lowercased().contains(lowercased) ||
                    $0.authorName.lowercased().contains(lowercased)
                }
            }

            templates = fetched
            Self.cacheTemplates(fetched)
        } catch {
            self.error = error.localizedDescription
            // Fall back to cached templates on network failure (Req 33.6)
            if templates.isEmpty {
                templates = Self.loadCachedTemplates()
            }
        }

        isLoading = false
    }

    // MARK: - Publish template (Req 26.1)

    /// Publishes the user's Object_Types as a new template to the marketplace.
    /// - Parameters:
    ///   - name: Template name.
    ///   - description: Template description.
    ///   - category: Template category.
    ///   - objectTypes: The Object_Types to include in the template.
    ///   - authorName: Display name for the author.
    func publishTemplate(
        name: String,
        description: String,
        category: TemplateCategory,
        objectTypes: [ObjectType],
        authorName: String
    ) async throws {
        let templateData = objectTypes.map { MarketplaceObjectTypeData(from: $0) }

        var template = MarketplaceTemplate(
            id: UUID().uuidString,
            name: name,
            templateDescription: description,
            category: category,
            objectTypes: templateData,
            authorName: authorName,
            downloadCount: 0,
            averageRating: 0.0,
            ratingCount: 0,
            createdAt: Date(),
            isFlagged: false
        )

        let record = try template.toCKRecord()
        let savedRecord = try await publicDatabase.save(record)

        // Update local ID with the saved record's name
        template.id = savedRecord.recordID.recordName

        // Prepend to local list
        templates.insert(template, at: 0)
        Self.cacheTemplates(templates)
    }

    // MARK: - Install template (Req 26.3)

    /// Installs a marketplace template by adding its Object_Types to the given session.
    /// - Parameters:
    ///   - template: The template to install.
    ///   - session: The CountSession to add the Object_Types to.
    func installTemplate(
        _ template: MarketplaceTemplate,
        into session: CountSession
    ) async throws {
        let existingSortOrders = session.objectTypes.map(\.sortOrder)
        let maxSortOrder = existingSortOrders.max() ?? -1

        for (index, typeData) in template.objectTypes.enumerated() {
            let objectType = ObjectType(
                id: UUID(),
                name: typeData.name,
                colorHex: typeData.colorHex,
                iconName: typeData.iconName,
                sortOrder: maxSortOrder + 1 + index,
                session: session
            )
            session.objectTypes.append(objectType)
        }

        try await StorageService.shared.save(session)

        // Increment download count in CloudKit (best-effort, non-blocking)
        Task.detached(priority: .background) { [weak self] in
            await self?.incrementDownloadCount(for: template.id)
        }
    }

    // MARK: - Rate template (Req 26.4, 26.5)

    /// Submits a star rating (1–5) for a template.
    /// Uses a separate `TemplateRating` record to avoid race conditions on the template record.
    func rateTemplate(_ template: MarketplaceTemplate, rating: Int) async throws {
        guard (1...5).contains(rating) else {
            throw TemplateMarketplaceError.invalidRating
        }

        // Store the rating as a separate record linked to the template
        let ratingRecord = CKRecord(recordType: "TemplateRating")
        ratingRecord["templateID"] = template.id
        ratingRecord["rating"] = rating
        ratingRecord["ratedAt"] = Date()

        try await publicDatabase.save(ratingRecord)

        // Optimistically update local average
        if let index = templates.firstIndex(where: { $0.id == template.id }) {
            let current = templates[index]
            let newCount = current.ratingCount + 1
            let newAverage = (current.averageRating * Double(current.ratingCount) + Double(rating)) / Double(newCount)
            templates[index].averageRating = newAverage
            templates[index].ratingCount = newCount
            Self.cacheTemplates(templates)
        }
    }

    // MARK: - Report template (Req 26.6)

    /// Reports an inappropriate template by creating a flag record in CloudKit.
    func reportTemplate(_ template: MarketplaceTemplate, reason: ReportReason) async throws {
        let reportRecord = CKRecord(recordType: "TemplateReport")
        reportRecord["templateID"] = template.id
        reportRecord["reason"] = reason.rawValue
        reportRecord["reportedAt"] = Date()

        try await publicDatabase.save(reportRecord)
    }

    // MARK: - Private helpers

    private func incrementDownloadCount(for templateID: String) async {
        let recordID = CKRecord.ID(
            recordName: templateID,
            zoneID: Self.zoneID
        )
        do {
            let record = try await publicDatabase.record(for: recordID)
            let current = record[MarketplaceTemplate.RecordKey.downloadCount] as? Int ?? 0
            record[MarketplaceTemplate.RecordKey.downloadCount] = current + 1
            _ = try await publicDatabase.save(record)
        } catch {
            // Non-critical; ignore failures
        }
    }

    // MARK: - UserDefaults cache (Req 33.6)

    private static func cacheTemplates(_ templates: [MarketplaceTemplate]) {
        guard let data = try? JSONEncoder().encode(templates) else { return }
        UserDefaults.standard.set(data, forKey: cacheKey)
    }

    private static func loadCachedTemplates() -> [MarketplaceTemplate] {
        guard
            let data = UserDefaults.standard.data(forKey: cacheKey),
            let templates = try? JSONDecoder().decode([MarketplaceTemplate].self, from: data)
        else { return [] }
        return templates
    }
}

// MARK: - MarketplaceTemplate memberwise init (for internal use)

extension MarketplaceTemplate {
    init(
        id: String,
        name: String,
        templateDescription: String,
        category: TemplateCategory,
        objectTypes: [MarketplaceObjectTypeData],
        authorName: String,
        downloadCount: Int,
        averageRating: Double,
        ratingCount: Int,
        createdAt: Date,
        isFlagged: Bool
    ) {
        self.id = id
        self.name = name
        self.templateDescription = templateDescription
        self.category = category
        self.objectTypes = objectTypes
        self.authorName = authorName
        self.downloadCount = downloadCount
        self.averageRating = averageRating
        self.ratingCount = ratingCount
        self.createdAt = createdAt
        self.isFlagged = isFlagged
    }
}

// MARK: - TemplateMarketplaceError

enum TemplateMarketplaceError: LocalizedError {
    case invalidRating
    case recordNotFound
    case encodingFailed

    var errorDescription: String? {
        switch self {
        case .invalidRating:
            return "Rating must be between 1 and 5 stars."
        case .recordNotFound:
            return "The template could not be found in the marketplace."
        case .encodingFailed:
            return "Failed to encode template data."
        }
    }
}
