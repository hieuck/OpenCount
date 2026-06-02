import Foundation
import Network
import os.log

// MARK: - LocalAPIServer

/// A local HTTP server on localhost:47200 exposing session data via a REST API.
/// Opt-in, toggled in Settings under "Developer Tools". Binds only to 127.0.0.1.
///
/// Endpoints:
///   GET /sessions                        — list all sessions as JSON
///   GET /sessions/{id}/tally             — return current tally for a session
///   POST /sessions/{id}/markers          — add a marker (body: {objectType, x, y})
///   GET /sessions/{id}/export?format=csv|json — stream export file
///
/// Requirement 55 (Req 44)
@MainActor
final class LocalAPIServer: ObservableObject {

    // MARK: - Published state

    @Published var isRunning: Bool = false
    @Published var requestCount: Int = 0

    // MARK: - Configuration

    static let port: UInt16 = 47200
    static let host = "127.0.0.1"

    // MARK: - Private

    private var listener: NWListener?
    private var storage: StorageServiceProtocol?

    // MARK: - Lifecycle

    /// Starts the server.
    func start(storage: StorageServiceProtocol) {
        guard !isRunning else { return }
        self.storage = storage

        do {
            let params = NWParameters.tcp
            guard let port = NWEndpoint.Port(rawValue: Self.port) else {
                throw NSError(domain: "LocalAPIServer", code: -1,
                            userInfo: [NSLocalizedDescriptionKey: "Invalid port number: \(Self.port)"])
            }
            params.requiredLocalEndpoint = NWEndpoint.hostPort(
                host: NWEndpoint.Host(Self.host),
                port: port
            )
            listener = try NWListener(using: params)
            listener?.newConnectionHandler = { [weak self] connection in
                self?.handleConnection(connection)
            }
            listener?.stateUpdateHandler = { [weak self] state in
                Task { @MainActor in
                    self?.isRunning = (state == .ready)
                }
            }
            listener?.start(queue: .global(qos: .utility))
            writeREADME()
        } catch {
            os_log(.error, log: .default, "[LocalAPIServer] Failed to start: %{public}@", error.localizedDescription)
        }
    }

    /// Stops the server.
    func stop() {
        listener?.cancel()
        listener = nil
        isRunning = false
    }

    // MARK: - Connection handling

    private func handleConnection(_ connection: NWConnection) {
        connection.start(queue: .global(qos: .utility))
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, isComplete, error in
            guard let self, let data, !data.isEmpty else {
                connection.cancel()
                return
            }
            Task { @MainActor in
                self.requestCount += 1
                let response = await self.processRequest(data: data)
                self.sendResponse(response, on: connection)
            }
        }
    }

    private func processRequest(data: Data) async -> HTTPResponse {
        guard let requestStr = String(data: data, encoding: .utf8) else {
            return HTTPResponse(status: 400, body: "{\"error\":\"Bad request\"}")
        }

        let lines = requestStr.components(separatedBy: "\r\n")
        guard let requestLine = lines.first else {
            return HTTPResponse(status: 400, body: "{\"error\":\"Bad request\"}")
        }

        let parts = requestLine.components(separatedBy: " ")
        guard parts.count >= 2 else {
            return HTTPResponse(status: 400, body: "{\"error\":\"Bad request\"}")
        }

        let method = parts[0]
        let path = parts[1]

        return await routeRequest(method: method, path: path, body: extractBody(from: requestStr))
    }

    private func routeRequest(method: String, path: String, body: String?) async -> HTTPResponse {
        if method == "GET" && path == "/sessions" {
            return await handleGetSessions()
        }
        if method == "GET", let id = extractSessionID(from: path, suffix: "/tally") {
            return await handleGetTally(sessionID: id)
        }
        if method == "GET", path.contains("/export") {
            let pathWithoutQuery = path.components(separatedBy: "?").first ?? path
            if let id = extractSessionID(from: pathWithoutQuery, suffix: "/export") {
                let format = path.contains("format=json") ? "json" : "csv"
                return await handleExport(sessionID: id, format: format)
            }
        }
        if method == "POST", let id = extractSessionID(from: path, suffix: "/markers") {
            return await handleAddMarker(sessionID: id, body: body)
        }
        return HTTPResponse(status: 404, body: "{\"error\":\"Not found\"}")
    }

    // MARK: - Route handlers

    private func handleGetSessions() async -> HTTPResponse {
        guard let storage else {
            return HTTPResponse(status: 500, body: "{\"error\":\"Storage not available\"}")
        }
        do {
            let sessions = try await storage.fetchAllSessions()
            let items = sessions.map { s -> [String: Any] in
                [
                    "id": s.id.uuidString,
                    "name": s.name,
                    "markerCount": s.markers.count,
                    "modifiedAt": ISO8601DateFormatter().string(from: s.modifiedAt)
                ]
            }
            let data = try JSONSerialization.data(withJSONObject: items)
            return HTTPResponse(status: 200, body: String(data: data, encoding: .utf8) ?? "[]")
        } catch {
            return HTTPResponse(status: 500, body: "{\"error\":\"\(error.localizedDescription)\"}")
        }
    }

    private func handleGetTally(sessionID: UUID) async -> HTTPResponse {
        guard let storage else {
            return HTTPResponse(status: 500, body: "{\"error\":\"Storage not available\"}")
        }
        do {
            let sessions = try await storage.fetchAllSessions()
            guard let session = sessions.first(where: { $0.id == sessionID }) else {
                return HTTPResponse(status: 404, body: "{\"error\":\"Session not found\"}")
            }
            var tallies: [String: Int] = [:]
            for marker in session.markers {
                tallies[marker.objectType.name, default: 0] += 1
            }
            let result: [String: Any] = [
                "sessionID": session.id.uuidString,
                "sessionName": session.name,
                "tallies": tallies,
                "total": session.markers.count
            ]
            let data = try JSONSerialization.data(withJSONObject: result)
            return HTTPResponse(status: 200, body: String(data: data, encoding: .utf8) ?? "{}")
        } catch {
            return HTTPResponse(status: 500, body: "{\"error\":\"\(error.localizedDescription)\"}")
        }
    }

    private func handleExport(sessionID: UUID, format: String) async -> HTTPResponse {
        guard let storage else {
            return HTTPResponse(status: 500, body: "{\"error\":\"Storage not available\"}")
        }
        do {
            let sessions = try await storage.fetchAllSessions()
            guard let session = sessions.first(where: { $0.id == sessionID }) else {
                return HTTPResponse(status: 404, body: "{\"error\":\"Session not found\"}")
            }
            let service = ExportService()
            let data: Data
            let contentType: String
            if format == "json" {
                data = try service.exportJSON(session: session)
                contentType = "application/json"
            } else {
                data = try service.exportCSV(session: session)
                contentType = "text/csv"
            }
            return HTTPResponse(status: 200, body: String(data: data, encoding: .utf8) ?? "",
                                contentType: contentType)
        } catch {
            return HTTPResponse(status: 500, body: "{\"error\":\"\(error.localizedDescription)\"}")
        }
    }

    private func handleAddMarker(sessionID: UUID, body: String?) async -> HTTPResponse {
        guard let storage, let body else {
            return HTTPResponse(status: 400, body: "{\"error\":\"Missing body\"}")
        }
        do {
            guard let bodyData = body.data(using: .utf8),
                  let json = try JSONSerialization.jsonObject(with: bodyData) as? [String: Any],
                  let x = json["x"] as? Double,
                  let y = json["y"] as? Double,
                  let typeName = json["objectType"] as? String else {
                return HTTPResponse(status: 400, body: "{\"error\":\"Invalid body\"}")
            }
            let sessions = try await storage.fetchAllSessions()
            guard let session = sessions.first(where: { $0.id == sessionID }) else {
                return HTTPResponse(status: 404, body: "{\"error\":\"Session not found\"}")
            }
            guard let objectType = session.objectTypes.first(where: { $0.name == typeName }) else {
                return HTTPResponse(status: 400, body: "{\"error\":\"Object type not found\"}")
            }
            let marker = CountMarker(
                normalizedX: x.clamped(to: 0...1),
                normalizedY: y.clamped(to: 0...1),
                objectType: objectType,
                session: session
            )
            session.markers.append(marker)
            session.modifiedAt = Date()
            try await storage.save(session)
            return HTTPResponse(status: 201, body: "{\"id\":\"\(marker.id.uuidString)\"}")
        } catch {
            return HTTPResponse(status: 500, body: "{\"error\":\"\(error.localizedDescription)\"}")
        }
    }

    // MARK: - Response sending

    private func sendResponse(_ response: HTTPResponse, on connection: NWConnection) {
        let httpResponse = """
        HTTP/1.1 \(response.status) \(response.statusText)\r\n\
        Content-Type: \(response.contentType); charset=utf-8\r\n\
        Content-Length: \(response.body.utf8.count)\r\n\
        Access-Control-Allow-Origin: *\r\n\
        Connection: close\r\n\
        \r\n\
        \(response.body)
        """
        guard let data = httpResponse.data(using: .utf8) else {
            connection.cancel()
            return
        }
        connection.send(content: data, completion: .contentProcessed { _ in
            connection.cancel()
        })
    }

    // MARK: - Helpers

    private func extractSessionID(from path: String, suffix: String) -> UUID? {
        let prefix = "/sessions/"
        guard path.hasPrefix(prefix) else { return nil }
        let rest = String(path.dropFirst(prefix.count))
        let uuidStr = rest.hasSuffix(suffix) ? String(rest.dropLast(suffix.count)) : rest
        return UUID(uuidString: uuidStr)
    }

    private func extractBody(from request: String) -> String? {
        let parts = request.components(separatedBy: "\r\n\r\n")
        return parts.count > 1 ? parts[1] : nil
    }

    private func writeREADME() {
        let readme = """
        # OpenCount Local REST API

        The local API server is running on http://127.0.0.1:47200

        ## Endpoints

        GET  /sessions                        — List all sessions
        GET  /sessions/{id}/tally             — Get tally for a session
        POST /sessions/{id}/markers           — Add a marker (body: {"objectType":"name","x":0.5,"y":0.5})
        GET  /sessions/{id}/export?format=csv — Export session as CSV
        GET  /sessions/{id}/export?format=json — Export session as JSON

        This server binds only to localhost and is never exposed to external networks.
        """
        let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("README-API.md")
        try? readme.write(to: url, atomically: true, encoding: .utf8)
    }
}

// MARK: - HTTPResponse

private struct HTTPResponse {
    let status: Int
    let body: String
    var contentType: String = "application/json"

    var statusText: String {
        switch status {
        case 200: return "OK"
        case 201: return "Created"
        case 400: return "Bad Request"
        case 404: return "Not Found"
        case 500: return "Internal Server Error"
        default: return "Unknown"
        }
    }
}

// MARK: - Comparable clamped helper

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
