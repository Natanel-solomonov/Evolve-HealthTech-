import Foundation

// AppUser struct is defined in AuthenticationManager.swift and will be used here.
// NetworkError is also expected from AuthenticationManager.swift

class AppUserAPI {

    private let httpClient: AuthenticatedHTTPClient

    init(httpClient: AuthenticatedHTTPClient) {
        self.httpClient = httpClient
    }

    // Fetches user details for a given user ID.
    // This corresponds to the AppUserDetailView in the backend.
    // In the context of fetching the *currently authenticated* user's details,
    // AuthenticationManager.fetchCurrentUserDetails already provides this functionality.
    // This method is more generic if you need to fetch details for any user ID (with permissions).
    func fetchUserDetails(userId: String, completion: @escaping (Result<AppUser, NetworkError>) -> Void) {
        // The endpoint /users/<id>/ requires authentication and proper permissions (IsOwnerOrAdmin).
        let endpoint = "/users/\(userId)/"

        Task {
            do {
                let user: AppUser = try await httpClient.request(endpoint: endpoint, method: "GET", requiresAuth: true)
                completion(.success(user))
            } catch {
                completion(.failure(error as? NetworkError ?? .custom(message: "Unknown error fetching user details")))
            }
        }
    }
    
    // updateUserDetails could be added here if partial updates to AppUser are needed via a specific endpoint.
    // For example, if there was a PATCH /users/<id>/ for certain fields.
    // Currently, AuthenticationManager handles specific updates like onboarding or goals via their dedicated methods.

    // The fetchAppUsers function that fetches all users (/users/) is primarily for admin purposes
    // as per backend permissions (IsAdminUser) unless a phone query param is used (AllowAny).
    // It's generally not directly used by a standard client app to list all users.
    // If a search-by-phone functionality is needed for non-admins, a specific method could be added.
    /*
    func searchUserByPhone(phoneNumber: String, completion: @escaping (Result<[AppUser], NetworkError>) -> Void) {
        let endpoint = "/users/?phone=\(phoneNumber.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")"
        Task {
            do {
                // This endpoint with phone param has AllowAny permission
                let users: [AppUser] = try await httpClient.request(endpoint: endpoint, method: "GET", requiresAuth: false) 
                completion(.success(users))
            } catch {
                completion(.failure(error as? NetworkError ?? .custom(message: "Unknown error searching user by phone")))
            }
        }
    }
    */
    
    // Note: Operations like completing onboarding, updating points, or updating goals are currently managed
    // by methods within AuthenticationManager.swift (e.g., submitOnboardingProfile, updateUserGoals).
    // This AppUserAPI could be expanded if more direct user-related calls are needed outside of AuthenticationManager's scope.

    func fetchUserBMR() async throws -> BMRResponse {
        // Corresponds to the UserBMRView on the backend.
        // The exact URL path should be confirmed in the backend's urls.py.
        let endpoint = "/user/bmr/"
        return try await httpClient.request(endpoint: endpoint, method: "GET", requiresAuth: true)
    }
    
    func completeOnboarding(
        height: Double,
        weight: Double,
        age: Int,
        gender: String,
        activityLevel: String,
        goal: String
    ) {
        // Implementation of completeOnboarding method
    }
} 
