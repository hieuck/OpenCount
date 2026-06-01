import SwiftUI
import SwiftData

// MARK: - SampleSessionSeeder

/// Seeds the bundled `SampleSession.json` fixture into SwiftData on first launch.
///
/// The seeder is idempotent: it checks `UserDefaults` for the key
/// `"hasSeedSampleSession"` before inserting, so the sample session is only
/// created once.  The "Restore Sample Session" action in Settings calls
/// `seedIfNeeded(force:)` with `force: true` to re-create it even if it was
/// previously deleted.
///
/// Requirements: 29.4, 29.5
enum SampleSessionSeeder {

    // MARK: - UserDefaults key

    private static let seededKey = "hasSeedSampleSession"

    // MARK: - Public API

    /// Seeds the sample session if it has not been seeded before.
    ///
    /// - Parameters:
    ///   - context: The SwiftData `ModelContext` to insert into.
    ///   - force: When `true`, seeds even if the session was previously created.
    ///            Used by the "Restore Sample Session" Settings action.
    @MainActor
    static func seedIfNeeded(into context: ModelContext, force: Bool = false) {
        guard force || !UserDefaults.standard.bool(forKey: seededKey) else { return }
        guard let session = loadFixture() else { return }
        context.insert(session)
        try? context.save()
        UserDefaults.standard.set(true, forKey: seededKey)
    }

    // MARK: - Fixture loading

    /// Parses `SampleSession.json` from the app bundle and constructs a
    /// `CountSession` with its associated `ObjectType` and `CountMarker` records.
    private static func loadFixture() -> CountSession? {
        guard let url = Bundle.main.url(forResource: "SampleSession", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let dto = try? JSONDecoder().decode(SampleSessionDTO.self, from: data)
        else {
            assertionFailure("SampleSession.json missing or malformed")
            return nil
        }

        // Build ObjectType map
        var objectTypeMap: [String: ObjectType] = [:]
        for otDTO in dto.objectTypes {
            let ot = ObjectType(
                name: otDTO.name,
                colorHex: otDTO.colorHex,
                iconName: otDTO.iconName,
                sortOrder: otDTO.sortOrder
            )
            objectTypeMap[otDTO.id] = ot
        }

        // Build CountMarker list
        var markers: [CountMarker] = []
        for mDTO in dto.markers {
            guard let objectType = objectTypeMap[mDTO.objectTypeID] else { continue }
            let marker = CountMarker(
                normalizedX: mDTO.normalizedX,
                normalizedY: mDTO.normalizedY,
                objectType: objectType,
                isAIDerived: mDTO.isAIDerived
            )
            markers.append(marker)
        }

        // Build CountRegion list
        var regions: [CountRegion] = []
        for rDTO in dto.regions {
            let points = rDTO.normalizedPoints.map { CGPoint(x: $0.x, y: $0.y) }
            let shapeType = RegionShapeType(rawValue: rDTO.shapeType) ?? .rectangle
            let region = CountRegion(
                name: rDTO.name,
                colorHex: rDTO.colorHex,
                shapeType: shapeType,
                normalizedPoints: points
            )
            regions.append(region)
        }

        // Assemble session
        let session = CountSession(
            name: dto.name,
            sessionDescription: dto.sessionDescription
        )
        session.objectTypes = Array(objectTypeMap.values)
        session.markers = markers
        session.regions = regions

        return session
    }
}

// MARK: - DTO types (private, used only for JSON decoding)

private struct SampleSessionDTO: Decodable {
    let id: String
    let name: String
    let sessionDescription: String?
    let objectTypes: [ObjectTypeDTO]
    let markers: [MarkerDTO]
    let regions: [RegionDTO]
}

private struct ObjectTypeDTO: Decodable {
    let id: String
    let name: String
    let colorHex: String
    let iconName: String
    let sortOrder: Int
}

private struct MarkerDTO: Decodable {
    let id: String
    let normalizedX: Double
    let normalizedY: Double
    let objectTypeID: String
    let isAIDerived: Bool
}

private struct RegionDTO: Decodable {
    let id: String
    let name: String
    let colorHex: String
    let shapeType: String
    let normalizedPoints: [PointDTO]
}

private struct PointDTO: Decodable {
    let x: Double
    let y: Double
}
