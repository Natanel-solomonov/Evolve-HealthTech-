import Foundation

// Response struct after logging an emotion.
// This should match the fields from AppUserCurrentEmotionSerializer or AppUserDailyEmotionSerializer.
struct LoggedEmotionResponse: Codable {
    let id: Int
    let feeling: String
    let causes: [String]
    let impacts: [String]
    let trackedAt: String // From backend's tracked_at
    let date: String?      // From backend's date (only for daily emotions)

    private enum CodingKeys: String, CodingKey {
        case id, feeling, causes, impacts
        case trackedAt = "tracked_at"
        case date
    }
}

// NetworkError is expected from AuthenticationManager.swift

// MARK: - Main API Class

class EmotionAPI {
    
    private let httpClient: AuthenticatedHTTPClient

    // To use this class as a singleton, consider a shared instance approach similar to other APIs
    // e.g., init with AuthenticationManager.shared.httpClient
    init(httpClient: AuthenticatedHTTPClient) {
        self.httpClient = httpClient
    }
    
    func logEmotion(
        type: EmotionLogType,
        feeling: String,
        causes: [String],
        impacts: [String],
        intensity: Int
    ) async throws -> LoggedEmotionResponse {
        let endpoint = type == .current ? "/current-emotions/" : "/daily-emotions/"
        
        let body = EmotionLogRequest(
            feeling: feeling,
            cause: causes.joined(separator: ", "),
            biggestImpact: impacts.joined(separator: ", "),
            intensity: intensity
        )
        
        // Both /current-emotions/ and /daily-emotions/ POST endpoints are IsAuthenticated
        let loggedEmotion: LoggedEmotionResponse = try await httpClient.request(
            endpoint: endpoint, 
            method: "POST", 
            body: body, 
            requiresAuth: true
        )
        return loggedEmotion
    }
    
    // TODO: Add methods for fetching current/daily emotions if needed.
    // Example for fetching current emotions:
    // func fetchCurrentEmotions(completion: @escaping (Result<[LoggedEmotionResponse], NetworkError>) -> Void) {
    //     Task {
    //         do {
    //             let emotions: [LoggedEmotionResponse] = try await httpClient.request(endpoint: "/current-emotions/", method: "GET", requiresAuth: true)
    //             completion(.success(emotions))
    //         } catch {
    //             completion(.failure(error as? NetworkError ?? .custom(message: "Failed to fetch current emotions")))
    //         }
    //     }
    // }
}

// MARK: - Authentication Manager Extension (If any specific helper was intended here, it can be re-evaluated)
// The original file had this section empty.




