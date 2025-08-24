import Foundation

struct AppUserEquipment: Codable, Hashable {
    let user: String // User ID
    let availableEquipment: [String]

    enum CodingKeys: String, CodingKey {
        case user
        case availableEquipment = "available_equipment"
    }
} 