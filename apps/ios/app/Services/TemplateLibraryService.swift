import Foundation

// MARK: - SessionTemplate

final class SessionTemplate: ObservableObject, Identifiable, Codable {
    var id: UUID
    var name: String
    var templateDescription: String?
    var createdAt: Date
    var isPrivate: Bool
    var objectTypeData: Data
    var version: Int

    init(id: UUID = UUID(), name: String, templateDescription: String? = nil,
         createdAt: Date = Date(), isPrivate: Bool = true,
         objectTypeData: Data = Data(), version: Int = 1) {
        self.id = id; self.name = name; self.templateDescription = templateDescription
        self.createdAt = createdAt; self.isPrivate = isPrivate
        self.objectTypeData = objectTypeData; self.version = version
    }
}

// MARK: - TemplateObjectTypeData

struct TemplateObjectTypeData: Codable {
    let name: String
    let colorHex: String
    let iconName: String
    let sortOrder: Int
    let targetCount: Int?
}

// MARK: - TemplateLibraryService

final class TemplateLibraryService {

    private var templatesURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("templates.json")
    }

    private var encoder: JSONEncoder {
        let e = JSONEncoder(); e.dateEncodingStrategy = .iso8601; return e
    }
    private var decoder: JSONDecoder {
        let d = JSONDecoder(); d.dateDecodingStrategy = .iso8601; return d
    }

    func loadAll() -> [SessionTemplate] {
        guard let data = try? Data(contentsOf: templatesURL),
              let templates = try? decoder.decode([SessionTemplate].self, from: data) else { return [] }
        return templates.sorted { $0.createdAt > $1.createdAt }
    }

    func saveAll(_ templates: [SessionTemplate]) {
        if let data = try? encoder.encode(templates) {
            try? data.write(to: templatesURL, options: .atomic)
        }
    }

    func saveAsTemplate(name: String, description: String?, from session: CountSession) throws {
        let typeData = session.objectTypes
            .sorted { $0.sortOrder < $1.sortOrder }
            .map { TemplateObjectTypeData(name: $0.name, colorHex: $0.colorHex,
                                          iconName: $0.iconName, sortOrder: $0.sortOrder,
                                          targetCount: $0.targetCount) }
        let encoded = try JSONEncoder().encode(typeData)
        let template = SessionTemplate(name: name, templateDescription: description,
                                       isPrivate: true, objectTypeData: encoded)
        var all = loadAll()
        all.append(template)
        saveAll(all)
    }

    func applyTemplate(_ template: SessionTemplate, to session: CountSession) throws {
        let typeData = try JSONDecoder().decode([TemplateObjectTypeData].self,
                                                from: template.objectTypeData)
        for data in typeData {
            let ot = ObjectType(name: data.name, colorHex: data.colorHex,
                                iconName: data.iconName, sortOrder: data.sortOrder,
                                session: session, targetCount: data.targetCount)
            session.objectTypes.append(ot)
        }
    }

    func deleteTemplate(_ template: SessionTemplate) {
        var all = loadAll()
        all.removeAll { $0.id == template.id }
        saveAll(all)
    }

    func previewObjectTypes(for template: SessionTemplate) -> [TemplateObjectTypeData] {
        (try? JSONDecoder().decode([TemplateObjectTypeData].self, from: template.objectTypeData)) ?? []
    }
}
