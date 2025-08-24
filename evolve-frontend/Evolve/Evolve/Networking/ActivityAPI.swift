import Foundation

// Assuming Activity Codable struct is defined elsewhere.
// struct Activity: Codable, Identifiable { ... }

// NetworkError is expected from AuthenticationManager.swift

class ActivityAPI {

    private let httpClient: AuthenticatedHTTPClient

    init(httpClient: AuthenticatedHTTPClient) {
        self.httpClient = httpClient
    }

    func fetchActivities(completion: @escaping (Result<[Activity], NetworkError>) -> Void) {
        let endpoint = "/activities/"
        
        Task {
            do {
                // Backend ActivityListView GET is IsAuthenticated
                let activities: [Activity] = try await httpClient.request(endpoint: endpoint, method: "GET", requiresAuth: true)
                completion(.success(activities))
            } catch {
                completion(.failure(error as? NetworkError ?? .custom(message: "Unknown error fetching activities")))
            }
        }
    }
    
    // If needed, add fetchActivity(id: UUID, ...) for ActivityDetailView (/activities/<uuid:pk>/)
    // func fetchActivity(id: UUID, completion: @escaping (Result<Activity, NetworkError>) -> Void) {
    //     let endpoint = "/activities/\\(id.uuidString)/"
    //     Task {
    //         do {
    //             // Backend ActivityDetailView GET is IsAuthenticated
    //             let activity: Activity = try await httpClient.request(endpoint: endpoint, method: "GET", requiresAuth: true)
    //             completion(.success(activity))
    //         } catch {
    //             completion(.failure(error as? NetworkError ?? .custom(message: "Unknown error fetching activity")))
    //         }
    //     }
    // }
}
