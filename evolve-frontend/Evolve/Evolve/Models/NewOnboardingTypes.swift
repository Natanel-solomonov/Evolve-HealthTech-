import Foundation
import HealthKit

// MARK: - New Health Profile (Codable)
/// Stores user's health information collected during onboarding
struct NewHealthProfile: Codable {
    var dateOfBirth: Date?
    var biologicalSex: HKBiologicalSex?
    var height: Double? // in meters
    var weight: Double? // in kilograms
    
    // Computed property for age
    var age: Int? {
        guard let dob = dateOfBirth else { return nil }
        let calendar = Calendar.current
        let ageComponents = calendar.dateComponents([.year], from: dob, to: Date())
        return ageComponents.year
    }
    
    // Custom encoding/decoding for HKBiologicalSex
    enum CodingKeys: String, CodingKey {
        case dateOfBirth
        case biologicalSexRaw
        case height
        case weight
    }
    
    init() {}
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        dateOfBirth = try container.decodeIfPresent(Date.self, forKey: .dateOfBirth)
        if let sexRaw = try container.decodeIfPresent(Int.self, forKey: .biologicalSexRaw) {
            biologicalSex = HKBiologicalSex(rawValue: sexRaw)
        }
        height = try container.decodeIfPresent(Double.self, forKey: .height)
        weight = try container.decodeIfPresent(Double.self, forKey: .weight)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(dateOfBirth, forKey: .dateOfBirth)
        try container.encodeIfPresent(biologicalSex?.rawValue, forKey: .biologicalSexRaw)
        try container.encodeIfPresent(height, forKey: .height)
        try container.encodeIfPresent(weight, forKey: .weight)
    }
}

// MARK: - New Goal Detail Question (Codable)
/// Represents a follow-up question for a selected goal
struct NewGoalDetailQuestion: Identifiable, Codable {
    let id: UUID
    let goalId: UUID
    let goalTitle: String
    let questionText: String
    var suggestedResponses: [String]
    var responseText: String
    
    init(goalId: UUID, goalTitle: String, questionText: String, suggestedResponses: [String]) {
        self.id = UUID()
        self.goalId = goalId
        self.goalTitle = goalTitle
        self.questionText = questionText
        self.suggestedResponses = suggestedResponses
        self.responseText = ""
    }
}

// Type aliases to use the legacy types where needed
//typealias HealthProfile = NewHealthProfile
//typealias GoalDetailQuestion = NewGoalDetailQuestion 
