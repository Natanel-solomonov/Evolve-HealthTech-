// FoodSearchAPI.swift
import Foundation

// Make sure your FoodProduct struct (likely in Models/Nutrition.swift)
// matches the backend serializer and conforms to Decodable, Identifiable, Hashable.
// struct FoodProduct: Decodable, Identifiable, Hashable { ... }

// Models (assumed to be defined elsewhere, e.g., Models/Nutrition.swift)
// struct FoodProduct: Codable, Identifiable, Hashable { ... }
// struct FoodEntry: Codable, Identifiable, Hashable { ... }

struct LogFoodEntryRequest: Codable {
    let userPhone: String // Backend expects user_phone and validates it against request.user.phone
    let foodProductId: String
    let servingSize: Double
    let mealType: String
    let timeConsumed: String // ISO8601 string
}

struct CreateFoodEntryRequest: Codable {
    let userPhone: String
    let foodProductId: String?
    let foodName: String
    let servingSize: Double
    let servingUnit: String
    let calories: Int
    let protein: Double
    let carbs: Double
    let fat: Double
    let fiberGrams: Double
    let ironMilligrams: Double
    let calciumMilligrams: Double
    let vitaminAMicrograms: Double
    let vitaminCMilligrams: Double
    let vitaminB12Micrograms: Double
    let folateMicrograms: Double
    let potassiumMilligrams: Double
    let mealType: String
    let timeConsumed: String
    
    enum CodingKeys: String, CodingKey {
        case userPhone = "user_phone"
        case foodProductId = "food_product_id"
        case foodName = "food_name"
        case servingSize = "serving_size"
        case servingUnit = "serving_unit"
        case calories, protein, carbs, fat
        case fiberGrams = "fiber_grams"
        case ironMilligrams = "iron_milligrams"
        case calciumMilligrams = "calcium_milligrams"
        case vitaminAMicrograms = "vitamin_a_micrograms"
        case vitaminCMilligrams = "vitamin_c_milligrams"
        case vitaminB12Micrograms = "vitamin_b12_micrograms"
        case folateMicrograms = "folate_micrograms"
        case potassiumMilligrams = "potassium_milligrams"
        case mealType = "meal_type"
        case timeConsumed = "time_consumed"
    }
}

// MARK: - Water Tracking Request Models

struct LogWaterRequest: Codable {
    let amountMl: Double
    let containerType: String
    
    enum CodingKeys: String, CodingKey {
        case amountMl = "amount_ml"
        case containerType = "container_type"
    }
}

struct UpdateWaterSettingsRequest: Codable {
    let waterGoalMl: Double
    let preferredUnit: String
    
    enum CodingKeys: String, CodingKey {
        case waterGoalMl = "water_goal_ml"
        case preferredUnit = "preferred_unit"
    }
}

class FoodSearchAPI: ObservableObject {

    private let httpClient: AuthenticatedHTTPClient
    
    // Public getter for httpClient to allow other API classes to use it
    var authenticatedHTTPClient: AuthenticatedHTTPClient {
        return httpClient
    }

    init(httpClient: AuthenticatedHTTPClient) {
        self.httpClient = httpClient
    }

    // Define potential API errors
    enum APIError: Error {
        case invalidURL
        case networkError(Error)
        case decodingError(Error)
        case invalidResponse
        case serverError(statusCode: Int)
    }

    // Function to search food products
    func searchFood(query: String, completion: @escaping (Result<[FoodProduct], NetworkError>) -> Void) {
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            completion(.success([]))
            return
        }
        
        let endpointPath = "/food-products/search/"
        var components = URLComponents(string: endpointPath) // httpClient prepends base URL
        components?.queryItems = [URLQueryItem(name: "query", value: query)]

        guard let finalEndpoint = components?.string else {
            completion(.failure(.invalidURL))
            return
        }
        
        Task {
            do {
                // Step 1: Perform the raw data request
                let (data, _) = try await httpClient.requestData(endpoint: finalEndpoint, method: "GET", requiresAuth: true) // Backend now requires auth

                // Step 2: Decode safely using compactMap
                let decoder = JSONDecoder()
                // Configure decoder if necessary (e.g., keyDecodingStrategy, dateDecodingStrategy)
                // Assuming FoodProduct's custom init handles .convertFromSnakeCase implicitly or CodingKeys handle it.
                // If not, and your JSON still has snake_case keys, you might need:
                // decoder.keyDecodingStrategy = .convertFromSnakeCase

                let rawArray = try JSONSerialization.jsonObject(with: data, options: []) as? [[String: Any]] ?? []

                var decodedProducts: [FoodProduct] = []
                var decodingErrors: [Error] = []

                for dict in rawArray {
                    do {
                        let jsonData = try JSONSerialization.data(withJSONObject: dict, options: [])
                        let product = try decoder.decode(FoodProduct.self, from: jsonData)
                        decodedProducts.append(product)
                    } catch {
                        print("FoodSearchAPI: Skipping one product due to decoding error: \(error)")
                        decodingErrors.append(error)
                    }
                }
                
                if !decodingErrors.isEmpty && decodedProducts.isEmpty {
                    // If all products failed to decode, it's a more significant issue.
                    let firstErrorDescription = String(describing: decodingErrors.first!) // first! is safe due to the check
                    print("FoodSearchAPI: All products failed to decode. First error: \(firstErrorDescription)")
                    let detailedErrorMessage = "All products failed to decode. Error: \(firstErrorDescription)"
                    completion(.failure(.decodingError(detailedErrorMessage)))
                } else if !decodingErrors.isEmpty {
                     print("FoodSearchAPI: Some products failed to decode (\(decodingErrors.count) errors), but returning \(decodedProducts.count) successfully decoded products.")
                    completion(.success(decodedProducts)) // Partial success
                } else {
                    completion(.success(decodedProducts)) // Full success
                }

            } catch let networkError as NetworkError {
                 print("FoodSearchAPI: NetworkError during food search: \(networkError)")
                 completion(.failure(networkError))
            } catch { // Catch other errors like JSONSerialization errors
                print("FoodSearchAPI: Error parsing food search response (Non-NetworkError): \(error)")
                // Handle as a decoding error or a custom error
                completion(.failure(.decodingError("Failed to parse search response: \(error.localizedDescription)")))
            }
        }
    }

    // --- Updating logFoodEntry to use userPhone instead of userId ---
    func logFoodEntry(
        entryData: LogFoodEntryRequest,
        completion: @escaping (Result<FoodEntry, NetworkError>) -> Void // Changed to return created FoodEntry
    ) {
        Task {
            do {
                // Backend /food-entries/ POST returns the created FoodEntry object (201 Created)
                let createdEntry: FoodEntry = try await httpClient.request(endpoint: "/food-entries/", method: "POST", body: entryData, requiresAuth: true)
                completion(.success(createdEntry))
            } catch {
                completion(.failure(error as? NetworkError ?? .custom(message: "Error logging food entry")))
            }
        }
    }
    
    // Create comprehensive food entry with nutritional data
    func createFoodEntry(
        entryData: CreateFoodEntryRequest,
        completion: @escaping (Result<FoodEntry, NetworkError>) -> Void
    ) {
        Task {
            do {
                // Backend /food-entries/ POST returns the created FoodEntry object (201 Created)
                let createdEntry: FoodEntry = try await httpClient.request(endpoint: "/food-entries/", method: "POST", body: entryData, requiresAuth: true)
                completion(.success(createdEntry))
            } catch {
                completion(.failure(error as? NetworkError ?? .custom(message: "Error creating food entry")))
            }
        }
    }

    // Function to fetch food entries for a specific date and user
    func fetchDailyLogEntries(userPhone: String, date: Date) async -> Result<[FoodEntry], NetworkError> {
        let endpointPath = "/food-entries/"
        
        // Format date as YYYY-MM-DD
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let dateString = dateFormatter.string(from: date)

        // Construct query parameters
        let queryItems = [
            URLQueryItem(name: "user_phone", value: userPhone),
            URLQueryItem(name: "date", value: dateString)
        ]
        
        // Build the final endpoint string with query parameters
        var components = URLComponents()
        components.path = endpointPath
        components.queryItems = queryItems
        
        guard let finalEndpointWithQuery = components.string else {
            print("FoodSearchAPI Error: Could not create final endpoint string with query.")
            return .failure(.invalidURL)
        }

        print("FoodSearchAPI: Fetching entries via httpClient. Endpoint with query: \(finalEndpointWithQuery)")

        do {
            // Use httpClient to make the authenticated request
            let entries: [FoodEntry] = try await httpClient.request(
                endpoint: finalEndpointWithQuery,
                method: "GET",
                requiresAuth: true
            )
            print("FoodSearchAPI: Successfully fetched \(entries.count) entries for \(dateString) via httpClient")
            return .success(entries)
        } catch let error as NetworkError {
            print("FoodSearchAPI Error: NetworkError fetching entries via httpClient: \(error)")
            // Log raw data if available from NetworkError.serverError
            if case .serverError(_, let data) = error, let data = data, let _ = String(data: data, encoding: .utf8) {
                 print("Raw response data for server error:\n\(String(data: data, encoding: .utf8) ?? "Unable to decode data")")
            }
            return .failure(error)
        } catch {
            print("FoodSearchAPI Error: Unexpected error fetching entries via httpClient: \(error)")
            return .failure(.custom(message: "Unexpected error: \(error.localizedDescription)"))
        }
    }

    // Fetches all food entries for the currently authenticated user.
    // Date filtering should be done client-side if needed, or backend API updated.
    func fetchUserFoodEntries(completion: @escaping (Result<[FoodEntry], NetworkError>) -> Void) {
        Task {
            do {
                let entries: [FoodEntry] = try await httpClient.request(endpoint: "/food-entries/", method: "GET", requiresAuth: true)
                completion(.success(entries))
            } catch {
                completion(.failure(error as? NetworkError ?? .custom(message: "Error fetching food entries")))
            }
        }
    }

    // Function to delete a food entry
    func deleteFoodEntry(entryId: Int, completion: @escaping (Result<Void, NetworkError>) -> Void) {
        let endpointPath = "/food-entries/\(entryId)/"
        Task {
            do {
                let (_, httpResponse) = try await httpClient.requestData(endpoint: endpointPath, method: "DELETE", requiresAuth: true)
                if (200...299).contains(httpResponse.statusCode) { // Expect 204
                    completion(.success(()))
                } else {
                    completion(.failure(.serverError(statusCode: httpResponse.statusCode, data: nil)))
                }
            } catch {
                completion(.failure(error as? NetworkError ?? .custom(message: "Error deleting food entry")))
            }
        }
    }

    func fetchProductByBarcode(barcode: String) async throws -> EnhancedBarcodeProductResult {
        let endpoint = "/food-products/barcode/\(barcode)/"
        
        // 1. Fetch raw data instead of trying to decode directly
        let (data, httpResponse) = try await httpClient.requestData(
                endpoint: endpoint,
                method: "GET",
                requiresAuth: true
            )

        guard (200...299).contains(httpResponse.statusCode) else {
            // Throw a specific error based on the status code
            throw APIError.serverError(statusCode: httpResponse.statusCode)
        }

        // 2. Decode the response to check for specialized products
        do {
            let decoder = JSONDecoder()
            let barcodeResponse = try decoder.decode(BarcodeResponse.self, from: data)
            
            // Check if it's a specialized product (alcohol/caffeine) - direct match
            if let type = barcodeResponse.type, let specializedProduct = barcodeResponse.specializedProduct {
                if type == "alcohol" {
                    if let alcoholBeverage = specializedProduct.toAlcoholicBeverage() {
                        return .alcohol(alcoholBeverage)
                    }
                } else if type == "caffeine" {
                    if let caffeineProduct = specializedProduct.toCaffeineProduct() {
                        return .caffeine(caffeineProduct)
                    }
                }
            }
            
            // Handle custom food
            var foodProduct: FoodProduct?
            
            if let isCustom = barcodeResponse.isCustom, isCustom == true {
                foodProduct = FoodProduct(
                    id: barcodeResponse.id ?? "",
                    productName: barcodeResponse.productName ?? "Custom Food",
                    brands: barcodeResponse.brands ?? "Custom",
                    calories: barcodeResponse.calories ?? 0,
                    protein: barcodeResponse.protein ?? 0,
                    carbs: barcodeResponse.carbs ?? 0,
                    fat: barcodeResponse.fat ?? 0
                )
            } else if let originalFood = barcodeResponse.originalFoodProduct {
                foodProduct = originalFood
            } else {
                // Fallback: try to decode as a direct food product
                foodProduct = try decoder.decode(FoodProduct.self, from: data)
            }
            
            // 3. If we have a food product, try fuzzy matching to alcohol/caffeine products
            if let food = foodProduct {
                // Ensure we have the latest alcohol and caffeine products cached
                await loadProductsForMapping()
                
                // Try to map the food product to specialized products
                if let mappingResult = ProductMappingService.shared.mapFoodProduct(food) {
                    switch mappingResult {
                    case .alcohol(let alcoholProduct):
                        print("FoodSearchAPI: Mapped food product '\(food.productName ?? "")' to alcohol product '\(alcoholProduct.name)'")
                        return .mappedAlcohol(food, alcoholProduct)
                    case .caffeine(let caffeineProduct):
                        print("FoodSearchAPI: Mapped food product '\(food.productName ?? "")' to caffeine product '\(caffeineProduct.name)'")
                        return .mappedCaffeine(food, caffeineProduct)
                    }
                }
                
                // No mapping found, return as regular food product
                return .food(food)
            }
            
            throw APIError.decodingError(NSError(domain: "FoodSearchAPI", code: -1, userInfo: [NSLocalizedDescriptionKey: "Could not decode product"]))
            
        } catch {
            // If decoding fails, wrap the error
                throw APIError.decodingError(error)
        }
    }
    
    /// Loads alcohol and caffeine products for mapping purposes
    private func loadProductsForMapping() async {
        // Only load if we haven't cached products recently
        // In a production app, you might want to implement cache expiration
        
        async let alcoholTask: Void = loadAlcoholProductsForMapping()
        async let caffeineTask: Void = loadCaffeineProductsForMapping()
        
        _ = await [alcoholTask, caffeineTask]
    }
    
    /// Loads popular alcohol products for mapping
    private func loadAlcoholProductsForMapping() async {
        do {
            let alcoholAPI = AlcoholAPI(httpClient: httpClient)
            // Get popular categories and fetch products from each
            let categoriesResponse = try await alcoholAPI.getAlcoholCategories()
            var allBeverages: [AlcoholicBeverage] = []
            
            // Fetch products from top categories (beer, wine, spirits)
            let popularCategories = ["beer", "wine", "spirits"]
            for category in popularCategories {
                do {
                    let categoryResponse = try await alcoholAPI.getBeveragesByCategory(categoryKey: category, limit: 100)
                    allBeverages.append(contentsOf: categoryResponse.beverages)
                } catch {
                    print("FoodSearchAPI: Failed to load category \(category): \(error)")
                }
            }
            
            ProductMappingService.shared.updateAlcoholProducts(allBeverages)
            print("FoodSearchAPI: Loaded \(allBeverages.count) alcohol products for mapping")
        } catch {
            print("FoodSearchAPI: Failed to load alcohol products for mapping: \(error)")
        }
    }
    
    /// Loads popular caffeine products for mapping
    private func loadCaffeineProductsForMapping() async {
        do {
            let caffeineAPI = CaffeineAPI(httpClient: httpClient)
            // Get popular categories and fetch products from each
            let categoriesResponse = try await caffeineAPI.getCaffeineCategories()
            var allProducts: [CaffeineProduct] = []
            
            // Fetch products from top categories (coffee, energy_drink, tea)
            let popularCategories = ["coffee", "energy_drink", "tea"]
            for category in popularCategories {
                do {
                    let categoryResponse = try await caffeineAPI.getProductsByCategory(categoryKey: category, pageSize: 100)
                    allProducts.append(contentsOf: categoryResponse.products)
                } catch {
                    print("FoodSearchAPI: Failed to load category \(category): \(error)")
                }
            }
            
            ProductMappingService.shared.updateCaffeineProducts(allProducts)
            print("FoodSearchAPI: Loaded \(allProducts.count) caffeine products for mapping")
        } catch {
            print("FoodSearchAPI: Failed to load caffeine products for mapping: \(error)")
        }
    }

    // Function to fetch a food product by ID
    func fetchProductById(productId: String) async throws -> FoodProduct {
        let endpoint = "/food-products/\(productId)/"
        
        do {
            let product: FoodProduct = try await httpClient.request(
                endpoint: endpoint,
                method: "GET",
                requiresAuth: true
            )
            return product
        } catch {
            throw error as? NetworkError ?? .custom(message: "Error fetching food product")
        }
    }
    
    // Function to fetch a custom food by ID
    func fetchCustomFoodById(customFoodId: Int) async throws -> CustomFoods {
        let endpoint = "/custom-foods/\(customFoodId)/"
        
        do {
            let customFood: CustomFoods = try await httpClient.request(
                endpoint: endpoint,
                method: "GET",
                requiresAuth: true
            )
            return customFood
        } catch {
            throw error as? NetworkError ?? .custom(message: "Error fetching custom food")
        }
    }

    // MARK: - Streak Related Methods
    
    /// Fetch streak data for the current user
    func fetchStreakData() async throws -> StreakData {
        let endpoint = "/streak/"
        
        do {
            let streakData: StreakData = try await httpClient.request(
                endpoint: endpoint,
                method: "GET",
                requiresAuth: true
            )
            return streakData
        } catch {
            throw error as? NetworkError ?? .custom(message: "Error fetching streak data")
        }
    }
    
    /// Share streak message
    func shareStreak() async throws -> ShareStreakResponse {
        let endpoint = "/streak/share/"
        
        do {
            let response: ShareStreakResponse = try await httpClient.request(
                endpoint: endpoint,
                method: "POST",
                requiresAuth: true
            )
            return response
        } catch {
            throw error as? NetworkError ?? .custom(message: "Error sharing streak")
        }
    }

    // MARK: - Water Tracking API Methods
    
    func logWater(amountMl: Double, containerType: String) async throws -> WaterEntry {
        let endpoint = "/nutrition/water-entries/log_water/"
        
        let requestBody = LogWaterRequest(amountMl: amountMl, containerType: containerType)
        
        do {
            let waterEntry: WaterEntry = try await httpClient.request(
                endpoint: endpoint,
                method: "POST",
                body: requestBody,
                requiresAuth: true
            )
            return waterEntry
        } catch {
            throw APIError.networkError(error)
        }
    }
    
    func getWaterSettings() async throws -> WaterSettings {
        let endpoint = "/nutrition/water-entries/settings/"
        
        do {
            let (data, _) = try await httpClient.requestData(
                endpoint: endpoint,
                method: "GET",
                requiresAuth: true
            )
            
            let decoder = JSONDecoder()
            let settings = try decoder.decode(WaterSettings.self, from: data)
            return settings
        } catch {
            throw APIError.networkError(error)
        }
    }
    
    func updateWaterSettings(waterGoalMl: Double, preferredUnit: String = "ml") async throws -> WaterSettings {
        let endpoint = "/nutrition/water-entries/settings/"
        
        let requestBody = UpdateWaterSettingsRequest(waterGoalMl: waterGoalMl, preferredUnit: preferredUnit)
        
        do {
            let settings: WaterSettings = try await httpClient.request(
                endpoint: endpoint,
                method: "PATCH",
                body: requestBody,
                requiresAuth: true
            )
            return settings
        } catch {
            throw APIError.networkError(error)
        }
    }
    
    func getWaterDailySummary(date: String? = nil) async throws -> WaterDailySummary {
        var endpoint = "/nutrition/water-entries/daily_summary/"
        
        if let date = date {
            endpoint += "?date=\(date)"
        }
        
        do {
            let (data, _) = try await httpClient.requestData(
                endpoint: endpoint,
                method: "GET",
                requiresAuth: true
            )
            
            let decoder = JSONDecoder()
            let summary = try decoder.decode(WaterDailySummary.self, from: data)
            return summary
        } catch {
            throw APIError.networkError(error)
        }
    }

}
