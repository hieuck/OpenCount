import Foundation

/// Bridges Swift file system to KMP PlatformStorage
class StorageBridgeImpl: StorageBridge {
    private let fileManager = FileManager.default
    private let sessionsDir: URL

    init() {
        let docs = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        sessionsDir = docs.appendingPathComponent("kmp_sessions", isDirectory: true)
        try? fileManager.createDirectory(at: sessionsDir, withIntermediateDirectories: true)
    }

    func save(_ id: String, json: String) {
        let url = sessionsDir.appendingPathComponent("\(id).json")
        try? json.write(to: url, atomically: true, encoding: .utf8)
    }

    func load(_ id: String) -> String? {
        let url = sessionsDir.appendingPathComponent("\(id).json")
        return try? String(contentsOf: url, encoding: .utf8)
    }

    func loadAll() -> [String] {
        guard let files = try? fileManager.contentsOfDirectory(at: sessionsDir,
                includingPropertiesForKeys: nil) else { return [] }
        return files.filter { $0.pathExtension == "json" }.compactMap {
            try? String(contentsOf: $0, encoding: .utf8)
        }
    }

    func delete(_ id: String) {
        let url = sessionsDir.appendingPathComponent("\(id).json")
        try? fileManager.removeItem(at: url)
    }

    func exists(_ id: String) -> Bool {
        let url = sessionsDir.appendingPathComponent("\(id).json")
        return fileManager.fileExists(atPath: url.path)
    }
}
