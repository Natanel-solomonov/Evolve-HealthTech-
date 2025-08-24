import Foundation

struct FriendGroupEvent: Codable, Identifiable, Hashable {
    let id: UUID
    let friendGroup: Int
    let user: SimpleAppUser? // User might be null if event is system-generated or user deleted
    let eventType: String
    let timestamp: Date
    // Assuming UserCompletedLog is defined elsewhere and is Codable
    let userCompletedLog: UserCompletedLog?

    // Map snake_case JSON keys to camelCase Swift properties
    enum CodingKeys: String, CodingKey {
        case id
        case friendGroup = "friend_group"
        case user
        case eventType = "event_type"
        case timestamp
        case userCompletedLog = "completed_activity_log" // Explicit map needed
    }

    // Implement Hashable
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    // Implement Equatable based on id for Identifiable conformance
    static func == (lhs: FriendGroupEvent, rhs: FriendGroupEvent) -> Bool {
        lhs.id == rhs.id
    }
}
