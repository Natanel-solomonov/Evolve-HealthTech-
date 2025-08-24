import Foundation

struct AppUserFatigueModel: Codable, Identifiable, Hashable {
    let id: UUID
    let user: String? // User ID, nullable in model
    let dateRecorded: String

    // Muscle group fatigue levels
    let quadriceps: Double
    let abdominals: Double
    let abductors: Double
    let adductors: Double
    let biceps: Double
    let calves: Double
    let cardiovascular: Double
    let chest: Double
    let forearms: Double
    let fullBody: Double
    let glutes: Double
    let hamstrings: Double
    let lats: Double
    let lowerBack: Double
    let middleBack: Double
    let neck: Double
    let shoulders: Double
    let traps: Double
    let triceps: Double
    
    enum CodingKeys: String, CodingKey {
        case id, user, quadriceps, abdominals, abductors, adductors, biceps, calves,
             cardiovascular, chest, forearms, glutes, hamstrings, lats, neck,
             shoulders, traps, triceps
        case dateRecorded = "date_recorded"
        case fullBody = "full_body"
        case lowerBack = "lower_back"
        case middleBack = "middle_back"
    }
} 