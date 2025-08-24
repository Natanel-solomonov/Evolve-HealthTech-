import SwiftUI

struct AppConfig {
    // Configuration switch for testing vs production
    static let useLocalServer = false// Set to false for production
    
    // API Base URLs
    private static let productionURL = "https://evolve-backend-production4701250738638064907896437.up.railway.app/api"
    private static let localURL = "http://172.20.10.8:8000/api"
    
    // Dynamic base URL based on configuration
    static var apiBaseURL: String {
        return useLocalServer ? localURL : productionURL
    }
}

// MARK: - Codable Structs for OTP Flow
struct SendOTPRequest: Codable {
    let phone: String
}

struct SendOTPResponse: Codable {
    let message: String
    let otp_code: String?
}

struct VerifyOTPRequest: Codable {
    let phone: String
    let otp: String
    let firstName: String
    let lastName: String
}

struct VerifyOTPResponse: Codable {
    let message: String
    let access_token: String
    let refresh_token: String
    let user: AppUser // Expects the full AppUser object
}

// MARK: - Codable Structs for Token Refresh
struct RefreshTokenRequest: Codable {
    let refresh: String
}

struct RefreshTokenResponse: Codable {
    let access: String
    let refresh: String? // Handles rotated refresh tokens
}

// MARK: - Codable Struct for Completing Onboarding Profile

// This represents one item in the 'details' array for the goals payload.
struct UserGoalDetailPayload: Codable {
    let goal_categories: [String]
    let text: String
}

struct CompleteOnboardingRequest: Codable {
    let firstName: String
    let lastName: String
    let height: Double
    let birthday: String
    let weight: Double
    let sex: String

    // This nested struct matches the 'goals' object in the request body.
    struct Goals: Codable {
        let goals_general: [String]
        let details: [UserGoalDetailPayload]?
    }
    let goals: Goals?
}

struct CompleteOnboardingResponse: Codable {
    let message: String
    let user: AppUser
}

// MARK: - Codable Structs for User Update
struct AppUserUpdatePayload: Codable {
    var firstName: String?
    var lastName: String?
    var backupEmail: String?
    var info: AppUserInfoUpdatePayload?

    enum CodingKeys: String, CodingKey {
        case firstName = "first_name"
        case lastName = "last_name"
        case backupEmail = "backup_email"
        case info
    }

    init(firstName: String? = nil, lastName: String? = nil, backupEmail: String? = nil, info: AppUserInfoUpdatePayload? = nil) {
        self.firstName = firstName
        self.lastName = lastName
        self.backupEmail = backupEmail
        self.info = info
    }
}

struct AppUserInfoUpdatePayload: Codable {
    let height: Double?
    let birthday: String? // "YYYY-MM-DD"
    let weight: Double?
    let sex: String?

    init(height: Double? = nil, birthday: String? = nil, weight: Double? = nil, sex: String? = nil) {
        self.height = height
        self.birthday = birthday
        self.weight = weight
        self.sex = sex
    }
}

// MARK: - Network Client and Errors
enum NetworkError: Error, Equatable {
    case invalidURL
    case requestFailed(String)
    case invalidResponse
    case decodingError(String)
    case encodingError(String)
    case unauthorized
    case sessionExpired
    case serverError(statusCode: Int, data: Data?)
    case custom(message: String)

    static func == (lhs: NetworkError, rhs: NetworkError) -> Bool {
        switch (lhs, rhs) {
        case (.invalidURL, .invalidURL): return true
        case (.requestFailed(let lMsg), .requestFailed(let rMsg)): return lMsg == rMsg
        case (.invalidResponse, .invalidResponse): return true
        case (.decodingError(let lMsg), .decodingError(let rMsg)): return lMsg == rMsg
        case (.encodingError(let lMsg), .encodingError(let rMsg)): return lMsg == rMsg
        case (.unauthorized, .unauthorized): return true
        case (.sessionExpired, .sessionExpired): return true
        case (.serverError(let lCode, _), .serverError(let rCode, _)): return lCode == rCode
        case (.custom(let lMsg), .custom(let rMsg)): return lMsg == rMsg
        default: return false
        }
    }
}

class AuthenticatedHTTPClient {
    // MARK: - Properties
    private weak var authenticationManager: AuthenticationManager?

    private var apiBaseURLString: String {
        return AppConfig.apiBaseURL
    }

    // Date formatter for handling fractional seconds in ISO8601 dates
    private static let iso8601FractionalSecondsFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSSSSZ"
        formatter.timeZone = TimeZone(secondsFromGMT: 0) // Assume UTC
        return formatter
    }()
    
    // Date formatter for handling ISO8601 dates without fractional seconds
    private static let iso8601StandardFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
        formatter.timeZone = TimeZone(secondsFromGMT: 0) // Assume UTC
        return formatter
    }()
    
    // Custom date decoding strategy that handles multiple ISO8601 formats
    @Sendable
    private static func customDateDecodingStrategy(decoder: Decoder) throws -> Date {
        let container = try decoder.singleValueContainer()
        let dateString = try container.decode(String.self)
        
        // Try fractional seconds format first
        if let date = iso8601FractionalSecondsFormatter.date(from: dateString) {
            return date
        }
        
        // Try standard format without fractional seconds
        if let date = iso8601StandardFormatter.date(from: dateString) {
            return date
        }
        
        // Try ISO8601DateFormatter as fallback
        if let date = ISO8601DateFormatter().date(from: dateString) {
            return date
        }
        
        throw DecodingError.dataCorrupted(
            DecodingError.Context(
                codingPath: decoder.codingPath,
                debugDescription: "Invalid date format: \(dateString)"
            )
        )
    }

    // MARK: - Initialization
    init(authenticationManager: AuthenticationManager) {
        self.authenticationManager = authenticationManager
    }

    // MARK: - Private Request Logic
    private func performRawRequest(
        endpoint: String,
        method: String = "GET",
        body: Encodable? = nil,
        requiresAuth: Bool = true,
        isRetry: Bool = false
    ) async throws -> (Data, HTTPURLResponse) {
        guard let authManager = authenticationManager else {
            print("AuthenticatedHTTPClient: AuthenticationManager is nil.")
            throw NetworkError.custom(message: "AuthenticationManager not available.")
        }

        guard let url = URL(string: apiBaseURLString + endpoint) else {
            throw NetworkError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        // Add headers to identify this as an API request (helps with CSRF exemption)
        request.setValue("XMLHttpRequest", forHTTPHeaderField: "X-Requested-With")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if let body = body {
            do {
                
                let encoder = JSONEncoder()
                encoder.keyEncodingStrategy = .convertToSnakeCase
                request.httpBody = try encoder.encode(body)
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            } catch {
                throw NetworkError.encodingError(error.localizedDescription)
            }
        }

        if requiresAuth {
            if await authManager.authToken == nil && !isRetry {
                 print("AuthenticatedHTTPClient: No auth token for \(url.path), attempting preemptive refresh.")
                 _ = await authManager.refreshAccessToken()
            }
            
            guard let token = await authManager.authToken else {
                print("AuthenticatedHTTPClient: No auth token for \(url.path) after potential refresh. Session likely expired.")
                if await authManager.currentUser != nil {
                    await MainActor.run { authManager.logout() }
                }
                throw NetworkError.sessionExpired
            }
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        let actionDescription = "\(method) request to \(url.path)"
        let authStatus = requiresAuth ? (await authManager.authToken != nil ? "with token \(await authManager.authToken!.prefix(10))..." : "AUTH REQUIRED BUT TOKEN MISSING (Error Case)") : "(no auth required)"
        print("AuthenticatedHTTPClient: Making \(actionDescription) \(authStatus).")

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw NetworkError.requestFailed(error.localizedDescription)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }
        
        let responseLog = String(data: data, encoding: .utf8)?.prefix(500) ?? "(Non-UTF8 or empty data)"
        print("AuthenticatedHTTPClient: Response for \(url.path) - Status \(httpResponse.statusCode). Data: \(responseLog)...")

        if (200...299).contains(httpResponse.statusCode) {
            return (data, httpResponse)
        } else if httpResponse.statusCode == 401 && requiresAuth && !isRetry {
            print("AuthenticatedHTTPClient: Unauthorized (401) for \(url.path). Attempting token refresh.")
            if await authManager.refreshAccessToken() {
                print("AuthenticatedHTTPClient: Token refresh successful. Retrying request for \(url.path).")
                return try await self.performRawRequest(endpoint: endpoint, method: method, body: body, requiresAuth: requiresAuth, isRetry: true)
            } else {
                print("AuthenticatedHTTPClient: Token refresh failed for \(url.path). Session expired.")
                if await authManager.currentUser != nil {
                     await MainActor.run { authManager.logout() }
                }
                throw NetworkError.sessionExpired
            }
        } else if httpResponse.statusCode == 401 && requiresAuth && isRetry {
            print("AuthenticatedHTTPClient: Unauthorized (401) for \(url.path) even after retry. Session expired.")
            if await authManager.currentUser != nil {
                await MainActor.run { authManager.logout() }
            }
            throw NetworkError.sessionExpired
        } else {
            throw NetworkError.serverError(statusCode: httpResponse.statusCode, data: data)
        }
    }

    // MARK: - Public Request Methods
    func request<T: Decodable>(
        endpoint: String,
        method: String = "GET",
        body: Encodable? = nil,
        requiresAuth: Bool = true
    ) async throws -> T {
        let (data, httpResponse) = try await performRawRequest(endpoint: endpoint, method: method, body: body, requiresAuth: requiresAuth)
        
        if data.isEmpty {
            if httpResponse.statusCode == 204, let empty = (Optional<Int>.none as? T) {
                 print("AuthenticatedHTTPClient: Received 204 No Content for \(endpoint), returning nil-equivalent for Optional type T.")
                 return empty
            } else if httpResponse.statusCode == 204 {
                 throw NetworkError.custom(message: "Received 204 No Content for \(endpoint), but expected Decodable type \(String(describing: T.self)) cannot be empty.")
            }
        }

        // Pre-process data through JSONSerialization to attempt to sanitize it
        let sanitizedData: Data
        do {
            let jsonObject = try JSONSerialization.jsonObject(with: data, options: .allowFragments)
            sanitizedData = try JSONSerialization.data(withJSONObject: jsonObject, options: [])
            print("AuthenticatedHTTPClient: Data re-serialized via JSONSerialization. Original size: \(data.count), Sanitized size: \(sanitizedData.count)")
        } catch {
            print("AuthenticatedHTTPClient: Could not pre-process JSON via JSONSerialization: \(error). Using original data for decoding.")
            sanitizedData = data // Fallback to original data if sanitization fails
        }

        do {
            let decoder = JSONDecoder()
//            decoder.keyDecodingStrategy = .convertFromSnakeCase
            decoder.dateDecodingStrategy = .custom(Self.customDateDecodingStrategy)
            let decodedObject = try decoder.decode(T.self, from: sanitizedData)
            return decodedObject
        } catch {
            let dataRepresentation = String(data: data, encoding: .utf8) ?? "[Data could not be represented as UTF-8 string]"
            print("AuthenticatedHTTPClient: Decoding error for \(String(describing: T.self)) from endpoint \(endpoint): \(String(describing: error)). Original Data Preview: \(dataRepresentation.prefix(1000))")
            throw NetworkError.decodingError("Decoding error: \(String(describing: error)). Data preview: \(dataRepresentation.prefix(200))")
        }
    }
    
    func requestData(
        endpoint: String,
        method: String = "GET",
        body: Encodable? = nil,
        requiresAuth: Bool = true
    ) async throws -> (Data, HTTPURLResponse) {
        return try await performRawRequest(endpoint: endpoint, method: method, body: body, requiresAuth: requiresAuth)
    }
}

// MARK: - Refresh Synchronization Helper
private final class RefreshSynchronizer: @unchecked Sendable {
    private let queue = DispatchQueue(label: "com.evolve.refreshSync", qos: .userInitiated)
    private var isRefreshing = false
    private var completionHandlers: [(Bool) -> Void] = []
    
    func performRefresh(_ refreshOperation: @escaping () async -> Bool) async -> Bool {
        return await withCheckedContinuation { continuation in
            queue.async { [weak self] in
                guard let self = self else {
                    continuation.resume(returning: false)
                    return
                }
                
                // If refresh is already in progress, queue the completion handler
                if self.isRefreshing {
                    print("AuthenticationManager: Refresh already in progress, queuing request.")
                    self.completionHandlers.append { success in
                        continuation.resume(returning: success)
                    }
                    return
                }
                
                // Start refresh process
                self.isRefreshing = true
                print("AuthenticationManager: Starting token refresh process.")
                
                Task {
                    let success = await refreshOperation()
                    
                    // Complete all queued handlers on the sync queue
                    self.queue.async {
                        let handlers = self.completionHandlers
                        self.completionHandlers.removeAll()
                        self.isRefreshing = false
                        
                        // Notify all waiting callers
                        for handler in handlers {
                            handler(success)
                        }
                        
                        // Resume the original caller
                        continuation.resume(returning: success)
                    }
                }
            }
        }
    }
}

@MainActor // Ensure AuthenticationManager is main actor isolated if it publishes UI changes
class AuthenticationManager: ObservableObject {
    // MARK: - Published Properties
    @Published var currentUser: AppUser?
    @Published var users: [SimpleAppUser] = [] // For test login view
    @Published var authToken: String?

    // MARK: - Computed Properties
    var isUserLoggedIn: Bool {
        return currentUser != nil && authToken != nil
    }

    // MARK: - Private Properties
    private var refreshToken: String?
    private let userDefaultsKey = "evolveSavedUser"
    private let keychainAuthTokenKey = "evolveAuthToken"
    private let keychainRefreshTokenKey = "evolveRefreshToken"
    
    // MARK: - Refresh Synchronization
    private let refreshSynchronizer = RefreshSynchronizer()
    
    lazy var httpClient: AuthenticatedHTTPClient = {
        AuthenticatedHTTPClient(authenticationManager: self)
    }()

    // MARK: - Initialization
    init() {
        print("AuthenticationManager: Initializing.")
        loadSavedSession()
        if self.authToken == nil && self.refreshToken != nil && self.currentUser != nil {
            Task {
                print("AuthenticationManager: App launch with refresh token but no auth token. Attempting preemptive token refresh.")
                _ = await refreshAccessToken()
            }
        } else if self.currentUser == nil && (self.authToken != nil || self.refreshToken != nil) {
            print("AuthenticationManager: Inconsistent state on init (tokens present but no user). Clearing session.")
            clearLocalSessionData()
        } else if self.authToken != nil {
            // Start background token refresh monitoring
            Task {
                await startTokenRefreshMonitoring()
            }
        }
    }
    
    // MARK: - Token Refresh Monitoring
    private func startTokenRefreshMonitoring() async {
        while currentUser != nil && authToken != nil {
            // Check if token needs refresh every 30 minutes
            try? await Task.sleep(nanoseconds: 30 * 60 * 1_000_000_000) // 30 minutes
            
            if await shouldRefreshToken() {
                print("AuthenticationManager: Proactively refreshing token before expiration.")
                _ = await refreshAccessToken()
            }
        }
    }
    
    private func shouldRefreshToken() async -> Bool {
        guard let token = authToken else { return false }
        
        // Parse JWT to check expiration (simplified check)
        let components = token.components(separatedBy: ".")
        guard components.count == 3,
              let payloadData = Data(base64Encoded: addPaddingToBase64(components[1])),
              let payload = try? JSONSerialization.jsonObject(with: payloadData) as? [String: Any],
              let exp = payload["exp"] as? TimeInterval else {
            return false
        }
        
        let expirationDate = Date(timeIntervalSince1970: exp)
        let timeUntilExpiration = expirationDate.timeIntervalSinceNow
        
        // Refresh if token expires in the next 15 minutes
        return timeUntilExpiration < 15 * 60
    }
    
    private func addPaddingToBase64(_ base64: String) -> String {
        let remainder = base64.count % 4
        if remainder > 0 {
            return base64 + String(repeating: "=", count: 4 - remainder)
        }
        return base64
    }
    
    // MARK: - Public API (Authentication)
    func loginUser(user: AppUser, accessToken: String, refreshToken: String) {
        print("AuthenticationManager: loginUser called for \(user.displayName).")
        self.currentUser = user
        self.authToken = accessToken
        self.refreshToken = refreshToken

        self.persistCurrentSessionState()
        print("AuthenticationManager: User \(user.displayName) logged in. Tokens and user data persisted.")
        
        // Start background token refresh monitoring
        Task {
            await startTokenRefreshMonitoring()
        }
    }
    
    func logout() {
        print("AuthenticationManager: Initiating logout for user \(currentUser?.displayName ?? "N/A").")
        let tokenToInvalidateOnServer = self.refreshToken
        clearLocalSessionData()
        if let token = tokenToInvalidateOnServer {
            Task {
                await invalidateTokenOnServer(refreshToken: token)
            }
        }
    }
    
    func refreshAccessToken() async -> Bool {
        return await refreshSynchronizer.performRefresh { [weak self] in
            guard let self = self else { return false }
            return await self.performTokenRefresh()
        }
    }
    
    private func performTokenRefresh() async -> Bool {
        guard let currentRefreshToken = self.refreshToken else {
            print("AuthenticationManager: No refresh token for refreshAccessToken.")
            await MainActor.run {
                if currentUser != nil { clearLocalSessionData() }
            }
            return false
        }

        print("AuthenticationManager: Attempting token refresh.")
        guard let refreshURL = URL(string: AppConfig.apiBaseURL + "/token/refresh/") else {
            print("AuthenticationManager: Invalid URL for token refresh.")
            return false
        }

        var request = URLRequest(url: refreshURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let payload = RefreshTokenRequest(refresh: currentRefreshToken)
        do {
            request.httpBody = try JSONEncoder().encode(payload)
        } catch {
            print("AuthenticationManager: Error encoding refresh payload: \(error)")
            return false
        }
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                print("AuthenticationManager: Invalid refresh response.")
                return false
            }
            
            let responseBodyString = String(data: data, encoding: .utf8) ?? ""
            print("AuthenticationManager: Refresh response status: \(httpResponse.statusCode). Body: \(responseBodyString.prefix(500))")

            if httpResponse.statusCode == 401 {
                print("AuthenticationManager: Refresh token invalid (401). Logging out.")
                await MainActor.run {
                    clearLocalSessionData()
                }
                return false
            }
            guard (200...299).contains(httpResponse.statusCode) else {
                print("AuthenticationManager: Refresh request failed. Status: \(httpResponse.statusCode)")
                return false
            }
            let decodedResponse = try JSONDecoder().decode(RefreshTokenResponse.self, from: data)
            
            await MainActor.run {
                self.authToken = decodedResponse.access
                if let rotatedRefreshToken = decodedResponse.refresh {
                    self.refreshToken = rotatedRefreshToken
                    print("AuthenticationManager: Token refresh successful. New access and new (rotated) refresh token received.")
                } else {
                    print("AuthenticationManager: Token refresh successful. New access token. Refresh token not rotated.")
                }
                persistCurrentSessionState()
            }
            return true
        } catch {
            print("AuthenticationManager: Error during token refresh call: \(error)")
            return false
        }
    }
    
    // MARK: - Public API (User Data)
    func submitOnboardingProfile(firstName: String, lastName: String, height: Double, birthday: String, weight: Double, sex: String, goalsRaw: [String]?, goalDetails: [UserGoalDetailPayload]?, completion: @escaping (Bool, Error?) -> Void) {
        guard let currentUser = self.currentUser else {
            print("AuthenticationManager: No current user to submit onboarding profile.")
            completion(false, NetworkError.custom(message: "User not logged in."))
            return
        }

        let endpoint = "/complete-onboarding/"
        
        var goalsPayload: CompleteOnboardingRequest.Goals?
        if let rawGoals = goalsRaw {
            goalsPayload = CompleteOnboardingRequest.Goals(goals_general: rawGoals, details: goalDetails)
        } else {
            goalsPayload = nil
        }

        let requestBody = CompleteOnboardingRequest(
            firstName: firstName,
            lastName: lastName,
            height: height,
            birthday: birthday,
            weight: weight,
            sex: sex,
            goals: goalsPayload
        )

        print("AuthenticationManager: Submitting full onboarding profile for user \(currentUser.displayName).")

        Task {
            do {
                let response: CompleteOnboardingResponse = try await httpClient.request(endpoint: endpoint, method: "POST", body: requestBody, requiresAuth: true)

                self.currentUser = response.user
                self.persistCurrentSessionState()
                
                print("AuthenticationManager: Successfully submitted onboarding profile. User data updated. Message: \(response.message)")
                completion(true, nil)
            } catch let error as NetworkError where error == .sessionExpired || error == .unauthorized {
                print("AuthenticationManager: Session expired/unauthorized during onboarding submission. Error: \(error)")
                completion(false, error)
            } catch {
                print("AuthenticationManager: Error submitting onboarding profile: \(error.localizedDescription)")
                completion(false, error)
            }
        }
    }
    
    func fetchCurrentUserDetails() {
        guard let user = currentUser else {
            print("AuthenticationManager: Cannot refresh user details. No current user.")
            if authToken != nil || refreshToken != nil { clearLocalSessionData() }
            return
        }
        let userId = user.id

        print("AuthenticationManager: Refreshing current user details for user ID \(userId) using httpClient.")

        Task {
            do {
                let refreshedUser: AppUser = try await httpClient.request(endpoint: "/users/\(userId)/", method: "GET", requiresAuth: true)
                self.currentUser = refreshedUser
                self.persistCurrentSessionState()
                print("AuthenticationManager: Successfully refreshed user details for \(refreshedUser.displayName).")
            } catch NetworkError.sessionExpired {
                print("AuthenticationManager: Session expired while fetching user details.")
                if self.currentUser != nil { clearLocalSessionData() }
            } catch NetworkError.unauthorized {
                print("AuthenticationManager: Unauthorized while fetching user details.")
                if self.currentUser != nil { clearLocalSessionData() }
            } catch {
                print("AuthenticationManager: Error refreshing user details: \(error.localizedDescription)")
            }
        }
    }

    func updateUserDetails(payload: AppUserUpdatePayload) async throws {
        guard let currentUser = self.currentUser else {
            throw NetworkError.custom(message: "User not logged in.")
        }

        let endpoint = "/users/\(currentUser.id)/"

        let updatedUser: AppUser = try await httpClient.request(
            endpoint: endpoint,
            method: "PATCH",
            body: payload,
            requiresAuth: true
        )
        
        self.currentUser = updatedUser
        persistCurrentSessionState()
        print("AuthenticationManager: Successfully updated user details. User re-persisted.")
    }

    func updateUserGoals(userId: String, goalsRaw: [String], completion: @escaping (Bool, Error?) -> Void) {
        struct UserGoalsUpdateRequest: Codable {
            let goals_general: [String]
        }

        let endpoint = "/users/\(userId)/goals/"

        let requestBody = UserGoalsUpdateRequest(goals_general: goalsRaw)

        print("AuthenticationManager: Attempting to update goals for user ID \(userId) at \(endpoint).")

        Task {
            do {
                let (_, httpResponse) = try await httpClient.requestData(
                    endpoint: endpoint,
                    method: "POST",
                    body: requestBody,
                    requiresAuth: true
                )

                guard (200...299).contains(httpResponse.statusCode) else {
                    let errorDetail = String(data: httpResponse.debugDescription.data(using: .utf8) ?? Data(), encoding: .utf8) ?? "Unknown server error"
                    print("AuthenticationManager: Failed to update goals for user ID \(userId). Status: \(httpResponse.statusCode). Error: \(errorDetail)")
                    completion(false, NetworkError.serverError(statusCode: httpResponse.statusCode, data: nil))
                    return
                }

                print("AuthenticationManager: Successfully submitted goals update for user ID \(userId) to \(endpoint). Refreshing user details.")
                
                if self.currentUser?.id == userId {
                    self.fetchCurrentUserDetails()
                }
                
                completion(true, nil)

            } catch let error as NetworkError {
                print("AuthenticationManager: NetworkError updating goals for user ID \(userId): \(error)")
                completion(false, error)
            } catch {
                print("AuthenticationManager: Generic error updating goals for user ID \(userId): \(error.localizedDescription)")
                completion(false, error)
            }
        }
    }
    
    func fetchSimpleUsers() async {
        guard let url = URL(string: AppConfig.apiBaseURL + "/users/simple/") else {
            print("AuthenticationManager: Invalid URL for simple users.")
            return
        }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let decodedUsers = try JSONDecoder().decode([SimpleAppUser].self, from: data)
            self.users = decodedUsers
        } catch {
            print("AuthenticationManager: Error fetching simple users: \(error)")
        }
    }
    
    // MARK: - Test/Debug Methods
    func fetchAndAuthenticateUser(phone: String, firstName: String, lastName: String) async {
        print("AuthenticationManager: Test Login: fetchAndAuthenticateUser for \(firstName) \(lastName) \(phone).")
        guard let sendOTPURL = URL(string: AppConfig.apiBaseURL + "/send-otp/") else { return }
        var sendReq = URLRequest(url: sendOTPURL)
        sendReq.httpMethod = "POST"
        sendReq.setValue("application/json", forHTTPHeaderField: "Content-Type")
        do {
            sendReq.httpBody = try JSONEncoder().encode(SendOTPRequest(phone: phone))
        } catch { print("Encode error SendOTP: \(error)"); return }
        
        do {
            let (otpData, otpResp) = try await URLSession.shared.data(for: sendReq)
            guard let httpOtpResp = otpResp as? HTTPURLResponse, (200...299).contains(httpOtpResp.statusCode) else {
                print("SendOTP failed: \((otpResp as? HTTPURLResponse)?.statusCode ?? -1) Body: \(String(data: otpData, encoding: .utf8) ?? "")")
                return
            }
            let decOtpResp = try JSONDecoder().decode(SendOTPResponse.self, from: otpData)
            print("AuthenticationManager: Test Login: Received OTP (fake): \(decOtpResp.otp_code ?? "No OTP code").")

            guard let verifyOTPURL = URL(string: AppConfig.apiBaseURL + "/verify-otp/") else { return }
            var verifyReq = URLRequest(url: verifyOTPURL)
            verifyReq.httpMethod = "POST"
            verifyReq.setValue("application/json", forHTTPHeaderField: "Content-Type")
            let verifyPayload = VerifyOTPRequest(phone: phone, otp: decOtpResp.otp_code ?? "", firstName: firstName, lastName: lastName)
            do {
                verifyReq.httpBody = try JSONEncoder().encode(verifyPayload)
            } catch {
                print("Encoding error for VerifyOTPRequest: \(error)")
                return
            }

            let (verifyData, verifyResp) = try await URLSession.shared.data(for: verifyReq)
            guard let httpVerifyResp = verifyResp as? HTTPURLResponse, (200...299).contains(httpVerifyResp.statusCode) else {
                print("VerifyOTP failed: \((verifyResp as? HTTPURLResponse)?.statusCode ?? -1) Body: \(String(data: verifyData, encoding: .utf8) ?? "")")
                return
            }
            let decVerifyResp = try JSONDecoder().decode(VerifyOTPResponse.self, from: verifyData)
            print("AuthenticationManager: Test Login: OTP verified for \(decVerifyResp.user.displayName).")
            loginUser(user: decVerifyResp.user, accessToken: decVerifyResp.access_token, refreshToken: decVerifyResp.refresh_token)
        } catch {
            print("AuthenticationManager: Test Login: Error during OTP flow: \(error)")
        }
    }

    // MARK: - Private Helpers (Session Management)
    private func invalidateTokenOnServer(refreshToken: String) async {
        print("AuthenticationManager: Attempting to invalidate refresh token on server.")
        struct LogoutRequest: Encodable { let refresh: String }
        let payload = LogoutRequest(refresh: refreshToken)
        do {
            let (responseData, httpResponse) = try await httpClient.requestData(endpoint: "/auth/logout/", method: "POST", body: payload, requiresAuth: false)
            if (200...299).contains(httpResponse.statusCode) {
                print("AuthenticationManager: Refresh token successfully invalidated on server.")
            } else {
                print("AuthenticationManager: Failed to invalidate refresh token on server. Status: \(httpResponse.statusCode). Response: \(String(data: responseData, encoding: .utf8) ?? "No data")")
            }
        } catch {
            print("AuthenticationManager: Error calling server logout: \(error.localizedDescription)")
        }
    }

    private func saveUserToUserDefaults() {
        if let user = currentUser {
            do {
                let encoder = JSONEncoder()
                let userData = try encoder.encode(user)
                UserDefaults.standard.set(userData, forKey: userDefaultsKey)
                print("AuthenticationManager: User data for \(user.displayName) saved to UserDefaults.")
            } catch {
                print("AuthenticationManager: Error saving user data to UserDefaults: \(error)")
            }
        } else {
             UserDefaults.standard.removeObject(forKey: userDefaultsKey)
             print("AuthenticationManager: No current user, cleared user data from UserDefaults.")
        }
    }
    
    private func clearLocalSessionData() {
        print("AuthenticationManager: Clearing all local session data.")
        self.currentUser = nil
        self.authToken = nil
        self.refreshToken = nil

        UserDefaults.standard.removeObject(forKey: self.userDefaultsKey)
        do {
            try KeychainHelper.standard.deleteData(forKey: self.keychainAuthTokenKey)
            try KeychainHelper.standard.deleteData(forKey: self.keychainRefreshTokenKey)
            print("AuthenticationManager: Tokens cleared from Keychain and local state.")
        } catch {
            print("AuthenticationManager: Error clearing tokens from Keychain: \(error)")
        }
    }
    
    private func persistCurrentSessionState() {
        saveUserToUserDefaults()
        do {
            if let token = authToken {
                try KeychainHelper.standard.saveString(token, forKey: keychainAuthTokenKey)
            } else {
                try KeychainHelper.standard.deleteData(forKey: keychainAuthTokenKey)
            }
            if let token = refreshToken {
                try KeychainHelper.standard.saveString(token, forKey: keychainRefreshTokenKey)
            } else {
                try KeychainHelper.standard.deleteData(forKey: keychainRefreshTokenKey)
            }
            print("AuthenticationManager: Tokens persisted to Keychain.")
        } catch {
            print("AuthenticationManager: CRITICAL - Error persisting tokens to Keychain: \(error). Consider forced logout.")
        }
    }

    private func loadSavedSession() {
        print("AuthenticationManager: loadSavedSession called.")
        var loadedUser: AppUser? = nil
        if let userData = UserDefaults.standard.data(forKey: userDefaultsKey) {
            do {
                loadedUser = try JSONDecoder().decode(AppUser.self, from: userData)
            } catch {
                print("AuthenticationManager: Error decoding user from UserDefaults: \(error). Clearing session.")
                clearLocalSessionData()
                return
            }
        } else {
            print("AuthenticationManager: No saved user in UserDefaults.")
        }

        var loadedAuthToken: String? = nil
        var loadedRefreshToken: String? = nil
        do {
            loadedAuthToken = try KeychainHelper.standard.loadString(forKey: keychainAuthTokenKey)
            loadedRefreshToken = try KeychainHelper.standard.loadString(forKey: keychainRefreshTokenKey)
        } catch {
            print("AuthenticationManager: Error loading tokens from Keychain: \(error). Clearing session.")
            clearLocalSessionData()
            return
        }
        
        if let user = loadedUser, let refToken = loadedRefreshToken {
            self.currentUser = user
            self.authToken = loadedAuthToken
            self.refreshToken = refToken
            print("AuthenticationManager: Session restored for \(user.displayName). AuthToken: \(loadedAuthToken != nil), RefreshToken: \(loadedRefreshToken != nil)")
        } else {
            print("AuthenticationManager: No valid session to restore (User: \(loadedUser != nil), RefreshToken: \(loadedRefreshToken != nil)).")
            if self.currentUser != nil || self.authToken != nil || self.refreshToken != nil {
                 clearLocalSessionData()
            }
        }
    }
}
