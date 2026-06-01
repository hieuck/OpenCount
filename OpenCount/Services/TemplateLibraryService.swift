import Foundation
import SwiftData

// MARK: - SessionTemplate

/// A reusable session template storing ObjectTypes, default regions, and target counts.
/// Can be saved privately by the user or published to the Template Marketplace.
///
/// Requirement 54 (Req 43): private template library for one-tap session creation.
@Model
final class SessionTemplate {
    var id: UUID
    var name: String
    var templateDescription: String?
    var createdAt: Date
    /// true = stored locally only; false = published to CloudKit marketplace
    var isPrivate: Bool
    /// JSON-encoded array of `TemplateObjectTypeData`
    var objectTypeData: Data
    /// Version number for update tracking (Requirement 54: template versioning)
    var version: Int

    init(
        id: UUID = UUID(),
        name: String,
        templateDescription: String? = nil,
        createdAt: Date = Date(),
        isPrivate: Bool = true,
        objectTypeData: Data = Data(),
        version: Int = 1
    ) {
        self.id = id
        self.name = name
        self.templateDescription = templateDescription
        self.createdAt = createdAt
        self.isPrivate = isPrivate
        self.objectTypeData = objectTypeData
        self.version = version
    }
}

// MARK: - TemplateObjectTypeData

/// Codable snapshot of an ObjectType for template storage.
struct TemplateObjectTypeData: Codable {
    let name: String
    let colorHex: String
    let iconName: String
    let sortOrder: Int
    let targetCount: Int?
}

// MARK: - TemplateLibraryService

/// Manages the private template library stored in SwiftData.
///
/// Requirement 54 (Req 43): save sessions as private templates, list them,
/// and apply them to create new sessions with one tap.
final class TemplateLibraryService {

    // MARK: - Save session as template

    /// Saves the ObjectTypes from a session as a reusable private template.
    ///
    /// - Parameters:
    ///   - name: Display name for the template.
    ///   - description: Optional description.
    ///   - session: The source session whose ObjectTypes are captured.
    ///   - context: The SwiftData ModelContext to persist into.
    func saveAsTemplate(
        name: String,
        description: String?,
        from session: CountSession,
        into context: ModelContext
    ) throws {
        let typeData = session.objectTypes
            .sorted { $0.sortOrder < $1.sortOrder }
            .map { ot in
                TemplateObjectTypeData(
                    name: ot.name,
                    colorHex: ot.colorHex,
                    iconName: ot.iconName,
                    sortOrder: ot.sortOrder,
                    targetCount: ot.targetCount
                )
            }
        let encoded = try JSONEncoder().encode(typeData)
        let template = SessionTemplate(
            name: name,
            templateDescription: description,
            isPrivate: true,
            objectTypeData: encoded,
            version: 1
        )
        context.insert(template)
        try context.save()
    }

    /// Fetches all private templates sorted by creation date descending.
    func fetchPrivateTemplates(from context: ModelContext) throws -> [SessionTemplate] {
        let descriptor = FetchDescriptor<SessionTemplate>(
            predicate: #Predicate { $0.isPrivate == true },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        return try context.fetch(descriptor)
    }

    /// Applies a template to a new session by creating ObjectTypes from the template data.
    ///
    /// - Parameters:
    ///   - template: The template to apply.
    ///   - session: The target session to populate with ObjectTypes.
    func applyTemplate(_ template: SessionTemplate, to session: CountSession) throws {
        let typeData = try JSONDecoder().decode(
            [TemplateObjectTypeData].self,
            from: template.objectTypeData
        )
        for data in typeData {
            let objectType = ObjectType(
                name: data.name,
                colorHex: data.colorHex,
                iconName: data.iconName,
                sortOrder: data.sortOrder,
                session: session,
                targetCount: data.targetCount
            )
            session.objectTypes.append(objectType)
        }
    }

    /// Deletes a template from the store.
    func deleteTemplate(_ template: SessionTemplate, from context: ModelContext) throws {
        context.delete(template)
        try context.save()
    }

    /// Returns the decoded ObjectType data for preview purposes.
    func previewObjectTypes(for template: SessionTemplate) -> [TemplateObjectTypeData] {
        (try? JSONDecoder().decode([TemplateObjectTypeData].self, from: template.objectTypeData)) ?? []
    }
}
