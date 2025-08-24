import Foundation

class JournalEntryAPI {
    private let httpClient: AuthenticatedHTTPClient
    
    init(httpClient: AuthenticatedHTTPClient) {
        self.httpClient = httpClient
    }
    
    // MARK: - Fetch Journal Entries
    func fetchJournalEntries() async throws -> [JournalEntry] {
        return try await httpClient.request(
            endpoint: "/journal-entries/",
            method: "GET",
            requiresAuth: true
        )
    }
    
    // MARK: - Create Journal Entry
    func createJournalEntry(request: CreateJournalEntryRequest) async throws -> JournalEntry {
        return try await httpClient.request(
            endpoint: "/journal-entries/",
            method: "POST",
            body: request,
            requiresAuth: true
        )
    }
    
    // MARK: - Fetch Journal Entry by ID
    func fetchJournalEntry(id: UUID) async throws -> JournalEntry {
        return try await httpClient.request(
            endpoint: "/journal-entries/\(id.uuidString)/",
            method: "GET",
            requiresAuth: true
        )
    }
    
    // MARK: - Update Journal Entry
    func updateJournalEntry(id: UUID, request: UpdateJournalEntryRequest) async throws -> JournalEntry {
        return try await httpClient.request(
            endpoint: "/journal-entries/\(id.uuidString)/",
            method: "PATCH",
            body: request,
            requiresAuth: true
        )
    }
    
    // MARK: - Delete Journal Entry
    func deleteJournalEntry(id: UUID) async throws {
        let _: String? = try await httpClient.request(
            endpoint: "/journal-entries/\(id.uuidString)/",
            method: "DELETE",
            requiresAuth: true
        )
    }
}

// MARK: - Convenience Methods
extension JournalEntryAPI {
    /// Create a journal entry with current date and time
    func createJournalEntry(title: String, content: String) async throws -> JournalEntry {
        let now = Date()
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HH:mm:ss"
        
        let request = CreateJournalEntryRequest(
            title: title,
            content: content,
            dateCreated: dateFormatter.string(from: now),
            timeCreated: timeFormatter.string(from: now)
        )
        
        return try await createJournalEntry(request: request)
    }
} 