import Foundation

struct ExerciseTransferCoefficient: Codable, Identifiable, Hashable {
    let id: UUID
    let fromExercise: Exercise
    let toExercise: Exercise
    let coefficient: Double
    let derivationMethod: String
    let notes: String?
    let createdAt: String
    let updatedAt: String

    enum CodingKeys: String, CodingKey {
        case id, coefficient, notes
        case fromExercise = "from_exercise"
        case toExercise = "to_exercise"
        case derivationMethod = "derivation_method"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
} 