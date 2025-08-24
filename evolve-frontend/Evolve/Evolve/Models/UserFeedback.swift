import Foundation

struct UserFeedback: Codable, Identifiable, Hashable {
    let id: Int
    let user: String // User ID
    let feedback: String
    let createdAt: String
    let updatedAt: String

    enum CodingKeys: String, CodingKey {
        case id, user, feedback
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
} 