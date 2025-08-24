import Foundation

struct Workout: Codable, Identifiable, Hashable {
    let id: UUID
    let name: String
    let description: String?
    let duration: String
    let createdAt: String
    let updatedAt: String
    var workoutexercises: [WorkoutExercise]

    enum CodingKeys: String, CodingKey {
        case id, name, description, duration, workoutexercises
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
} 
