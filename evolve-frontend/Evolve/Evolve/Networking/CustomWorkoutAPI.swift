import Foundation

struct GenerateCustomWorkoutRequest: Codable {
    let muscleGroups: [String]
    let duration: Int
    let intensity: String
    let includeCardio: Bool
    let scheduleForToday: Bool

    enum CodingKeys: String, CodingKey {
        case muscleGroups = "muscle_groups"
        case duration, intensity
        case includeCardio = "include_cardio"
        case scheduleForToday = "schedule_for_today"
    }
}

struct GenerateCustomWorkoutResponse: Codable {
    let workoutId: UUID
    let activityId: UUID
    let scheduledActivityId: UUID?
    let cardioActivityId: UUID?
    let cardioScheduledId: UUID?

    enum CodingKeys: String, CodingKey {
        case workoutId = "workout_id"
        case activityId = "activity_id"
        case scheduledActivityId = "scheduled_activity_id"
        case cardioActivityId = "cardio_activity_id"
        case cardioScheduledId = "cardio_scheduled_id"
    }
}

class CustomWorkoutAPI {
    private let httpClient: AuthenticatedHTTPClient
    init(httpClient: AuthenticatedHTTPClient) {
        self.httpClient = httpClient
    }

    func generateCustomWorkout(request: GenerateCustomWorkoutRequest) async throws -> GenerateCustomWorkoutResponse {
        return try await httpClient.request(endpoint: "/custom-workouts/", method: "POST", body: request, requiresAuth: true)
    }
} 