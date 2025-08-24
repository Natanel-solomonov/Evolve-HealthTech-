import Foundation

// MARK: - Request/Response Models

// Helper struct for creating a scheduled activity
struct CreateUserScheduledActivityRequest: Codable {
    let activityId: String // UUID of the Activity template. Will be encoded as activity_id
    let scheduledDate: String // YYYY-MM-DD. Will be encoded as scheduled_date
    let orderInDay: Int?
    let customNotes: String?
    
    enum CodingKeys: String, CodingKey {
        case activityId = "activity_id"
        case scheduledDate = "scheduled_date"
        case orderInDay = "order_in_day"
        case customNotes = "custom_notes"
    }
}

// Helper struct for updating a scheduled activity (e.g., marking complete)
struct UpdateUserScheduledActivityRequest: Codable {
    let isComplete: Bool?
    let customNotes: String?
    
    enum CodingKeys: String, CodingKey {
        case isComplete = "is_complete"
        case customNotes = "custom_notes"
    }
}

// Helper struct for creating an ad-hoc completion log
struct CreateAdhocCompletionLogRequest: Codable {
    let activityId: String? // Optional: if logging completion of an existing Activity template
    let activityNameAtCompletion: String
    let descriptionAtCompletion: String?
    let pointsAwarded: Int
    let userNotesOnCompletion: String?
    let isAdhoc: Bool = true
    
    enum CodingKeys: String, CodingKey {
        case activityId = "activity"
        case activityNameAtCompletion = "activity_name_at_completion"
        case descriptionAtCompletion = "description_at_completion"
        case pointsAwarded = "points_awarded"
        case userNotesOnCompletion = "user_notes_on_completion"
        case isAdhoc = "is_adhoc"
    }
}

// MARK: - Main API Class

/**
 UserActivityAPI provides methods for managing user scheduled activities and completion logs.
 
 ## Key Operations:
 
 ### Marking Activities Complete:
 ```swift
 // Method 1: Using convenience method (recommended)
 let updatedActivity = try await userActivityAPI.markActivityComplete(
     activityId: scheduledActivity.id,
     notes: "Completed 30 minute workout"
 )
 
 // Method 2: Using direct update method
 let updateRequest = UpdateUserScheduledActivityRequest(
     isComplete: true,
     customNotes: "Great workout today!"
 )
 let updatedActivity = try await userActivityAPI.updateScheduledActivity(
     activityId: scheduledActivity.id,
     updateData: updateRequest
 )
 ```
 
 ### Backend Behavior:
 When `isComplete` is set to `true`, the backend automatically:
 1. Sets `completedAt` to the current timestamp
 2. Creates a `UserCompletedLog` record via Django signals
 3. Awards points based on the activity's `defaultPointValue`
 4. Returns the updated `UserScheduledActivity` object
 
 ### Error Handling:
 Always wrap calls in do-catch blocks to handle potential network errors:
 ```swift
 do {
     let completed = try await userActivityAPI.markActivityComplete(activityId: activity.id)
     // Handle success - activity is now marked complete
     print("Activity completed at: \(completed.completedAt ?? "unknown")")
 } catch let error as NetworkError {
     // Handle specific network errors
     switch error {
     case .unauthorized:
         // Handle auth error
     case .serverError(let statusCode, _):
         // Handle server errors
     default:
         // Handle other errors
     }
 } catch {
     // Handle unexpected errors
 }
 ```
 */
class UserActivityAPI {

    private let httpClient: AuthenticatedHTTPClient

    init(httpClient: AuthenticatedHTTPClient) {
        self.httpClient = httpClient
    }

    // MARK: - User Scheduled Activities Endpoints

    func fetchScheduledActivities(
        scheduledDate: String? = nil, // YYYY-MM-DD
        startDate: String? = nil,     // YYYY-MM-DD
        endDate: String? = nil,       // YYYY-MM-DD
        completion: @escaping (Result<[UserScheduledActivity], NetworkError>) -> Void
    ) {
        var queryItems = [String: String]()
        if let scheduledDate = scheduledDate {
            queryItems["scheduled_date"] = scheduledDate
        }
        if let startDate = startDate, let endDate = endDate {
            queryItems["start_date"] = startDate
            queryItems["end_date"] = endDate
        }

        let endpoint = "/user-schedule/"
        var urlComponents = URLComponents(string: endpoint)
        if !queryItems.isEmpty {
            urlComponents?.queryItems = queryItems.map { URLQueryItem(name: $0.key, value: $0.value) }
        }
        
        guard let finalEndpoint = urlComponents?.string else {
            completion(.failure(.invalidURL))
            return
        }

        Task {
            do {
                let activities: [UserScheduledActivity] = try await httpClient.request(endpoint: finalEndpoint, method: "GET", requiresAuth: true)
                completion(.success(activities))
            } catch {
                completion(.failure(error as? NetworkError ?? .custom(message: "Unknown error fetching scheduled activities")))
            }
        }
    }

    // MARK: - Async/Await Methods

    /// Fetch scheduled activities using async/await
    func fetchScheduledActivities(
        scheduledDate: String? = nil,
        startDate: String? = nil,
        endDate: String? = nil
    ) async throws -> [UserScheduledActivity] {
        var queryItems = [String: String]()
        if let scheduledDate = scheduledDate {
            queryItems["scheduled_date"] = scheduledDate
        }
        if let startDate = startDate, let endDate = endDate {
            queryItems["start_date"] = startDate
            queryItems["end_date"] = endDate
        }

        let endpoint = "/user-schedule/"
        var urlComponents = URLComponents(string: endpoint)
        if !queryItems.isEmpty {
            urlComponents?.queryItems = queryItems.map { URLQueryItem(name: $0.key, value: $0.value) }
        }
        
        guard let finalEndpoint = urlComponents?.string else {
            throw NetworkError.invalidURL
        }

        return try await httpClient.request(endpoint: finalEndpoint, method: "GET", requiresAuth: true)
    }

    /// Create a scheduled activity
    func createScheduledActivity(activityData: CreateUserScheduledActivityRequest) async throws -> UserScheduledActivity {
        return try await httpClient.request(endpoint: "/user-schedule/", method: "POST", body: activityData, requiresAuth: true)
    }

    /// Update a scheduled activity
    func updateScheduledActivity(
        activityId: UUID,
        updateData: UpdateUserScheduledActivityRequest
    ) async throws -> UserScheduledActivity {
        return try await httpClient.request(
            endpoint: "/user-schedule/\(activityId.uuidString.lowercased())/", 
            method: "PATCH", 
            body: updateData, 
            requiresAuth: true
        )
    }

    /// Convenience method to mark a scheduled activity as complete
    /// - Parameters:
    ///   - activityId: UUID of the UserScheduledActivity
    ///   - notes: Optional completion notes
    /// - Returns: Updated UserScheduledActivity with completion status
    /// - Note: Backend automatically sets completedAt timestamp and creates UserCompletedLog
    func markActivityComplete(activityId: UUID, notes: String? = nil) async throws -> UserScheduledActivity {
        let updateData = UpdateUserScheduledActivityRequest(
            isComplete: true,
            customNotes: notes
        )
        let updatedActivity = try await updateScheduledActivity(activityId: activityId, updateData: updateData)
        
        // Post notification that an activity was completed so other views can refresh
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: NSNotification.Name("ActivityCompleted"), object: nil)
        }
        
        return updatedActivity
    }

    /// Convenience method to mark a scheduled activity as incomplete
    /// - Parameters:
    ///   - activityId: UUID of the UserScheduledActivity
    ///   - notes: Optional notes explaining why activity was marked incomplete
    /// - Returns: Updated UserScheduledActivity with completion status
    func markActivityIncomplete(activityId: UUID, notes: String? = nil) async throws -> UserScheduledActivity {
        let updateData = UpdateUserScheduledActivityRequest(
            isComplete: false,
            customNotes: notes
        )
        return try await updateScheduledActivity(activityId: activityId, updateData: updateData)
    }

    /// Delete a scheduled activity
    func deleteScheduledActivity(activityId: UUID) async throws {
        let (_, httpResponse) = try await httpClient.requestData(
            endpoint: "/user-schedule/\(activityId.uuidString.lowercased())/", 
            method: "DELETE", 
            requiresAuth: true
        )
        guard (200...299).contains(httpResponse.statusCode) else {
            throw NetworkError.serverError(statusCode: httpResponse.statusCode, data: nil)
        }
    }

    // MARK: - Legacy Methods (for backward compatibility)

    func createScheduledActivity(
        activityData: CreateUserScheduledActivityRequest,
        completion: @escaping (Result<UserScheduledActivity, NetworkError>) -> Void
    ) {
        Task {
            do {
                let activity = try await createScheduledActivity(activityData: activityData)
                completion(.success(activity))
            } catch {
                completion(.failure(error as? NetworkError ?? .custom(message: "Unknown error creating scheduled activity")))
            }
        }
    }

    func updateScheduledActivity(
        activityId: String, // UUID of the UserScheduledActivity
        updateData: UpdateUserScheduledActivityRequest,
        completion: @escaping (Result<UserScheduledActivity, NetworkError>) -> Void
    ) {
        guard let uuid = UUID(uuidString: activityId) else {
            completion(.failure(.custom(message: "Invalid UUID format")))
            return
        }
        
        Task {
            do {
                let activity = try await updateScheduledActivity(activityId: uuid, updateData: updateData)
                completion(.success(activity))
            } catch {
                completion(.failure(error as? NetworkError ?? .custom(message: "Unknown error updating scheduled activity")))
            }
        }
    }

    func deleteScheduledActivity(
        activityId: String, // UUID of the UserScheduledActivity
        completion: @escaping (Result<Void, NetworkError>) -> Void
    ) {
        guard let uuid = UUID(uuidString: activityId) else {
            completion(.failure(.custom(message: "Invalid UUID format")))
            return
        }
        
        Task {
            do {
                try await deleteScheduledActivity(activityId: uuid)
                completion(.success(()))
            } catch {
                completion(.failure(error as? NetworkError ?? .custom(message: "Unknown error deleting scheduled activity")))
            }
        }
    }

    // MARK: - User Completion Logs Endpoints

    /// Fetch completion logs
    func fetchCompletionLogs() async throws -> [UserCompletedLog] {
        return try await httpClient.request(endpoint: "/user-completion-logs/", method: "GET", requiresAuth: true)
    }

    /// Create an adhoc completion log (for activities completed outside of schedule)
    /// - Parameter logData: Request containing activity details and completion info
    /// - Returns: Created UserCompletedLog with isAdhoc = true
    func createAdhocCompletionLog(logData: CreateAdhocCompletionLogRequest) async throws -> UserCompletedLog {
        let createdLog: UserCompletedLog = try await httpClient.request(endpoint: "/user-completion-logs/", method: "POST", body: logData, requiresAuth: true)
        
        // Post notification that an activity was completed so other views can refresh
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: NSNotification.Name("ActivityCompleted"), object: nil)
        }
        
        return createdLog
    }

    // MARK: - Legacy Methods for Completion Logs

    func fetchCompletionLogs(
        completion: @escaping (Result<[UserCompletedLog], NetworkError>) -> Void
    ) {
        Task {
            do {
                let logs = try await fetchCompletionLogs()
                completion(.success(logs))
            } catch {
                completion(.failure(error as? NetworkError ?? .custom(message: "Unknown error fetching completion logs")))
            }
        }
    }

    func createAdhocCompletionLog(
        logData: CreateAdhocCompletionLogRequest,
        completion: @escaping (Result<UserCompletedLog, NetworkError>) -> Void
    ) {
        Task {
            do {
                let log = try await createAdhocCompletionLog(logData: logData)
                completion(.success(log))
            } catch {
                completion(.failure(error as? NetworkError ?? .custom(message: "Unknown error creating adhoc completion log")))
            }
        }
    }
} 
