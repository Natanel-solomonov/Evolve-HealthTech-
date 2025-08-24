// CaffeineAPI.swift
import Foundation

/// Request structure for logging caffeine products
struct LogCaffeineEntryRequest: Codable {
    let userPhone: String
    let caffeineProduct: String // CaffeineProduct ID
    let foodName: String
    let quantity: Double // Number of servings
    let servingUnit: String // Always "serving"
    let mealType: String
    let timeConsumed: String // ISO8601 string
    
    enum CodingKeys: String, CodingKey {
        case userPhone = "user_phone"
        case caffeineProduct = "caffeine_product"
        case foodName = "food_name"
        case quantity
        case servingUnit = "serving_unit"
        case mealType = "meal_type"
        case timeConsumed = "time_consumed"
    }
}

/// Response from caffeine logging endpoint
struct LogCaffeineResponse: Codable {
    let message: String
    let entryId: Int
    
    enum CodingKeys: String, CodingKey {
        case message
        case entryId = "entry_id"
    }
}

/// Response structure for caffeine categories
struct CaffeineCategoriesResponse: Codable {
    let categories: [CaffeineCategory]
}

/// Response structure for caffeine product search
struct CaffeineSearchResponse: Codable {
    let products: [CaffeineProduct]
    let totalCount: Int
    let hasMore: Bool
    
    enum CodingKeys: String, CodingKey {
        case products
        case totalCount = "total_count"
        case hasMore = "has_more"
    }
}

/// Response structure for caffeine products by category
struct CaffeineCategoryResponse: Codable {
    let products: [CaffeineProduct]
    let totalCount: Int
    let hasMore: Bool
}

/// Main API class for caffeine-related network requests
class CaffeineAPI {
    
    private let httpClient: AuthenticatedHTTPClient
    
    init(httpClient: AuthenticatedHTTPClient) {
        self.httpClient = httpClient
    }
    
    // MARK: - API Errors
    enum APIError: Error {
        case invalidURL
        case networkError(Error)
        case decodingError(Error)
        case invalidResponse
        case serverError(statusCode: Int)
    }
    
    // MARK: - Get All Caffeine Categories
    /// Fetches all available caffeine categories with counts
    func getCaffeineCategories() async throws -> CaffeineCategoriesResponse {
        do {
            let response: CaffeineCategoriesResponse = try await httpClient.request(
                endpoint: "/nutrition/caffeine-products/categories/",
                method: "GET",
                requiresAuth: true
            )
            return response
        } catch {
            print("CaffeineAPI: Error fetching categories: \(error)")
            throw APIError.networkError(error)
        }
    }
    
    // MARK: - Search Caffeine Products
    /// Searches for caffeine products with optional category filtering
    /// - Parameters:
    ///   - query: Search query (minimum 2 characters)
    ///   - category: Optional category filter
    ///   - pageSize: Maximum number of results (default: 25)
    func searchCaffeineProducts(
        query: String,
        category: String? = nil,
        pageSize: Int = 25
    ) async throws -> CaffeineSearchResponse {
        
        guard query.trimmingCharacters(in: .whitespacesAndNewlines).count >= 2 else {
            throw APIError.invalidResponse
        }
        
        var urlComponents = URLComponents(string: "/nutrition/caffeine-products/search/")!
        var queryItems = [
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "page_size", value: String(pageSize))
        ]
        
        if let category = category {
            queryItems.append(URLQueryItem(name: "category", value: category))
        }
        
        urlComponents.queryItems = queryItems
        
        guard let endpoint = urlComponents.string else {
            throw APIError.invalidURL
        }
        
        do {
            let response: CaffeineSearchResponse = try await httpClient.request(
                endpoint: endpoint,
                method: "GET",
                requiresAuth: true
            )
            return response
        } catch {
            print("CaffeineAPI: Error searching products: \(error)")
            throw APIError.networkError(error)
        }
    }
    
    // MARK: - Get Products by Category
    /// Fetches caffeine products for a specific category with pagination
    /// - Parameters:
    ///   - categoryKey: The category key (e.g., "coffee", "energy_drink")
    ///   - pageSize: Number of results per page (default: 20)
    ///   - page: Page number (default: 1)
    func getProductsByCategory(
        categoryKey: String,
        pageSize: Int = 20,
        page: Int = 1
    ) async throws -> CaffeineCategoryResponse {
        
        var urlComponents = URLComponents(string: "/nutrition/caffeine-products/search/")!
        urlComponents.queryItems = [
            URLQueryItem(name: "category", value: categoryKey),
            URLQueryItem(name: "page_size", value: String(pageSize)),
            URLQueryItem(name: "page", value: String(page))
        ]
        
        guard let endpoint = urlComponents.string else {
            throw APIError.invalidURL
        }
        
        do {
            let response: CaffeineSearchResponse = try await httpClient.request(
                endpoint: endpoint,
                method: "GET",
                requiresAuth: true
            )
            // Convert CaffeineSearchResponse to CaffeineCategoryResponse
            return CaffeineCategoryResponse(
                products: response.products,
                totalCount: response.totalCount,
                hasMore: response.hasMore
            )
        } catch {
            print("CaffeineAPI: Error fetching category products: \(error)")
            throw APIError.networkError(error)
        }
    }
    
    // MARK: - Get Product Details
    /// Fetches detailed information for a specific caffeine product
    /// - Parameter productId: The unique ID of the caffeine product
    func getProductDetails(productId: String) async throws -> CaffeineProduct {
        let endpoint = "/nutrition/caffeine-products/\(productId)/"
        
        do {
            let response: CaffeineProduct = try await httpClient.request(
                endpoint: endpoint,
                method: "GET",
                requiresAuth: true
            )
            return response
        } catch {
            print("CaffeineAPI: Error fetching product details: \(error)")
            throw APIError.networkError(error)
        }
    }
    
    // MARK: - Log Caffeine Product
    /// Logs a caffeine product to the user's food diary
    /// - Parameters:
    ///   - product: The caffeine product to log
    ///   - quantity: Number of servings (default: 1.0)
    ///   - mealType: Meal type (breakfast, lunch, dinner, snack, caffeine)
    ///   - userPhone: User's phone number for validation
    func logCaffeineProduct(
        product: CaffeineProduct,
        quantity: Double = 1.0,
        mealType: String,
        userPhone: String
    ) async throws -> LogCaffeineResponse {
        print("CaffeineAPI: logCaffeineProduct called for \(product.name) with quantity \(quantity)")
        
        let request = LogCaffeineEntryRequest(
            userPhone: userPhone,
            caffeineProduct: product.id,
            foodName: product.displayName,
            quantity: quantity,
            servingUnit: "serving",
            mealType: mealType,
            timeConsumed: ISO8601DateFormatter().string(from: Date())
        )
        
        do {
            print("CaffeineAPI: About to make HTTP request")
            let response: LogCaffeineResponse = try await httpClient.request(
                endpoint: "/nutrition/caffeine-products/log/",
                method: "POST",
                body: request,
                requiresAuth: true
            )
            print("CaffeineAPI: HTTP request completed successfully")
            return response
        } catch {
            print("CaffeineAPI: Error logging product: \(error)")
            throw APIError.networkError(error)
        }
    }
}

// MARK: - Convenience Methods
extension CaffeineAPI {
    
    /// Quick method to get all categories using completion handler
    func getCaffeineCategories(completion: @escaping (Result<CaffeineCategoriesResponse, Error>) -> Void) {
        Task {
            do {
                let response = try await getCaffeineCategories()
                await MainActor.run {
                    completion(.success(response))
                }
            } catch {
                await MainActor.run {
                    completion(.failure(error))
                }
            }
        }
    }
    
    /// Quick method to search products using completion handler
    func searchCaffeineProducts(
        query: String,
        category: String? = nil,
        completion: @escaping (Result<CaffeineSearchResponse, Error>) -> Void
    ) {
        Task {
            do {
                let response = try await searchCaffeineProducts(query: query, category: category)
                await MainActor.run {
                    completion(.success(response))
                }
            } catch {
                await MainActor.run {
                    completion(.failure(error))
                }
            }
        }
    }
    
    /// Quick method to get category products using completion handler
    func getProductsByCategory(
        categoryKey: String,
        completion: @escaping (Result<CaffeineCategoryResponse, Error>) -> Void
    ) {
        Task {
            do {
                let response = try await getProductsByCategory(categoryKey: categoryKey)
                await MainActor.run {
                    completion(.success(response))
                }
            } catch {
                await MainActor.run {
                    completion(.failure(error))
                }
            }
        }
    }
} 