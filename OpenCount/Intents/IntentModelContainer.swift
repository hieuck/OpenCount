import Foundation
import SwiftData

// MARK: - IntentModelContainer

/// Shared helper for creating a ModelContainer in App Intents.
/// All intents must use the same schema as the main app to avoid
/// SwiftData migration errors.
enum IntentModelContainer {

    /// Creates a ModelContainer with the full app schema.
    /// This must match the schema in OpenCountApp.init().
    static func makeContainer() throws -> ModelContainer {
        let schema = Schema([
            CountSession.self,
            ObjectType.self,
            CountMarker.self,
            CountRegion.self,
            SessionImage.self,
            VideoFrameCount.self,
            SessionTemplate.self,
            SessionTag.self,
            CountFormula.self,
        ])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        return try ModelContainer(for: schema, configurations: [config])
    }
}
