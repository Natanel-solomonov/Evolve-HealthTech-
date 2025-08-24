import Foundation

struct CardioWorkout: Codable, Identifiable, Hashable {
    let id: UUID
    let name: String
    let cardioType: String
    let duration: String // DurationField from Django is serialized as string "HH:MM:SS"
    let intensity: String
    let isTreadmill: Bool
    let isOutdoor: Bool
    let createdAt: String
    let updatedAt: String

    enum CodingKeys: String, CodingKey {
        case id, name, duration, intensity
        case cardioType = "cardio_type"
        case isTreadmill = "is_treadmill"
        case isOutdoor = "is_outdoor"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
} 