// AlcoholAPI.swift
import Foundation

/// Request structure for logging alcoholic beverages
struct LogAlcoholEntryRequest: Codable {
    let userPhone: String
    let alcoholicBeverage: String // AlcoholicBeverage ID
    let foodName: String
    let servingSize: Double // Always 1.0 for standard drink
    let servingUnit: String // Always "standard drink"
    let quantity: Int // Number of standard drinks
    let mealType: String
    let timeConsumed: String // ISO8601 string
    
    enum CodingKeys: String, CodingKey {
        case userPhone = "user_phone"
        case alcoholicBeverage = "alcoholic_beverage"
        case foodName = "food_name"
        case servingSize = "serving_size"
        case servingUnit = "serving_unit"
        case quantity
        case mealType = "meal_type"
        case timeConsumed = "time_consumed"
    }
}

/// Response from alcohol logging endpoint
struct LogAlcoholResponse: Codable {
    let message: String
    let entryId: Int
    
    enum CodingKeys: String, CodingKey {
        case message
        case entryId = "entry_id"
    }
}

/// Main API class for alcohol-related network requests
class AlcoholAPI {
    
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
    
    // MARK: - Get All Alcohol Categories
    /// Fetches all available alcohol categories with counts
    func getAlcoholCategories() async throws -> AlcoholCategoriesResponse {
        do {
            let response: AlcoholCategoriesResponse = try await httpClient.request(
                endpoint: "/nutrition/alcoholic-beverages/categories/",
                method: "GET",
                requiresAuth: true
            )
            return response
        } catch {
            print("AlcoholAPI: Error fetching categories: \(error)")
            throw APIError.networkError(error)
        }
    }
    
    // MARK: - Search Alcoholic Beverages
    /// Searches for alcoholic beverages with optional category filtering
    /// - Parameters:
    ///   - query: Search query (minimum 2 characters)
    ///   - category: Optional category filter
    ///   - limit: Maximum number of results (default: 25)
    func searchAlcoholicBeverages(
        query: String,
        category: String? = nil,
        limit: Int = 25
    ) async throws -> AlcoholSearchResponse {
        
        guard query.trimmingCharacters(in: .whitespacesAndNewlines).count >= 2 else {
            throw APIError.invalidResponse
        }
        
        var urlComponents = URLComponents(string: "/nutrition/alcoholic-beverages/search/")!
        var queryItems = [
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "limit", value: String(limit))
        ]
        
        if let category = category {
            queryItems.append(URLQueryItem(name: "category", value: category))
        }
        
        urlComponents.queryItems = queryItems
        
        guard let endpoint = urlComponents.string else {
            throw APIError.invalidURL
        }
        
        do {
            let response: AlcoholSearchResponse = try await httpClient.request(
                endpoint: endpoint,
                method: "GET",
                requiresAuth: true
            )
            return response
        } catch {
            print("AlcoholAPI: Error searching beverages: \(error)")
            throw APIError.networkError(error)
        }
    }
    
    // MARK: - Get Beverages by Category
    /// Fetches alcoholic beverages for a specific category with pagination
    /// - Parameters:
    ///   - categoryKey: The category key (e.g., "beer", "wine")
    ///   - limit: Number of results per page (default: 20)
    ///   - offset: Pagination offset (default: 0)
    func getBeveragesByCategory(
        categoryKey: String,
        limit: Int = 20,
        offset: Int = 0
    ) async throws -> AlcoholCategoryResponse {
        
        var urlComponents = URLComponents(string: "/nutrition/alcoholic-beverages/search/")!
        urlComponents.queryItems = [
            URLQueryItem(name: "category", value: categoryKey),
            URLQueryItem(name: "page_size", value: String(limit)),
            URLQueryItem(name: "page", value: String((offset / limit) + 1))
        ]
        
        guard let endpoint = urlComponents.string else {
            throw APIError.invalidURL
        }
        
        do {
            let response: AlcoholSearchResponse = try await httpClient.request(
                endpoint: endpoint,
                method: "GET",
                requiresAuth: true
            )
            // Convert AlcoholSearchResponse to AlcoholCategoryResponse
            return AlcoholCategoryResponse(
                beverages: response.beverages,
                totalCount: response.totalCount,
                hasMore: response.hasMore
            )
        } catch {
            print("AlcoholAPI: Error fetching category beverages: \(error)")
            throw APIError.networkError(error)
        }
    }
    
    // MARK: - Get Beverage Details
    /// Fetches detailed information for a specific alcoholic beverage
    /// - Parameter beverageId: The unique ID of the alcoholic beverage
    func getBeverageDetails(beverageId: String) async throws -> AlcoholicBeverage {
        let endpoint = "/nutrition/alcoholic-beverages/\(beverageId)/"
        
        do {
            let response: AlcoholicBeverage = try await httpClient.request(
                endpoint: endpoint,
                method: "GET",
                requiresAuth: true
            )
            return response
        } catch {
            print("AlcoholAPI: Error fetching beverage details: \(error)")
            throw APIError.networkError(error)
        }
    }
    


    // MARK: - Log Alcoholic Beverage
    /// Logs an alcoholic beverage to the user's food diary
    /// - Parameters:
    ///   - beverage: The alcoholic beverage to log
    ///   - quantity: Number of standard drinks (default: 1)
    ///   - mealType: Meal type (breakfast, lunch, dinner, snack)
    ///   - userPhone: User's phone number for validation
    func logAlcoholicBeverage(
        beverage: AlcoholicBeverage,
        quantity: Int = 1,
        mealType: String,
        userPhone: String
    ) async throws -> LogAlcoholResponse {
        
        let request = LogAlcoholEntryRequest(
            userPhone: userPhone,
            alcoholicBeverage: beverage.id,
            foodName: beverage.name,
            servingSize: 1.0, // Always 1.0 for standard drink
            servingUnit: "standard drink",
            quantity: quantity,
            mealType: mealType,
            timeConsumed: ISO8601DateFormatter().string(from: Date())
        )
        
        do {
            let response: LogAlcoholResponse = try await httpClient.request(
                endpoint: "/nutrition/alcoholic-beverages/log/",
                method: "POST",
                body: request,
                requiresAuth: true
            )
            return response
        } catch {
            print("AlcoholAPI: Error logging beverage: \(error)")
            throw APIError.networkError(error)
        }
    }
}

// MARK: - Convenience Methods
extension AlcoholAPI {
    
    /// Quick method to get all categories using completion handler
    func getAlcoholCategories(completion: @escaping (Result<AlcoholCategoriesResponse, Error>) -> Void) {
        Task {
            do {
                let response = try await getAlcoholCategories()
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
    
    /// Quick method to search beverages using completion handler
    func searchAlcoholicBeverages(
        query: String,
        category: String? = nil,
        completion: @escaping (Result<AlcoholSearchResponse, Error>) -> Void
    ) {
        Task {
            do {
                let response = try await searchAlcoholicBeverages(query: query, category: category)
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
    
    /// Quick method to get category beverages using completion handler
    func getBeveragesByCategory(
        categoryKey: String,
        completion: @escaping (Result<AlcoholCategoryResponse, Error>) -> Void
    ) {
        Task {
            do {
                let response = try await getBeveragesByCategory(categoryKey: categoryKey)
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