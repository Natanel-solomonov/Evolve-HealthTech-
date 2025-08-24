import Foundation

struct Shortcut: Codable, Identifiable, Hashable {
    let id: UUID
    let name: String
    let category: String
    let actionIdentifier: String
    let description: String?

    enum CodingKeys: String, CodingKey {
        case id, name, category, description
        case actionIdentifier = "action_identifier"
    }
} 