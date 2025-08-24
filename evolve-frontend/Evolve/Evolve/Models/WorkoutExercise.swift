import Foundation

struct WorkoutExercise: Codable, Identifiable, Hashable {
    let id: UUID
    // let workout: UUID? // Workout ID, if sent by backend when nested. Usually not needed if this is part of a Workout object.
    //                     // WorkoutExerciseSerializer uses fields = '__all__', so workout (FK ID) might be included.
    //                     // Let's assume it's not directly used/needed by client if fetched as part of Workout. Can add if required.
    let exercise: Exercise
    var sets: Int?
    var reps: Int?
    var weight: Int?
    let equipment: String?
    var order: Int
    let time: String?
    var isCompleted: Bool = false
} 