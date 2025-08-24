import Foundation

// MARK: - JournalEntry Model
struct JournalEntry: Codable, Identifiable {
    let id: UUID
    let user: String? // User phone number from backend
    let title: String
    let content: String
    let dateCreated: String // "YYYY-MM-DD" format
    let timeCreated: String // "HH:MM:SS" format
    let createdAt: String // Full timestamp
    let updatedAt: String // Full timestamp
    
    enum CodingKeys: String, CodingKey {
        case id, user, title, content
        case dateCreated = "date_created"
        case timeCreated = "time_created"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

// MARK: - JournalEntry Request/Response Models
struct CreateJournalEntryRequest: Codable {
    let title: String
    let content: String
    let dateCreated: String?
    let timeCreated: String?
    
    enum CodingKeys: String, CodingKey {
        case title, content
        case dateCreated = "date_created"
        case timeCreated = "time_created"
    }
    
    init(title: String, content: String, dateCreated: String? = nil, timeCreated: String? = nil) {
        self.title = title
        self.content = content
        self.dateCreated = dateCreated
        self.timeCreated = timeCreated
    }
}

struct UpdateJournalEntryRequest: Codable {
    let title: String?
    let content: String?
    let dateCreated: String?
    let timeCreated: String?
    
    enum CodingKeys: String, CodingKey {
        case title, content
        case dateCreated = "date_created"
        case timeCreated = "time_created"
    }
} 