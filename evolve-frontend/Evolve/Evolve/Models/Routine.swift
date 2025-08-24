import Foundation

struct RoutineStep: Codable, Identifiable, Hashable {
    let id: UUID
    let name: String
    let icon: String
    let order: Int
}

struct Routine: Codable, Identifiable, Hashable {
    let id: UUID
    let user: SimpleAppUser
    let title: String
    let description: String
    let scheduledTime: String?
    let createdAt: String
    let updatedAt: String
    let steps: [RoutineStep]

    enum CodingKeys: String, CodingKey {
        case id
        case user
        case title
        case description
        case scheduledTime = "scheduled_time"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case steps
    }
} 