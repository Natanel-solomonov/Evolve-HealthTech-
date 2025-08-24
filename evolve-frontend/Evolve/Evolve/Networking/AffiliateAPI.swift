import Foundation

class AffiliateAPI {
    
    private let httpClient: AuthenticatedHTTPClient
    
    // To use this class as a singleton, AuthenticationManager's httpClient would need to be accessible
    // For example, if AuthenticationManager has a shared instance:
    // static let shared = AffiliateAPI(httpClient: AuthenticationManager.shared.httpClient)
    // Or, AffiliateAPI is instantiated where an AuthenticationManager instance is available.
    // For now, designed to be initialized with an httpClient.
    
    init(httpClient: AuthenticatedHTTPClient) {
        self.httpClient = httpClient
    }
    
    // mediaBaseURLString can remain if it's used for constructing full media URLs separately from API calls
    // However, if it's just the API base, it's redundant. Assuming it might be for images etc.
    public static var mediaBaseURLString: String {
        return AppConfig.apiBaseURL // Using the root URL for media
    }
    
    func fetchAffiliates(completion: @escaping (Result<[Affiliate], NetworkError>) -> Void) {
        Task {
            do {
                let affiliates: [Affiliate] = try await httpClient.request(endpoint: "/affiliates/", method: "GET", requiresAuth: true)
                completion(.success(affiliates))
            } catch {
                completion(.failure(error as? NetworkError ?? .custom(message: "Unknown error")))
            }
        }
    }
    
    func fetchAffiliate(id: UUID, completion: @escaping (Result<Affiliate, NetworkError>) -> Void) {
        Task {
            do {
                let affiliate: Affiliate = try await httpClient.request(endpoint: "/affiliates/\\(id.uuidString)/", method: "GET", requiresAuth: true)
                completion(.success(affiliate))
            } catch {
                completion(.failure(error as? NetworkError ?? .custom(message: "Unknown error")))
            }
        }
    }

    func fetchAffiliatePromotions(completion: @escaping (Result<[AffiliatePromotion], NetworkError>) -> Void) {
        Task {
            do {
                let promotions: [AffiliatePromotion] = try await httpClient.request(endpoint: "/affiliate-promotions/", method: "GET", requiresAuth: true)
                completion(.success(promotions))
            } catch {
                completion(.failure(error as? NetworkError ?? .custom(message: "Unknown error")))
            }
        }
    }
    
    func fetchAffiliatePromotion(id: UUID, completion: @escaping (Result<AffiliatePromotion, NetworkError>) -> Void) {
        Task {
            do {
                let promotion: AffiliatePromotion = try await httpClient.request(endpoint: "/affiliate-promotions/\\(id.uuidString)/", method: "GET", requiresAuth: true)
                completion(.success(promotion))
            } catch {
                completion(.failure(error as? NetworkError ?? .custom(message: "Unknown error")))
            }
        }
    }
    
    /// Fetches affiliate promotions assigned to a specific user
    /// - Parameters:
    ///   - userId: The ID of the user to fetch promotions for
    ///   - activeOnly: If true, returns only currently active promotions (default: true)
    ///   - completion: Completion handler with result
    func fetchUserAffiliatePromotions(
        userId: String, 
        activeOnly: Bool = true,
        completion: @escaping (Result<[AffiliatePromotion], NetworkError>) -> Void
    ) {
        Task {
            do {
                print("AffiliateAPI: Fetching promotions for userId: \(userId), activeOnly: \(activeOnly)")
                
                // Construct endpoint with query parameter
                var endpoint = "/users/\(userId)/affiliate-promotions/"
                if !activeOnly {
                    endpoint += "?active_only=false"
                }
                
                let promotions: [AffiliatePromotion] = try await httpClient.request(
                    endpoint: endpoint, 
                    method: "GET", 
                    requiresAuth: true
                )
                completion(.success(promotions))
            } catch {
                completion(.failure(error as? NetworkError ?? .custom(message: "Unknown error")))
            }
        }
    }



    // Admin-only endpoint
    func fetchAffiliatePromotionRedemptions(completion: @escaping (Result<[AffiliatePromotionRedemption], NetworkError>) -> Void) {
        Task {
            do {
                let redemptions: [AffiliatePromotionRedemption] = try await httpClient.request(endpoint: "/affiliate-promotion-redemptions/", method: "GET", requiresAuth: true)
                completion(.success(redemptions))
            } catch {
                completion(.failure(error as? NetworkError ?? .custom(message: "Unknown error")))
            }
        }
    }
    
    // Admin-only endpoint
    func fetchAffiliatePromotionRedemption(id: UUID, completion: @escaping (Result<AffiliatePromotionRedemption, NetworkError>) -> Void) {
        Task {
            do {
                let redemption: AffiliatePromotionRedemption = try await httpClient.request(endpoint: "/affiliate-promotion-redemptions/\\(id.uuidString)/", method: "GET", requiresAuth: true)
                completion(.success(redemption))
            } catch {
                completion(.failure(error as? NetworkError ?? .custom(message: "Unknown error")))
            }
        }
    }
    
    // MARK: - Promotion Redemption
    
    /// Redeem a promotion for the current user
    func redeemPromotion(
        promotionId: UUID,
        completion: @escaping (Result<RedemptionResponse, NetworkError>) -> Void
    ) {
        Task {
            do {
                let requestBody = ["promotion_id": promotionId.uuidString]
                let response: RedemptionResponse = try await httpClient.request(
                    endpoint: "/redeem-promotion/",
                    method: "POST",
                    body: requestBody,
                    requiresAuth: true
                )
                completion(.success(response))
            } catch {
                completion(.failure(error as? NetworkError ?? .custom(message: "Unknown error")))
            }
        }
    }
    
    /// Get user's redemption history
    func fetchRedemptionHistory(
        completion: @escaping (Result<[AffiliatePromotionRedemption], NetworkError>) -> Void
    ) {
        Task {
            do {
                let redemptions: [AffiliatePromotionRedemption] = try await httpClient.request(
                    endpoint: "/redemption-history/",
                    method: "GET",
                    requiresAuth: true
                )
                completion(.success(redemptions))
            } catch {
                completion(.failure(error as? NetworkError ?? .custom(message: "Unknown error")))
            }
        }
    }
    
    /// Get user's products from redeemed promotions
    func fetchUserProducts(
        activeOnly: Bool = true,
        category: String? = nil,
        completion: @escaping (Result<[UserProduct], NetworkError>) -> Void
    ) {
        Task {
            do {
                var endpoint = "/user-products/"
                var queryParams: [String] = []
                
                if activeOnly {
                    queryParams.append("active_only=true")
                }
                
                if let category = category {
                    queryParams.append("category=\(category)")
                }
                
                if !queryParams.isEmpty {
                    endpoint += "?" + queryParams.joined(separator: "&")
                }
                
                let products: [UserProduct] = try await httpClient.request(
                    endpoint: endpoint,
                    method: "GET",
                    requiresAuth: true
                )
                completion(.success(products))
            } catch {
                completion(.failure(error as? NetworkError ?? .custom(message: "Unknown error")))
            }
        }
    }
    
    // Add create, update, delete methods for these entities as needed.
    // They would similarly use httpClient.request with appropriate methods ("POST", "PUT", "DELETE") and bodies.
    // Example:
    /*
    func createAffiliatePromotion(data: NewAffiliatePromotionData, completion: @escaping (Result<AffiliatePromotion, NetworkError>) -> Void) {
        Task {
            do {
                let promotion: AffiliatePromotion = try await httpClient.request(endpoint: "/affiliate-promotions/", method: "POST", body: data, requiresAuth: true)
                completion(.success(promotion))
            } catch {
                completion(.failure(error as? NetworkError ?? .custom(message: "Unknown error")))
            }
        }
    }
    */
}

// Note: The existence and structure of Affiliate, AffiliatePromotion,
// and AffiliatePromotionRedemption Codable structs
// are crucial for this refactoring to be complete. They should be defined based on
// the backend Django serializers (AffiliateSerializer, AffiliatePromotionSerializer, etc.).
