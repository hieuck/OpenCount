import SwiftUI

// MARK: - SampleSessionSeeder

/// Seeds the bundled `SampleSession.json` fixture into StorageService on first launch.
///
/// Requirements: 29.4, 29.5
enum SampleSessionSeeder {

    private static let seededKey = "hasSeedSampleSession"

    /// Seeds the sample session if it has not been seeded before.
    /// - Parameter force: When true, seeds even if previously created.
    @MainActor
    static func seedIfNeeded(force: Bool = false) async {
        guard force || !UserDefaults.standard.bool(forKey: seededKey) else { return }
        guard let session = loadFixture() else { return }
        try? await StorageService.shared.save(session)
        UserDefaults.standard.set(true, forKey: seededKey)
    }

    /// Seeds into an AppState (called from AppState.seedSampleIfNeeded).
    @MainActor
    static func seed(into appState: AppState) {
        guard let session = loadFixture() else { return }
        appState.sessions.append(session)
        Task { try? await StorageService.shared.save(session) }
    }

    // MARK: - Fixture loading

    private static func loadFixture() -> CountSession? {
        guard let url = Bundle.main.url(forResource: "SampleSession", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let dto = try? JSONDecoder().decode(SampleSessionDTO.self, from: data)
        else {
            return nil
        }

        let session = CountSession(
            name: dto.name,
            sessionDescription: dto.sessionDescription
        )

        var objectTypeMap: [String: ObjectType] = [:]
        for otDTO in dto.objectTypes {
            let ot = ObjectType(
                name: otDTO.name,
                colorHex: otDTO.colorHex,
                iconName: otDTO.iconName,
                sortOrder: otDTO.sortOrder,
                session: session
            )
            objectTypeMap[otDTO.id] = ot
        }
        session.objectTypes = Array(objectTypeMap.values).sorted { $0.sortOrder < $1.sortOrder }

        var markers: [CountMarker] = []
        for mDTO in dto.markers {
            guard let objectType = objectTypeMap[mDTO.objectTypeID] else { continue }
            let marker = CountMarker(
                normalizedX: mDTO.normalizedX,
                normalizedY: mDTO.normalizedY,
                objectType: objectType,
                isAIDerived: mDTO.isAIDerived,
                session: session
            )
            markers.append(marker)
        }
        session.markers = markers

        var regions: [CountRegion] = []
        for rDTO in dto.regions {
            let points = rDTO.normalizedPoints.map { CGPoint(x: $0.x, y: $0.y) }
            let shapeType = RegionShapeType(rawValue: rDTO.shapeType) ?? .rectangle
            let region = CountRegion(
                name: rDTO.name,
                colorHex: rDTO.colorHex,
                shapeType: shapeType,
                normalizedPoints: points,
                session: session
            )
            regions.append(region)
        }
        session.regions = regions

        return session
    }
}

// MARK: - DTO types

private struct SampleSessionDTO: Decodable {
    let id: String
    let name: String
    let sessionDescription: String?
    let objectTypes: [ObjectTypeDTO]
    let markers: [MarkerDTO]
    let regions: [RegionDTO]
}

private struct ObjectTypeDTO: Codable {
    let id: String
    let name: String
    let colorHex: String
    let iconName: String
    let sortOrder: Int
}

private struct MarkerDTO: Codable {
    let id: String
    let normalizedX: Double
    let normalizedY: Double
    let objectTypeID: String
    let isAIDerived: Bool
}

private struct RegionDTO: Codable {
    let id: String
    let name: String
    let colorHex: String
    let shapeType: String
    let normalizedPoints: [PointDTO]
}

private struct PointDTO: Codable {
    let x: Double
    let y: Double
}
