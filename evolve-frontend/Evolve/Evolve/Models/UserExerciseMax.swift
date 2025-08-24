import Foundation

struct UserExerciseMax: Codable, Identifiable, Hashable {
    let id: UUID
    let user: String // User ID
    let exercise: Exercise
    let oneRepMax: Double
    let dateRecorded: String
    let previousMaxes: [PreviousMax]?
    let unit: String
    let notes: String?

    enum CodingKeys: String, CodingKey {
        case id, user, exercise, unit, notes
        case oneRepMax = "one_rep_max"
        case dateRecorded = "date_recorded"
        case previousMaxes = "previous_maxes"
    }
}

struct PreviousMax: Codable, Hashable {
    let value: Double
    let date: String
} 