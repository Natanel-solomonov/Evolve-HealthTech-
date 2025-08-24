import Foundation

// Assuming Workout Codable struct is defined elsewhere and matches WorkoutSerializer.
// struct Workout: Codable, Identifiable { ... }

// NetworkError is expected from AuthenticationManager.swift

class WorkoutAPI {

    private let httpClient: AuthenticatedHTTPClient

    init(httpClient: AuthenticatedHTTPClient) {
        self.httpClient = httpClient
    }

    func fetchWorkouts(completion: @escaping (Result<[Workout], NetworkError>) -> Void) {
        let endpoint = "/workouts/"
        
        Task {
            do {
                // Backend WorkoutListView GET is IsAuthenticated
                let workouts: [Workout] = try await httpClient.request(endpoint: endpoint, method: "GET", requiresAuth: true)
                completion(.success(workouts))
            } catch {
                completion(.failure(error as? NetworkError ?? .custom(message: "Unknown error fetching workouts")))
            }
        }
    }
    
    func fetchWorkoutById(id: UUID) async throws -> Workout {
        return try await httpClient.request(endpoint: "/workouts/\(id.uuidString)/", method: "GET", requiresAuth: true)
    }
    
    // Note: Workout generation is handled in ExerciseAPI.swift via generateWorkout method.
} 