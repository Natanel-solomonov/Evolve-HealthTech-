import Foundation

struct ShortcutAPIService {
    
    private let httpClient: AuthenticatedHTTPClient
    
    init(httpClient: AuthenticatedHTTPClient) {
        self.httpClient = httpClient
    }

    /// Fetches all available shortcuts from the backend.
    func getAvailable() async throws -> [Shortcut] {
        return try await httpClient.request(endpoint: "/shortcuts/", method: "GET", requiresAuth: true)
    }

    /// Adds a shortcut to the user's dashboard.
    @discardableResult
    func add(shortcutId: UUID) async throws -> UserShortcut {
        let payload = ["shortcut_id": shortcutId.uuidString]
        return try await httpClient.request(endpoint: "/user-shortcuts/", method: "POST", body: payload, requiresAuth: true)
    }

    /// Deletes a user's shortcut from their dashboard.
    func delete(userShortcutId: UUID) async throws {
        // The request method returns a Decodable. For a DELETE request that returns
        // no content (204), we expect it to return a specific type or handle emptiness.
        // We'll attempt to decode an empty struct or handle the response differently if needed.
        // Let's assume a successful DELETE might not need a return value, but the request method requires a type.
        // We will use a generic helper struct for responses with no body.
        struct EmptyResponse: Decodable {}
        let _: EmptyResponse = try await httpClient.request(endpoint: "/user-shortcuts/\(userShortcutId.uuidString)/", method: "DELETE", requiresAuth: true)
    }
    
    /// Reorders the user's shortcuts.
    func reorder(orderedIds: [UUID]) async throws -> [UserShortcut] {
        let payload: [String: [String]] = ["ordered_ids": orderedIds.map { $0.uuidString }]
        return try await httpClient.request(endpoint: "/user-shortcuts/reorder/", method: "PUT", body: payload, requiresAuth: true)
    }
} 