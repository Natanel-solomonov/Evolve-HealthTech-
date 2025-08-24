import Foundation

// Assuming Exercise Codable struct is defined elsewhere.
// struct Exercise: Codable, Identifiable { ... }

// Request struct for generating a workout
struct GenerateWorkoutRequest: Codable {
    let duration: Int // e.g., minutes
    let targetMuscles: [String]
    let experienceLevel: String
    let workoutCategory: String
    let availableEquipment: [String]?
    // Ensure CodingKeys are used if Swift properties are camelCase and JSON is snake_case
    // Or rely on AuthenticatedHTTPClient's encoder strategy
    private enum CodingKeys: String, CodingKey {
        case duration
        case targetMuscles = "target_muscles"
        case experienceLevel = "experience_level"
        case workoutCategory = "workout_category"
        case availableEquipment = "available_equipment"
    }
}

// Response struct for a generated workout - structure depends on what OpenAI returns via the backend.
// This is a placeholder; adjust according to actual backend response from /generate-workout/.
struct GeneratedWorkoutResponse: Codable {
    // Example properties - replace with actual fields
    let name: String?
    let description: String?
    let estimatedDurationMinutes: Int?
    let exercises: [GeneratedExerciseDetail]?
}

struct GeneratedExerciseDetail: Codable {
    // Example properties
    let exerciseId: String? // If backend links to existing Exercise UUIDs
    let name: String
    let sets: Int?
    let reps: String? // e.g., "8-12" or "15"
    let restPeriodSeconds: Int?
    let notes: String?
}


// NetworkError is expected from AuthenticationManager.swift

class ExerciseAPI {

    private let httpClient: AuthenticatedHTTPClient

    init(httpClient: AuthenticatedHTTPClient) {
        self.httpClient = httpClient
    }

    func fetchExercises(completion: @escaping (Result<[Exercise], NetworkError>) -> Void) {
        let endpoint = "/exercises/"
        Task {
            do {
                // Backend ExerciseListView GET is IsAuthenticated
                let exercises: [Exercise] = try await httpClient.request(endpoint: endpoint, method: "GET", requiresAuth: true)
                completion(.success(exercises))
            } catch {
                completion(.failure(error as? NetworkError ?? .custom(message: "Unknown error fetching exercises")))
            }
        }
    }

    // func fetchExercise(id: UUID, completion: @escaping (Result<Exercise, NetworkError>) -> Void) { ... }

    func generateWorkout(requestBody: GenerateWorkoutRequest, completion: @escaping (Result<GeneratedWorkoutResponse, NetworkError>) -> Void) {
        let endpoint = "/generate-workout/"
        Task {
            do {
                // Backend generate_workout POST is IsAuthenticated
                let workoutResponse: GeneratedWorkoutResponse = try await httpClient.request(endpoint: endpoint, method: "POST", body: requestBody, requiresAuth: true)
                completion(.success(workoutResponse))
            } catch {
                completion(.failure(error as? NetworkError ?? .custom(message: "Unknown error generating workout")))
            }
        }
    }
} 