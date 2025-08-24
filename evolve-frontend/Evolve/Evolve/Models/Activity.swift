import Foundation

struct Activity: Codable, Identifiable, Hashable {
    let id: UUID
    let name: String
    let description: String
    let defaultPointValue: Int
    let category: [String]
    let activityType: String?
    let associatedWorkout: Workout?
    let associatedReading: ReadingContentModel?
    let isArchived: Bool
    
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case description
        case defaultPointValue = "default_point_value"
        case category
        case activityType = "activity_type"
        case associatedWorkout = "associated_workout"
        case associatedReading = "associated_reading"
        case isArchived = "is_archived"
    }
} 
