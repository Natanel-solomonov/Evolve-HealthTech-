import SwiftUI
import Combine // Needed for debouncing



// MARK: - NutritionViewModel (Long-Lived)
/// This view-model holds everything you need for the calorie tracker
/// and lives long enough to survive view transitions.
@MainActor
class NutritionViewModel: ObservableObject {
    // MARK: – Published state
    @Published var summary = DailyNutritionSummary()
    @Published var selectedFoodForConfirmation: FoodProduct? = nil
    @Published var todaysFoodEntries: [FoodEntry] = [] // Add this for live diary
    
    // Recent searches functionality
    @Published var recentSearches: [FoodProduct] = []
    private let recentSearchesKey = "RecentNutritionSearches"
    private let maxRecentSearches = 5
    
    // A reference to your AuthenticationManager (which provides the httpClient and currentUser)
    let authManager: AuthenticationManager
    
    // Keep track of whether we've loaded or created today's log already
    private var isLoadingLog = false
    
    // Store Combine subscriptions
    private var cancellables = Set<AnyCancellable>()
    
    init(authManager: AuthenticationManager) {
        self.authManager = authManager
        loadGoalsFromUserDefaults()
        loadRecentSearches()
        Task {
            await loadDailyLog()
            await loadTodaysFoodEntries() // Load diary entries on initialization
        }
    }
    
    // MARK: - Recent Searches
    func addToRecentSearches(_ food: FoodProduct) {
        // Remove if already exists
        recentSearches.removeAll { $0.id == food.id }
        
        // Add to beginning
        recentSearches.insert(food, at: 0)
        
        // Keep only max number of recent searches
        if recentSearches.count > maxRecentSearches {
            recentSearches = Array(recentSearches.prefix(maxRecentSearches))
        }
        
        saveRecentSearches()
    }
    
    func clearRecentSearches() {
        recentSearches.removeAll()
        UserDefaults.standard.removeObject(forKey: recentSearchesKey)
    }
    
    private func saveRecentSearches() {
        do {
            let data = try JSONEncoder().encode(recentSearches)
            UserDefaults.standard.set(data, forKey: recentSearchesKey)
        } catch {
            print("Failed to save recent searches: \(error)")
        }
    }
    
    private func loadRecentSearches() {
        guard let data = UserDefaults.standard.data(forKey: recentSearchesKey) else { return }
        
        do {
            recentSearches = try JSONDecoder().decode([FoodProduct].self, from: data)
        } catch {
            print("Failed to load recent searches: \(error)")
            recentSearches = []
        }
    }
    
    // MARK: – Public methods
    
    /// Call when you want to manually refresh (e.g. if user taps "Refresh")
    @MainActor
    func reloadCurrentLog() async {
        print("NutritionViewModel: reloadCurrentLog called")
        await loadDailyLog()
        await loadTodaysFoodEntries() // Add this
        print("NutritionViewModel: reloadCurrentLog completed - Cals: \(summary.caloriesEaten), Protein: \(summary.proteinEaten), Carbs: \(summary.carbsEaten), Fat: \(summary.fatEaten)")
    }
    
    /// Refresh diary entries specifically
    @MainActor
    func refreshDiary() async {
        print("NutritionViewModel: refreshDiary called")
        await loadTodaysFoodEntries()
        print("NutritionViewModel: refreshDiary completed - Loaded \(todaysFoodEntries.count) entries")
    }
    
    /// When the user logs a FoodEntry, call this to update `summary` immediately:
    @MainActor
    func handleLogSuccess(loggedCals: Double, loggedProtein: Double, loggedCarbs: Double, loggedFat: Double,
                          loggedFiber: Double, loggedIron: Double, loggedCalcium: Double, loggedVitaminA: Double,
                          loggedVitaminC: Double, loggedB12: Double, loggedFolate: Double, loggedPotassium: Double,
                          loggedAlcoholGrams: Double = 0.0, loggedStandardDrinks: Double = 0.0) {
        print("NutritionViewModel: handleLogSuccess called with - Cals: \(loggedCals), Protein: \(loggedProtein), Carbs: \(loggedCarbs), Fat: \(loggedFat), Alcohol: \(loggedAlcoholGrams), Drinks: \(loggedStandardDrinks)")
        print("NutritionViewModel: Before update - Cals: \(summary.caloriesEaten), Protein: \(summary.proteinEaten), Carbs: \(summary.carbsEaten), Fat: \(summary.fatEaten), Alcohol: \(summary.alcoholGrams), Drinks: \(summary.standardDrinks)")
        
        // Create a new summary object to trigger UI updates
        var newSummary = summary
        newSummary.caloriesEaten += Int(loggedCals.rounded())
        newSummary.proteinEaten += loggedProtein
        newSummary.carbsEaten += loggedCarbs
        newSummary.fatEaten += loggedFat
        
        // Add micronutrients
        newSummary.fiberGrams += loggedFiber
        newSummary.ironMilligrams += loggedIron
        newSummary.calciumMilligrams += loggedCalcium
        newSummary.vitaminAMicrograms += loggedVitaminA
        newSummary.vitaminCMilligrams += loggedVitaminC
        newSummary.vitaminB12Micrograms += loggedB12
        newSummary.folateMicrograms += loggedFolate
        newSummary.potassiumMilligrams += loggedPotassium
        
        // Add alcohol tracking
        newSummary.alcoholGrams += loggedAlcoholGrams
        newSummary.standardDrinks += loggedStandardDrinks
        
        // Assign the new summary to trigger UI updates
        summary = newSummary
        
        print("NutritionViewModel: After update - Cals: \(summary.caloriesEaten), Protein: \(summary.proteinEaten), Carbs: \(summary.carbsEaten), Fat: \(summary.fatEaten), Alcohol: \(summary.alcoholGrams), Drinks: \(summary.standardDrinks)")
        
        // Reload today's food entries to ensure diary is updated
        Task {
            await loadTodaysFoodEntries()
        }
    }
    
    /// Handle successful caffeine product logging with immediate UI updates
    @MainActor
    func handleCaffeineLogSuccess(loggedCals: Double, loggedProtein: Double, loggedCarbs: Double, loggedFat: Double,
                                  loggedFiber: Double, loggedIron: Double, loggedCalcium: Double, loggedVitaminA: Double,
                                  loggedVitaminC: Double, loggedB12: Double, loggedFolate: Double, loggedPotassium: Double,
                                  loggedCaffeineMg: Double) {
        print("NutritionViewModel: handleCaffeineLogSuccess called with - Cals: \(loggedCals), Caffeine: \(loggedCaffeineMg)mg")
        print("NutritionViewModel: Before update - Caffeine: \(summary.caffeineMg)mg")
        
        // Create a new summary object to trigger UI updates
        var newSummary = summary
        newSummary.caloriesEaten += Int(loggedCals.rounded())
        newSummary.proteinEaten += loggedProtein
        newSummary.carbsEaten += loggedCarbs
        newSummary.fatEaten += loggedFat
        
        // Add micronutrients
        newSummary.fiberGrams += loggedFiber
        newSummary.ironMilligrams += loggedIron
        newSummary.calciumMilligrams += loggedCalcium
        newSummary.vitaminAMicrograms += loggedVitaminA
        newSummary.vitaminCMilligrams += loggedVitaminC
        newSummary.vitaminB12Micrograms += loggedB12
        newSummary.folateMicrograms += loggedFolate
        newSummary.potassiumMilligrams += loggedPotassium
        
        // Add caffeine tracking
        newSummary.caffeineMg += loggedCaffeineMg
        
        // Assign the new summary to trigger UI updates
        summary = newSummary
        
        print("NutritionViewModel: After update - Caffeine: \(summary.caffeineMg)mg")
        
        // Reload today's food entries to ensure diary is updated
        Task {
            await loadTodaysFoodEntries()
        }
    }
    
    /// When a FoodEntry is deleted, subtract its values:
    @MainActor
    func handleEntryDeletion(_ deletedEntry: FoodEntry) {
        // Create a new summary object to trigger UI updates
        var newSummary = summary
        newSummary.caloriesEaten = max(0, summary.caloriesEaten - (deletedEntry.calories ?? 0))
        newSummary.proteinEaten = max(0, summary.proteinEaten - (deletedEntry.protein ?? 0.0))
        newSummary.carbsEaten = max(0, summary.carbsEaten - (deletedEntry.carbs ?? 0.0))
        newSummary.fatEaten = max(0, summary.fatEaten - (deletedEntry.fat ?? 0.0))
        
        // Handle micronutrients
        newSummary.fiberGrams = max(0, summary.fiberGrams - (deletedEntry.fiberGrams ?? 0.0))
        newSummary.ironMilligrams = max(0, summary.ironMilligrams - (deletedEntry.ironMilligrams ?? 0.0))
        newSummary.calciumMilligrams = max(0, summary.calciumMilligrams - (deletedEntry.calciumMilligrams ?? 0.0))
        newSummary.vitaminAMicrograms = max(0, summary.vitaminAMicrograms - (deletedEntry.vitaminAMicrograms ?? 0.0))
        newSummary.vitaminCMilligrams = max(0, summary.vitaminCMilligrams - (deletedEntry.vitaminCMilligrams ?? 0.0))
        newSummary.vitaminB12Micrograms = max(0, summary.vitaminB12Micrograms - (deletedEntry.vitaminB12Micrograms ?? 0.0))
        newSummary.folateMicrograms = max(0, summary.folateMicrograms - (deletedEntry.folateMicrograms ?? 0.0))
        newSummary.potassiumMilligrams = max(0, summary.potassiumMilligrams - (deletedEntry.potassiumMilligrams ?? 0.0))
        
        // Handle alcohol tracking fields
        newSummary.alcoholGrams = max(0, summary.alcoholGrams - (deletedEntry.alcoholGrams ?? 0.0))
        newSummary.standardDrinks = max(0, summary.standardDrinks - (deletedEntry.standardDrinks ?? 0.0))
        
        // Handle caffeine tracking fields
        newSummary.caffeineMg = max(0, summary.caffeineMg - (deletedEntry.caffeineMg ?? 0.0))
        
        // Assign the new summary to trigger UI updates
        summary = newSummary
    }
    
    /// Delete a food entry from today's diary
    @MainActor
    func deleteFoodEntry(_ entry: FoodEntry) async {
        let entryId = entry.id
        
        // Remove from local state first
        todaysFoodEntries.removeAll { $0.id == entryId }
        
        // Update summary by subtracting this entry's values
        handleEntryDeletion(entry)
        
        // Delete from backend
        let foodSearchAPI = FoodSearchAPI(httpClient: authManager.httpClient)
        foodSearchAPI.deleteFoodEntry(entryId: entryId) { result in
            Task { @MainActor in
                if case .failure(let error) = result {
                    print("Failed to delete entry: \(error.localizedDescription)")
                    // Reload on error to restore correct state
                    await self.reloadCurrentLog()
                }
            }
        }
    }
    
    /// Load today's food entries for the live diary
    @MainActor
    private func loadTodaysFoodEntries() async {
        guard let userPhone = authManager.currentUser?.phone else {
            print("NutritionViewModel: No user phone available for loading food entries")
            return
        }
        
        let foodSearchAPI = FoodSearchAPI(httpClient: authManager.httpClient)
        let result = await foodSearchAPI.fetchDailyLogEntries(userPhone: userPhone, date: Date())
        
        switch result {
        case .success(let entries):
            todaysFoodEntries = entries
            print("NutritionViewModel: Loaded \(entries.count) food entries for today")
        case .failure(let error):
            print("NutritionViewModel: Failed to load today's food entries: \(error.localizedDescription)")
            todaysFoodEntries = []
        }
    }
    
    /// Force reload today's food entries - public method for UI to call
    @MainActor
    func loadTodaysFoodEntriesPublic() async {
        await loadTodaysFoodEntries()
    }
    
    /// Show food confirmation view for editing an entry
    @MainActor
    func showFoodConfirmation(for entry: FoodEntry, foodProductId: String) async {
        print("NutritionViewModel: showFoodConfirmation called for entry: \(entry.foodName)")
        print("NutritionViewModel: foodProductId: '\(foodProductId)'")
        
        let foodSearchAPI = FoodSearchAPI(httpClient: authManager.httpClient)
        
        // Check if we have a valid original food product ID
        if !foodProductId.isEmpty && !foodProductId.hasPrefix("entry_") {
            // Try to fetch the original food product
            do {
                let foodProduct = try await foodSearchAPI.fetchProductById(productId: foodProductId)
                selectedFoodForConfirmation = foodProduct
                print("NutritionViewModel: Successfully fetched food product: \(foodProduct.productName ?? "Unknown")")
                addToRecentSearches(foodProduct) // Add to recent searches when a food is selected
                return
            } catch {
                print("NutritionViewModel: Failed to fetch food product for confirmation: \(error.localizedDescription)")
                // Fall back to creating from entry data
            }
        }
        
        // Check if it's a custom food
        if let customFoodId = entry.customFoodId {
            do {
                let customFood = try await foodSearchAPI.fetchCustomFoodById(customFoodId: customFoodId)
                let foodProduct = convertCustomFoodToFoodProduct(customFood)
                selectedFoodForConfirmation = foodProduct
                print("NutritionViewModel: Successfully fetched custom food: \(foodProduct.productName ?? "Unknown")")
                addToRecentSearches(foodProduct)
                return
            } catch {
                print("NutritionViewModel: Failed to fetch custom food for confirmation: \(error.localizedDescription)")
            }
        }
        
        // Fall back to creating a standard nutrition display from entry data
        print("NutritionViewModel: Creating standard FoodProduct from entry data for display only")
        createStandardFoodProductFromEntry(entry)
    }
    
    /// Create a FoodProduct with standard nutrition info from existing FoodEntry data
    /// This calculates per-100g nutrition values from the entry's tracked amounts
    @MainActor
    private func createStandardFoodProductFromEntry(_ entry: FoodEntry) {
        // Determine brand based on entry type
        let brand: String
        if entry.customFoodId != nil {
            brand = "Custom Food"
        } else if entry.foodProductId != nil {
            brand = "Unknown Brand" // For foods from database that don't have brand info
        } else {
            brand = "Unknown Brand" // For manually logged foods
        }
        
        // Calculate per-100g nutrition values from the tracked entry
        // This assumes the entry values are for the specific serving size tracked
        let servingSizeInGrams = entry.servingUnit == "g" ? entry.servingSize : 100.0 // Default fallback
        let factor = servingSizeInGrams > 0 ? 100.0 / servingSizeInGrams : 1.0
        
        let foodProduct = FoodProduct(
            id: entry.foodProductId ?? "manual_\(entry.id)", // Use original ID or create manual ID
            productName: entry.foodName,
            brands: brand,
            calories: Double(entry.calories ?? 0) * factor,
            protein: (entry.protein ?? 0.0) * factor,
            carbs: (entry.carbs ?? 0.0) * factor,
            fat: (entry.fat ?? 0.0) * factor,
            calcium: (entry.calciumMilligrams ?? 0.0) * factor,
            iron: (entry.ironMilligrams ?? 0.0) * factor,
            potassium: (entry.potassiumMilligrams ?? 0.0) * factor,
            vitamin_a: (entry.vitaminAMicrograms ?? 0.0) * factor,
            vitamin_c: (entry.vitaminCMilligrams ?? 0.0) * factor,
            vitamin_b12: (entry.vitaminB12Micrograms ?? 0.0) * factor,
            fiber: (entry.fiberGrams ?? 0.0) * factor,
            folate: (entry.folateMicrograms ?? 0.0) * factor
        )
        selectedFoodForConfirmation = foodProduct
        print("NutritionViewModel: Created standard FoodProduct from entry: \(foodProduct.productName ?? "Unknown Product") (per 100g values)")
        addToRecentSearches(foodProduct) // Add to recent searches when a food is selected
    }
    
    /// Convert custom food to FoodProduct format
    @MainActor
    private func convertCustomFoodToFoodProduct(_ customFood: CustomFoods) -> FoodProduct {
        return FoodProduct(
            id: "custom_\(customFood.id)",
            productName: customFood.name,
            brands: "Custom Food",
            calories: customFood.calories,
            protein: customFood.protein,
            carbs: customFood.carbs,
            fat: customFood.fat,
            calcium: customFood.calcium ?? 0.0,
            iron: customFood.iron ?? 0.0,
            potassium: customFood.potassium ?? 0.0,
            vitamin_a: customFood.vitaminA ?? 0.0,
            vitamin_c: customFood.vitaminC ?? 0.0,
            vitamin_b12: customFood.vitaminB12 ?? 0.0,
            fiber: 0.0, // Custom foods don't have fiber data
            folate: 0.0 // Custom foods don't have folate data
        )
    }
    
    @MainActor
    func updateGoal(for target: GoalTarget, value: Double) {
        switch target {
        case .calories:
            summary.caloriesGoal = Int(value)
            UserDefaults.standard.set(Int(value), forKey: "caloriesGoal")
        case .carbs:
            summary.carbsGoal = value
            UserDefaults.standard.set(value, forKey: "carbsGoal")
        case .protein:
            summary.proteinGoal = value
            UserDefaults.standard.set(value, forKey: "proteinGoal")
        case .fat:
            summary.fatGoal = value
            UserDefaults.standard.set(value, forKey: "fatGoal")
        }
    }
    
    // MARK: – Private helpers
    
    /// Formats a Date into "YYYY-MM-DD"
    private func isoDateString(from date: Date) -> String {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        return df.string(from: date)
    }
    
    /// Loads (GET) the DailyLog for a given date; if 404, automatically creates it
    @MainActor
    private func loadDailyLog() async {
        guard !isLoadingLog else {
            print("NutritionViewModel: Already loading log, returning.")
            return
        }
        isLoadingLog = true
        let date = Date()
        print("NutritionViewModel: Starting to load log for \(isoDateString(from: date))")
        defer {
            isLoadingLog = false
            print("NutritionViewModel: Finished loading log for \(isoDateString(from: date))")
        }
        
        guard let userId = authManager.currentUser?.id else {
            print("NutritionViewModel Error: Missing user ID. Resetting summary.")
            summary = DailyNutritionSummary()
            return
        }
        
        let iso = isoDateString(from: date)
        let endpoint = "/user_daily_log/\(userId)/\(iso)/"
        
        do {
            let response: DailyLogResponse = try await authManager.httpClient.request(
                endpoint: endpoint,
                method: "GET",
                requiresAuth: true
            )
            
            // Create a new summary object to trigger UI updates
            var newSummary = summary
            newSummary.dailyLogId = response.id
            newSummary.caloriesEaten = response.totalCalories
            newSummary.caloriesGoal = UserDefaults.standard.integer(forKey: "caloriesGoal") > 0 ? UserDefaults.standard.integer(forKey: "caloriesGoal") : response.calorieGoal
            newSummary.proteinEaten = response.proteinGrams
            newSummary.carbsEaten = response.carbsGrams
            newSummary.fatEaten = response.fatGrams
            
            // Load micronutrients
            newSummary.fiberGrams = response.fiberGrams ?? 0
            newSummary.ironMilligrams = response.ironMilligrams ?? 0
            newSummary.calciumMilligrams = response.calciumMilligrams ?? 0
            newSummary.vitaminAMicrograms = response.vitaminAMicrograms ?? 0
            newSummary.vitaminCMilligrams = response.vitaminCMilligrams ?? 0
            newSummary.vitaminB12Micrograms = response.vitaminB12Micrograms ?? 0
            newSummary.folateMicrograms = response.folateMicrograms ?? 0
            newSummary.potassiumMilligrams = response.potassiumMilligrams ?? 0
            
            // Load alcohol data
            newSummary.alcoholGrams = response.alcoholGrams ?? 0
            newSummary.standardDrinks = response.standardDrinks ?? 0
            
            // Load caffeine data
            newSummary.caffeineMg = response.caffeineMg ?? 0
            
            // Assign the new summary to trigger UI updates
            summary = newSummary
            
            print("NutritionViewModel: Successfully loaded log for \(iso). ID: \(response.id), Cals: \(response.totalCalories)/\(summary.caloriesGoal)")
            print("NutritionViewModel: Loaded data - Protein: \(response.proteinGrams), Carbs: \(response.carbsGrams), Fat: \(response.fatGrams)")
            print("NutritionViewModel: Loaded micronutrients - Fiber: \(response.fiberGrams ?? 0), Iron: \(response.ironMilligrams ?? 0), Calcium: \(response.calciumMilligrams ?? 0)")
            
        } catch let netErr as NetworkError {
            if case .serverError(let code, _) = netErr, code == 404 {
                print("NutritionViewModel: No log found (404) for \(iso), attempting to create...")
                await createDailyLog(userId: userId, isoDate: iso)
            } else {
                print("NutritionViewModel: Network or decoding error while loading log for \(iso): \(netErr). Resetting summary.")
                summary = DailyNutritionSummary()
                loadGoalsFromUserDefaults()
            }
        } catch {
            print("NutritionViewModel: Unexpected error while loading log for \(iso): \(error). Resetting summary.")
            summary = DailyNutritionSummary()
            loadGoalsFromUserDefaults()
        }
    }
    
    @MainActor
    private func createDailyLog(userId: String, isoDate: String) async {
        let endpoint = "/user_daily_log/\(userId)/\(isoDate)/"
        print("NutritionViewModel: Creating log for \(isoDate) at \(endpoint)")
        do {
            let created: DailyLogResponse = try await authManager.httpClient.request(
                endpoint: endpoint,
                method: "POST",
                body: Optional<String>.none,
                requiresAuth: true
            )
            
            // Create a new summary object to trigger UI updates
            var newSummary = summary
            newSummary.dailyLogId = created.id
            newSummary.caloriesEaten = created.totalCalories
            newSummary.caloriesGoal = UserDefaults.standard.integer(forKey: "caloriesGoal") > 0 ? UserDefaults.standard.integer(forKey: "caloriesGoal") : created.calorieGoal
            newSummary.proteinEaten = created.proteinGrams
            newSummary.carbsEaten = created.carbsGrams
            newSummary.fatEaten = created.fatGrams
            
            // Initialize micronutrients
            newSummary.fiberGrams = created.fiberGrams ?? 0
            newSummary.ironMilligrams = created.ironMilligrams ?? 0
            newSummary.calciumMilligrams = created.calciumMilligrams ?? 0
            newSummary.vitaminAMicrograms = created.vitaminAMicrograms ?? 0
            newSummary.vitaminCMilligrams = created.vitaminCMilligrams ?? 0
            newSummary.vitaminB12Micrograms = created.vitaminB12Micrograms ?? 0
            newSummary.folateMicrograms = created.folateMicrograms ?? 0
            newSummary.potassiumMilligrams = created.potassiumMilligrams ?? 0
            
            // Initialize alcohol data
            newSummary.alcoholGrams = created.alcoholGrams ?? 0
            newSummary.standardDrinks = created.standardDrinks ?? 0
            
            // Initialize caffeine data
            newSummary.caffeineMg = created.caffeineMg ?? 0
            
            // Assign the new summary to trigger UI updates
            summary = newSummary
            
            print("NutritionViewModel: Successfully created log for \(isoDate). ID: \(created.id), Cals: \(created.totalCalories)/\(summary.caloriesGoal)")
            print("NutritionViewModel: Created data - Protein: \(created.proteinGrams), Carbs: \(created.carbsGrams), Fat: \(created.fatGrams)")
            print("NutritionViewModel: Created micronutrients - Fiber: \(created.fiberGrams ?? 0), Iron: \(created.ironMilligrams ?? 0), Calcium: \(created.calciumMilligrams ?? 0)")
        } catch {
            print("NutritionViewModel: Error creating log for \(isoDate): \(error). Resetting summary.")
            summary = DailyNutritionSummary()
            loadGoalsFromUserDefaults()
        }
    }
    
    // ADDED: Method to log a new food entry
    @MainActor
    func logFoodEntry(_ foodEntry: FoodEntry, for userPhone: String) async -> Bool {
        struct FoodEntryPayload: Codable { // Ensure this struct matches what backend expects if not FoodEntry directly
            let foodName: String
            let servingSize: Double
            let servingUnit: String
            let calories: Int?
            let protein: Double?
            let carbs: Double?
            let fat: Double?
            let mealType: String
            let timeConsumed: String // ISO8601 string
            let foodProductId: String?
            let userPhone: String
        }
        
        let payload = FoodEntryPayload(
            foodName: foodEntry.foodName,
            servingSize: foodEntry.servingSize,
            servingUnit: foodEntry.servingUnit,
            calories: foodEntry.calories,
            protein: foodEntry.protein,
            carbs: foodEntry.carbs,
            fat: foodEntry.fat,
            mealType: foodEntry.mealType,
            timeConsumed: foodEntry.timeConsumed,
            foodProductId: foodEntry.foodProductId, // Now valid due to model change
            userPhone: userPhone
        )
        
        print("NutritionViewModel: Attempting to log food entry: \(payload.foodName) for user \(userPhone)")
        
        do {
            let (responseData, httpResponse) = try await authManager.httpClient.requestData(
                endpoint: "/food-entries/",
                method: "POST",
                body: payload,
                requiresAuth: true
            )
            
            if (200...299).contains(httpResponse.statusCode) {
                print("NutritionViewModel: Successfully logged food entry '\(payload.foodName)' to backend. Status: \(httpResponse.statusCode)")
                handleLogSuccess(
                    loggedCals: Double(payload.calories ?? 0),
                    loggedProtein: payload.protein ?? 0,
                    loggedCarbs: payload.carbs ?? 0,
                    loggedFat: payload.fat ?? 0,
                    loggedFiber: 0,
                    loggedIron: 0,
                    loggedCalcium: 0,
                    loggedVitaminA: 0,
                    loggedVitaminC: 0,
                    loggedB12: 0,
                    loggedFolate: 0,
                    loggedPotassium: 0
                )
                return true
            } else {
                // Cleaned up String conversion for error details
                let errorDetails = String(data: responseData, encoding: .utf8) ?? "(Could not decode error response body as UTF-8)"
                print("NutritionViewModel: Failed to log food entry '\(payload.foodName)'. Status: \(httpResponse.statusCode). Response: \(errorDetails)")
                return false
            }
        } catch {
            print("NutritionViewModel: Error logging food entry '\(payload.foodName)': \(error.localizedDescription)")
            return false
        }
    }
    
    @MainActor
    private func loadGoalsFromUserDefaults() {
        let standardCalories = 2000
        summary.caloriesGoal = UserDefaults.standard.integer(forKey: "caloriesGoal") > 0 ? UserDefaults.standard.integer(forKey: "caloriesGoal") : standardCalories
        
        let calorieGoalDouble = Double(summary.caloriesGoal)
        summary.carbsGoal = UserDefaults.standard.double(forKey: "carbsGoal") > 0 ? UserDefaults.standard.double(forKey: "carbsGoal") : (calorieGoalDouble * 0.5 / 4)
        summary.proteinGoal = UserDefaults.standard.double(forKey: "proteinGoal") > 0 ? UserDefaults.standard.double(forKey: "proteinGoal") : (calorieGoalDouble * 0.25 / 4)
        summary.fatGoal = UserDefaults.standard.double(forKey: "fatGoal") > 0 ? UserDefaults.standard.double(forKey: "fatGoal") : (calorieGoalDouble * 0.25 / 9)
    }
}

// MARK: - Data Models (Placeholders)
    // Replace with your actual data models later
    struct DailyNutritionSummary {
        var caloriesEaten: Int = 0
        var caloriesGoal: Int = 2000
        var caloriesLeft: Int { // Calculated property
            max(0, caloriesGoal - caloriesEaten - caloriesBurned)
        }
        var caloriesBurned: Int = 0 // Assuming this might still be client-side or from another source
        var carbsGoal: Double = 250
        var carbsEaten: Double = 0
        var proteinGoal: Double = 125
        var proteinEaten: Double = 0
        var fatGoal: Double = 55
        var fatEaten: Double = 0
        
        // Micronutrients
        var fiberGrams: Double = 0
        var ironMilligrams: Double = 0
        var calciumMilligrams: Double = 0
        var vitaminAMicrograms: Double = 0
        var vitaminCMilligrams: Double = 0
        var vitaminB12Micrograms: Double = 0
        var folateMicrograms: Double = 0
        var potassiumMilligrams: Double = 0
        
        // Alcohol tracking
        var alcoholGrams: Double = 0
        var standardDrinks: Double = 0
        
        // Caffeine tracking
        var caffeineMg: Double = 0
        
        // Water tracking
        var waterMl: Double = 0
        var waterGoalMl: Double = 2000
        
        // Recommended meal cals can be kept if they are UI-specific calculations
        var recommendedBreakfastCals: ClosedRange<Int> = 666...932
        var recommendedLunchCals: ClosedRange<Int> = 799...1065
        var recommendedDinnerCals: ClosedRange<Int> = 1039...1358
        var recommendedSnackCals: ClosedRange<Int> = 0...300 // Added for Snack
        
        // Store the actual log ID if needed
        var dailyLogId: Int? = nil
    }
    
    // MARK: - Main Nutrition View
    
    struct NutritionView: View {
        @EnvironmentObject var authManager: AuthenticationManager // ADDED
        @ObservedObject var viewModel: NutritionViewModel // ADDED
        
        // Updated Evolve Color Scheme to match DashboardView
        var gradientStartColor: Color { Color("Nutrition").opacity(0.6) } // Dashboard's Mind color
        var gradientEndColor: Color { Color("Nutrition") } // Dashboard's Sleep color
        var accentColor: Color { Color.blue } // A vibrant blue for accents, similar to Dashboard interactive elements
        // Card background will be white with opacity, similar to DashboardView's CardView
        // This will be applied directly in the subviews or via a modifier
        
        init(viewModel: NutritionViewModel) { // ADDED init
            self.viewModel = viewModel
        }
        
        var body: some View {
            // Pass viewModel to NutritionContentView
            NutritionContentView(
                viewModel: viewModel, // Pass the whole viewModel
                gradientStartColor: gradientStartColor,
                gradientEndColor: gradientEndColor,
                accentColor: accentColor
                // cardBackgroundColor and bottomBarColor will be handled by new styling
            )
            // REMOVE .onAppear and .onChange(of: currentDate) for data loading
            // as the viewModel handles this internally.
        }
    }
    
    // MARK: - Content View (Main UI)
    
    // Define context struct to hold data for the confirmation sheet
    struct FoodConfirmationContext: Identifiable {
        let id: String // Use food's ID for Identifiable conformance
        let food: FoodProduct
        let mealType: String
        
        init(food: FoodProduct, mealType: String) {
            self.id = food.id
            self.food = food
            self.mealType = mealType
        }
    }
    
    enum NutritionScreen: Equatable {
        case main
        case history
        case addFood
        case myFoods
        case createFood
        case streaks
        case alcoholCategories
        case alcoholBrowser(AlcoholCategory)
        case caffeineCategories
        case caffeineBrowser(CaffeineCategory)
        case caffeineProductDetail(CaffeineProduct)
        case alcoholProductDetail(AlcoholicBeverage)
        
        static func == (lhs: NutritionScreen, rhs: NutritionScreen) -> Bool {
            switch (lhs, rhs) {
            case (.main, .main),
                (.history, .history),
                (.addFood, .addFood),
                (.myFoods, .myFoods),
                (.createFood, .createFood),
                (.streaks, .streaks),
                (.alcoholCategories, .alcoholCategories),
                (.caffeineCategories, .caffeineCategories):
                return true
            case (.alcoholBrowser(let lhsCategory), .alcoholBrowser(let rhsCategory)):
                return lhsCategory == rhsCategory
            case (.caffeineBrowser(let lhsCategory), .caffeineBrowser(let rhsCategory)):
                return lhsCategory == rhsCategory
            case (.caffeineProductDetail(let lhsProduct), .caffeineProductDetail(let rhsProduct)):
                return lhsProduct.id == rhsProduct.id
            case (.alcoholProductDetail(let lhsProduct), .alcoholProductDetail(let rhsProduct)):
                return lhsProduct.id == rhsProduct.id
            default:
                return false
            }
        }
    }
    
    struct NutritionContentView: View {
        @EnvironmentObject var authManager: AuthenticationManager
        @ObservedObject var viewModel: NutritionViewModel
        @Environment(\.presentationMode) var presentationMode
        
        @State private var activeScreen: NutritionScreen = .main
        @State private var confirmationContext: FoodConfirmationContext? = nil
        @State private var showAddFoodView = false
        @State private var editingTarget: GoalTarget? = nil
        @State private var selectedTab = 0
        
        @State private var searchText: String = ""
        @State private var searchResults: [FoodProduct] = []
        @State private var isLoadingFoodSearch: Bool = false
        @State private var foodSearchErrorMessage: String?
        @State private var showCreateFoodView: Bool = false
        @State private var showBarcodeNoResultsView: Bool = false
        @State private var showWaterSettings: Bool = false
        @State private var preferredWaterUnit: WaterUnit = .milliliters // Add state for water unit preference
        
        @StateObject private var barcodeScannerViewModel: BarcodeScannerViewModel
        @State private var searchSubject = PassthroughSubject<String, Never>()
        @StateObject private var foodSearchAPI: FoodSearchAPI
        
        let gradientStartColor: Color
        let gradientEndColor: Color
        let accentColor: Color
        
        init(viewModel: NutritionViewModel, gradientStartColor: Color, gradientEndColor: Color, accentColor: Color) {
            self.viewModel = viewModel
            self.gradientStartColor = gradientStartColor
            self.gradientEndColor = gradientEndColor
            self.accentColor = accentColor
            
                    // Initialize StateObjects
        self._barcodeScannerViewModel = StateObject(wrappedValue: BarcodeScannerViewModel(authenticationManager: viewModel.authManager))
        self._foodSearchAPI = StateObject(wrappedValue: FoodSearchAPI(httpClient: AuthenticatedHTTPClient(authenticationManager: viewModel.authManager)))
        }
        
        // Helper method to get current daily tracker for alcohol card
        private func getCurrentDailyTracker() -> DailyCalorieTracker? {
            // Convert current summary to DailyCalorieTracker format
            // This is a simplified conversion - in a real app you'd have this data from the API
            let tracker = DailyCalorieTracker(
                id: viewModel.summary.dailyLogId ?? 0,
                userDetails: authManager.currentUser?.id ?? "",
                date: DateFormatter().string(from: Date()),
                totalCalories: viewModel.summary.caloriesEaten,
                calorieGoal: viewModel.summary.caloriesGoal,
                proteinGrams: viewModel.summary.proteinEaten,
                carbsGrams: viewModel.summary.carbsEaten,
                fatGrams: viewModel.summary.fatEaten,
                fiberGrams: viewModel.summary.fiberGrams,
                ironMilligrams: viewModel.summary.ironMilligrams,
                calciumMilligrams: viewModel.summary.calciumMilligrams,
                vitaminAMicrograms: viewModel.summary.vitaminAMicrograms,
                vitaminCMilligrams: viewModel.summary.vitaminCMilligrams,
                vitaminB12Micrograms: viewModel.summary.vitaminB12Micrograms,
                folateMicrograms: viewModel.summary.folateMicrograms,
                potassiumMilligrams: viewModel.summary.potassiumMilligrams,
                alcoholGrams: viewModel.summary.alcoholGrams,
                standardDrinks: viewModel.summary.standardDrinks,
                caffeineMg: viewModel.summary.caffeineMg,
                createdAt: "",
                updatedAt: "",
                foodEntries: viewModel.todaysFoodEntries
            )
            
            print("getCurrentDailyTracker: Created tracker with \(tracker.foodEntries.count) food entries")
            print("getCurrentDailyTracker: Alcohol grams from summary: \(viewModel.summary.alcoholGrams)")
            print("getCurrentDailyTracker: Standard drinks from summary: \(viewModel.summary.standardDrinks)")
            print("getCurrentDailyTracker: Caffeine mg from summary: \(viewModel.summary.caffeineMg)")
            
            return tracker
        }
        
        
        
        private var customHeader: some View {
            VStack(spacing: 0) {
                // Top row with back button
                HStack {
                    Button(action: {
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        Image(systemName: "chevron.left")
                            .font(.title2)
                            .foregroundColor(.white)
                    }
                    
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.top, 8)
                
                // Main header content below
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Nutrition")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                        
                        Text(getCurrentDateString())
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.8))
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                    
                    Spacer()
                    
                    HStack(spacing: 16) {
                        Button(action: {
                            activeScreen = .streaks
                        }) {
                            Image(systemName: "flame.fill")
                                .font(.title2)
                                .foregroundColor(.white)
                                .frame(width: 44, height: 44)
                                .background(Color.white.opacity(0.2))
                                .clipShape(Circle())
                        }
                        
                        Button(action: {
                            activeScreen = .myFoods
                        }) {
                            Image(systemName: "fork.knife")
                                .font(.title2)
                                .foregroundColor(.white)
                                .frame(width: 44, height: 44)
                                .background(Color.white.opacity(0.2))
                                .clipShape(Circle())
                        }
                        
                        Button(action: {
                            activeScreen = .history
                        }) {
                            Image(systemName: "calendar")
                                .font(.title2)
                                .foregroundColor(.white)
                                .frame(width: 44, height: 44)
                                .background(Color.white.opacity(0.2))
                                .clipShape(Circle())
                        }
                        
                        Button(action: {
                            barcodeScannerViewModel.showScannerSheet = true
                        }) {
                            Image(systemName: "barcode.viewfinder")
                                .font(.title2)
                                .foregroundColor(.white)
                                .frame(width: 44, height: 44)
                                .background(Color.white.opacity(0.2))
                                .clipShape(Circle())
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 8)
            }
        }
        
        private func getCurrentDateString() -> String {
            let formatter = DateFormatter()
            formatter.dateStyle = .full
            formatter.timeStyle = .none
            return formatter.string(from: Date())
        }
        
        private var historyHeader: some View {
            HStack {
                Button(action: { activeScreen = .main }) {
                    Image(systemName: "chevron.left").font(.system(size: 22)).foregroundColor(.white)
                }
                Spacer()
                Text("History").font(.system(size: 17, weight: .bold)).foregroundColor(.white)
                Spacer()
                Image(systemName: "chevron.left").font(.system(size: 22)).foregroundColor(.clear) // For spacing
            }
            .padding(.horizontal)
            .padding(.vertical, 10)
        }
        
        var body: some View {
            ZStack {
                // This ZStack ensures the gradient is always the base layer
                LinearGradient(
                    gradient: Gradient(colors: [gradientStartColor, gradientEndColor]),
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .edgesIgnoringSafeArea(.all)
                
                // The main content area
                switch activeScreen {
                case .main:
                    VStack(spacing: 0) {
                        customHeader
                            .padding(.top, (UIApplication.shared.connectedScenes.first as? UIWindowScene)?.windows.first?.safeAreaInsets.top ?? 0)
                        
                        ScrollView {
                            VStack(spacing: 25) {
                                CalorieProgressView(summary: $viewModel.summary)
                                    .onTapGesture { editingTarget = .calories }
                                
                                // Swipeable Macro/Micro/Water/Caffeine/Alcohol Card Area
                                TabView(selection: $selectedTab) {
                                    MacroCardView(summary: $viewModel.summary)
                                        .tag(0)
                                    
                                    MicroCardView(summary: $viewModel.summary)
                                        .tag(1)
                                    
                                    WaterCardView(
                                        summary: $viewModel.summary,
                                        onTap: {
                                            // TODO: Navigate to water details view
                                            print("Water details tapped")
                                        },
                                        onSettings: {
                                            showWaterSettings = true
                                        },
                                        onLogWater: { amount, containerType in
                                            logWater(amount: amount, containerType: containerType)
                                        },
                                        onRemoveWater: { amount in
                                            removeWater(amount: amount)
                                        },
                                        preferredUnit: preferredWaterUnit
                                    )
                                    .tag(2)
                                    
                                    CaffeineCardView(
                                        summary: $viewModel.summary,
                                        dailyTracker: getCurrentDailyTracker(),
                                        onTap: {
                                            activeScreen = .caffeineCategories
                                        },
                                        onCategorySelected: { category in
                                            activeScreen = .caffeineBrowser(category)
                                        }
                                    )
                                    .tag(3)
                                    
                                    AlcoholCardView(
                                        summary: $viewModel.summary,
                                        dailyTracker: getCurrentDailyTracker(),
                                        onTap: {
                                            activeScreen = .alcoholCategories
                                        },
                                        onCategorySelected: { category in
                                            activeScreen = .alcoholBrowser(category)
                                        }
                                    )
                                    .tag(4)
                                }
                                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                                .frame(height: 280)
                                .animation(.easeInOut, value: selectedTab)
                                
                                // Custom tab indicator dots
                                HStack {
                                    ForEach(0..<5) { index in
                                        Circle()
                                            .fill(selectedTab == index ? Color.white : Color.white.opacity(0.5))
                                            .frame(width: 8, height: 8)
                                            .animation(.easeInOut, value: selectedTab)
                                    }
                                }
                                .padding(.top, -10)
                                
                                LiveDiaryView(
                                    viewModel: viewModel,
                                    showAddFoodView: Binding(
                                        get: { activeScreen == .addFood },
                                        set: { show in
                                            activeScreen = show ? .addFood : .main
                                        }
                                    ),
                                    onEntryTap: handleDiaryEntryTap
                                )
                            }
                            .padding(.vertical, 20)
                        }
                    }
                    .edgesIgnoringSafeArea(.top)
                    
                case .history:
                    VStack(spacing: 0) {
                        historyHeader
                            .padding(.top, (UIApplication.shared.connectedScenes.first as? UIWindowScene)?.windows.first?.safeAreaInsets.top ?? 0)
                        
                        NutritionHistoryView()
                            .environmentObject(authManager)
                    }
                    .edgesIgnoringSafeArea(.top)
                    
                case .addFood:
                    FoodSearchView(
                        viewModel: viewModel,
                        isPresented: Binding(
                            get: { activeScreen == .addFood },
                            set: { show in
                                activeScreen = show ? .addFood : .main
                            }
                        ),
                        activeScreen: $activeScreen
                    )
                    .environmentObject(authManager)
                    
                case .myFoods:
                    ZStack {
                        LinearGradient(
                            gradient: Gradient(colors: [gradientStartColor, gradientEndColor]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        .edgesIgnoringSafeArea(.all)
                        MyFoodsView(onBack: {
                            activeScreen = .main
                        })
                        .environmentObject(authManager)
                    }
                    
                case .createFood:
                    ZStack {
                        LinearGradient(
                            gradient: Gradient(colors: [gradientStartColor, gradientEndColor]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        .edgesIgnoringSafeArea(.all)
                        CreateFoodView(onDismiss: {
                            showCreateFoodView = false
                        })
                        .environmentObject(authManager)
                    }
                    
                case .streaks:
                    ZStack {
                        LinearGradient(
                            gradient: Gradient(colors: [gradientStartColor, gradientEndColor]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        .edgesIgnoringSafeArea(.all)
                        StreakView(onBack: {
                            activeScreen = .main
                        })
                        .environmentObject(authManager)
                    }
                    
                case .alcoholCategories:
                    AlcoholCategoriesView(
                        onCategorySelected: { category in
                            activeScreen = .alcoholBrowser(category)
                        },
                        onBack: {
                            activeScreen = .main
                        }
                    )
                    .environmentObject(authManager)
                    
                case .alcoholBrowser(let category):
                    AlcoholBeverageBrowserView(
                        category: category,
                        onBack: {
                            activeScreen = .main
                        },
                        onBeverageLogged: {
                            // Refresh the nutrition data and return to main
                            Task {
                                await viewModel.reloadCurrentLog()
                            }
                            activeScreen = .main
                        },
                        onBeverageLoggedWithData: { calories, protein, carbs, fat, fiber, iron, calcium, vitaminA, vitaminC, vitaminB12, folate, potassium, alcoholGrams, standardDrinks in
                            // Update the summary immediately with alcohol data
                            viewModel.handleLogSuccess(
                                loggedCals: calories,
                                loggedProtein: protein,
                                loggedCarbs: carbs,
                                loggedFat: fat,
                                loggedFiber: fiber,
                                loggedIron: iron,
                                loggedCalcium: calcium,
                                loggedVitaminA: vitaminA,
                                loggedVitaminC: vitaminC,
                                loggedB12: vitaminB12,
                                loggedFolate: folate,
                                loggedPotassium: potassium,
                                loggedAlcoholGrams: alcoholGrams,
                                loggedStandardDrinks: standardDrinks
                            )
                        }
                    )
                    .environmentObject(authManager)
                    
                case .caffeineCategories:
                    CaffeineCategoriesView(
                        onCategorySelected: { category in
                            activeScreen = .caffeineBrowser(category)
                        },
                        onBack: {
                            activeScreen = .main
                        }
                    )
                    .environmentObject(authManager)
                    
                case .caffeineBrowser(let category):
                    CaffeineProductBrowserView(
                        category: category,
                        onBack: {
                            activeScreen = .main
                        },
                        onProductLogged: {
                            // Refresh the nutrition data and return to main
                            Task {
                                await viewModel.reloadCurrentLog()
                            }
                            activeScreen = .main
                        },
                        onProductLoggedWithData: { calories, protein, carbs, fat, fiber, iron, calcium, vitaminA, vitaminC, vitaminB12, folate, potassium, caffeineMg in
                            // Update the summary immediately with caffeine data
                            viewModel.handleCaffeineLogSuccess(
                                loggedCals: calories,
                                loggedProtein: protein,
                                loggedCarbs: carbs,
                                loggedFat: fat,
                                loggedFiber: fiber,
                                loggedIron: iron,
                                loggedCalcium: calcium,
                                loggedVitaminA: vitaminA,
                                loggedVitaminC: vitaminC,
                                loggedB12: vitaminB12,
                                loggedFolate: folate,
                                loggedPotassium: potassium,
                                loggedCaffeineMg: caffeineMg
                            )
                        }
                    )
                    .environmentObject(authManager)
                    
                case .caffeineProductDetail(let product):
                    CaffeineProductDetailView(
                        product: product,
                        onLog: { loggedProduct, quantity in
                            print("NutritionView: Caffeine callback called for \(loggedProduct.name)")
                            // Handle caffeine product logging
                            let calories = loggedProduct.caloriesPerServing * quantity
                            let caffeineMg = loggedProduct.caffeineMgPerServing * quantity
                            let sugarG = (loggedProduct.sugarGPerServing ?? 0) * quantity
                            
                            // Update the summary immediately with caffeine data
                            viewModel.handleCaffeineLogSuccess(
                                loggedCals: calories,
                                loggedProtein: 0, // Caffeine products typically don't have protein
                                loggedCarbs: 0,   // Carbs are tracked separately as sugar
                                loggedFat: 0,     // Caffeine products typically don't have fat
                                loggedFiber: 0,   // Caffeine products typically don't have fiber
                                loggedIron: 0,    // Caffeine products typically don't have iron
                                loggedCalcium: 0, // Caffeine products typically don't have calcium
                                loggedVitaminA: 0, // Caffeine products typically don't have vitamin A
                                loggedVitaminC: 0, // Caffeine products typically don't have vitamin C
                                loggedB12: 0,     // Caffeine products typically don't have B12
                                loggedFolate: 0,  // Caffeine products typically don't have folate
                                loggedPotassium: 0, // Caffeine products typically don't have potassium
                                loggedCaffeineMg: caffeineMg
                            )
                            
                            // Return to main - no need to reload since API call already saved the data
                            activeScreen = .main
                        },
                        onDismiss: {
                            activeScreen = .main
                        }
                    )
                    .environmentObject(authManager)
                    
                case .alcoholProductDetail(let product):
                    AlcoholBeverageDetailView(
                        beverage: product,
                        onLog: { loggedBeverage, quantity in
                            print("NutritionView: Alcohol callback called for \(loggedBeverage.name)")
                            // Handle alcohol beverage logging
                            let quantityDouble = Double(quantity)
                            let calories = loggedBeverage.calories * quantityDouble
                            let alcoholGrams = loggedBeverage.alcoholGrams * quantityDouble
                            let carbsGrams = loggedBeverage.carbsGrams * quantityDouble
                            let standardDrinks = Double(quantity) // 1 quantity = 1 standard drink
                            
                            // Update the summary immediately with alcohol data
                            viewModel.handleLogSuccess(
                                loggedCals: calories,
                                loggedProtein: 0, // Alcohol typically doesn't have protein
                                loggedCarbs: carbsGrams,
                                loggedFat: 0,     // Alcohol typically doesn't have fat
                                loggedFiber: 0,   // Alcohol typically doesn't have fiber
                                loggedIron: 0,    // Alcohol typically doesn't have iron
                                loggedCalcium: 0, // Alcohol typically doesn't have calcium
                                loggedVitaminA: 0, // Alcohol typically doesn't have vitamin A
                                loggedVitaminC: 0, // Alcohol typically doesn't have vitamin C
                                loggedB12: 0,     // Alcohol typically doesn't have B12
                                loggedFolate: 0,  // Alcohol typically doesn't have folate
                                loggedPotassium: 0, // Alcohol typically doesn't have potassium
                                loggedAlcoholGrams: alcoholGrams,
                                loggedStandardDrinks: standardDrinks
                            )
                            
                            // Return to main - no need to reload since API call already saved the data
                            activeScreen = .main
                        },
                        onDismiss: {
                            activeScreen = .main
                        }
                    )
                    .environmentObject(authManager)
                }
            }
            .sheet(item: $editingTarget) { target in
                GoalEditorView(viewModel: viewModel, target: target)
            }
            .sheet(item: $viewModel.selectedFoodForConfirmation) { foodToConfirm in
                FoodDetailConfirmationView(
                    food: foodToConfirm,
                    date: Date()
                ) { loggedCals, loggedProtein, loggedCarbs, loggedFat, loggedFiber, loggedIron, loggedCalcium, loggedVitaminA, loggedVitaminC, loggedB12, loggedFolate, loggedPotassium in
                    viewModel.handleLogSuccess(
                        loggedCals: loggedCals,
                        loggedProtein: loggedProtein,
                        loggedCarbs: loggedCarbs,
                        loggedFat: loggedFat,
                        loggedFiber: loggedFiber,
                        loggedIron: loggedIron,
                        loggedCalcium: loggedCalcium,
                        loggedVitaminA: loggedVitaminA,
                        loggedVitaminC: loggedVitaminC,
                        loggedB12: loggedB12,
                        loggedFolate: loggedFolate,
                        loggedPotassium: loggedPotassium
                    )
                    // Reload the daily log to ensure UI updates with fresh data
                    Task {
                        await viewModel.reloadCurrentLog()
                    }
                } onNavigateToMain: {
                    // Navigate back to main view after tracking
                    activeScreen = .main
                }
                .environmentObject(authManager)
            }
            .fullScreenCover(isPresented: $barcodeScannerViewModel.showScannerSheet) {
                BarcodeScannerView(
                    viewModel: barcodeScannerViewModel,
                    onProductFound: { product in
                        // Route to the unified FoodDetailConfirmationView for barcode scans
                        viewModel.selectedFoodForConfirmation = product
                    },
                    onAlcoholFound: { alcoholBeverage in
                        // Direct alcohol product match - navigate to detail view
                        print("Scanned alcohol product: \(alcoholBeverage.name)")
                        activeScreen = .alcoholProductDetail(alcoholBeverage)
                    },
                    onCaffeineFound: { caffeineProduct in
                        // Direct caffeine product match - navigate to detail view
                        print("Scanned caffeine product: \(caffeineProduct.name)")
                        activeScreen = .caffeineProductDetail(caffeineProduct)
                    },
                    onMappedAlcoholFound: { foodProduct, alcoholBeverage in
                        // Fuzzy matched alcohol product - navigate to alcohol detail view
                        print("Mapped food product '\(foodProduct.productName ?? "")' to alcohol product '\(alcoholBeverage.name)'")
                        activeScreen = .alcoholProductDetail(alcoholBeverage)
                    },
                    onMappedCaffeineFound: { foodProduct, caffeineProduct in
                        // Fuzzy matched caffeine product - navigate to caffeine detail view
                        print("Mapped food product '\(foodProduct.productName ?? "")' to caffeine product '\(caffeineProduct.name)'")
                        activeScreen = .caffeineProductDetail(caffeineProduct)
                    },
                    onProductNotFound: {
                        // Show the unified no results view instead of immediately opening create food
                        showBarcodeNoResultsView = true
                    }
                )
            }
            .sheet(isPresented: $showCreateFoodView) {
                CreateFoodView(onDismiss: {
                    showCreateFoodView = false
                })
                .environmentObject(authManager)
            }
            .sheet(isPresented: $showBarcodeNoResultsView) {
                NavigationView {
                    ZStack {
                        LinearGradient(
                            gradient: Gradient(colors: [Color("Nutrition").opacity(0.6), Color("Nutrition")]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        .edgesIgnoringSafeArea(.all)
                        
                        NoResultsFoundView(
                            message: "Barcode not found in our database. Would you like to add this food manually?",
                            onCreateFood: {
                                showBarcodeNoResultsView = false
                                showCreateFoodView = true
                            }
                        )
                    }
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarLeading) {
                            Button("Cancel") {
                                showBarcodeNoResultsView = false
                            }
                            .foregroundColor(.white)
                        }
                    }
                }
                .preferredColorScheme(.dark)
            }
            .sheet(isPresented: $showWaterSettings) {
                WaterSettingsModal(
                    waterGoal: $viewModel.summary.waterGoalMl,
                    onSave: { newGoal, unit in
                        updateWaterSettings(waterGoal: newGoal, unit: unit)
                    }
                )
            }
            .onAppear {
                // Initialize product mapping service
                Task {
                    await initializeProductMappingService()
                }
            }
        }
        
        // MARK: - Water Tracking Functions
        
        private func logWater(amount: Double, containerType: String) {
            Task {
                do {
                    let _ = try await foodSearchAPI.logWater(amountMl: amount, containerType: containerType)
                    
                    // Update the summary immediately for better UX
                    await MainActor.run {
                        viewModel.summary.waterMl += amount
                    }
                    
                    // Refresh the full data
                    await viewModel.reloadCurrentLog()
                    
                } catch {
                    print("Error logging water: \(error)")
                    // TODO: Show error message to user
                }
            }
        }
        
        private func removeWater(amount: Double) {
            Task {
                // For now, we'll just update locally since there might not be a specific API to remove water
                // In a real app, you might want to log a negative water entry or have a specific remove endpoint
                await MainActor.run {
                    viewModel.summary.waterMl = max(0, viewModel.summary.waterMl - amount)
                }
                
                // Optionally refresh the full data if you have a remove water API
                // await viewModel.reloadCurrentLog()
            }
        }
        
        private func updateWaterSettings(waterGoal: Double, unit: WaterUnit) {
            Task {
                do {
                    let _ = try await foodSearchAPI.updateWaterSettings(waterGoalMl: waterGoal, preferredUnit: unit.rawValue)
                    
                    // Update the summary and preferred unit immediately
                    await MainActor.run {
                        viewModel.summary.waterGoalMl = waterGoal
                        preferredWaterUnit = unit
                    }
                    
                    // Refresh the full data
                    await viewModel.reloadCurrentLog()
                    
                } catch {
                    print("Error updating water settings: \(error)")
                    // TODO: Show error message to user
                }
            }
        }
        
        // MARK: - Diary Entry Navigation
        
        private func handleDiaryEntryTap(entry: FoodEntry) {
            // Check if this is an alcohol entry
            if entry.isAlcoholicBeverage, let alcoholCategory = entry.alcoholCategory {
                // Try to find the alcohol product and show alcohol confirmation view
                Task {
                    do {
                        let alcoholAPI = AlcoholAPI(httpClient: foodSearchAPI.authenticatedHTTPClient)
                        
                        // Try to find the alcohol product by searching for it
                        let searchResponse = try await alcoholAPI.searchAlcoholicBeverages(query: entry.foodName, limit: 1)
                        
                        if let alcoholBeverage = searchResponse.beverages.first {
                            activeScreen = .alcoholProductDetail(alcoholBeverage)
                        } else {
                            // Fallback: create a mock alcohol beverage from the entry data
                            let mockAlcoholBeverage = AlcoholicBeverage(
                                id: "diary_\(entry.id)",
                                name: entry.foodName,
                                brand: nil,
                                category: alcoholCategory,
                                alcoholContentPercent: 5.0, // Default assumption
                                alcoholGrams: entry.alcoholGrams ?? 14.0,
                                calories: Double(entry.calories ?? 0),
                                carbsGrams: entry.carbs ?? 0.0,
                                servingSizeML: 355.0, // Default beer bottle
                                servingDescription: entry.servingUnit,
                                description: nil,
                                popularityScore: 0,
                                createdAt: "",
                                updatedAt: ""
                            )
                            activeScreen = .alcoholProductDetail(mockAlcoholBeverage)
                        }
                    } catch {
                        print("Error loading alcohol product for diary entry: \(error)")
                        // Fallback to regular food confirmation
                        Task {
                            await viewModel.showFoodConfirmation(for: entry, foodProductId: entry.foodProductId ?? "")
                        }
                    }
                }
            }
            // Check if this is a caffeine entry
            else if entry.isCaffeineProduct, let caffeineCategory = entry.caffeineCategory {
                Task {
                    do {
                        let caffeineAPI = CaffeineAPI(httpClient: foodSearchAPI.authenticatedHTTPClient)
                        
                        // Try to find the caffeine product by searching for it
                        let searchResponse = try await caffeineAPI.searchCaffeineProducts(query: entry.foodName)
                        
                        if let caffeineProduct = searchResponse.products.first {
                            activeScreen = .caffeineProductDetail(caffeineProduct)
                        } else {
                            // Fallback: create a mock caffeine product from the entry data
                            let mockCaffeineProduct = CaffeineProduct(
                                id: "diary_\(entry.id)",
                                name: entry.foodName,
                                brand: nil,
                                category: caffeineCategory,
                                subCategory: nil,
                                flavorOrVariant: nil,
                                servingSizeML: 355.0, // Default serving size
                                servingSizeDesc: entry.servingUnit,
                                caffeineMgPerServing: entry.caffeineMg ?? 95.0,
                                caffeineMgPer100ML: nil,
                                caloriesPerServing: Double(entry.calories ?? 0),
                                sugarGPerServing: nil,
                                upc: nil,
                                source: nil,
                                createdAt: "",
                                updatedAt: ""
                            )
                            activeScreen = .caffeineProductDetail(mockCaffeineProduct)
                        }
                    } catch {
                        print("Error loading caffeine product for diary entry: \(error)")
                        // Fallback to regular food confirmation
                        Task {
                            await viewModel.showFoodConfirmation(for: entry, foodProductId: entry.foodProductId ?? "")
                        }
                    }
                }
            }
            // Regular food entry - use existing logic
            else {
                Task {
                    await viewModel.showFoodConfirmation(for: entry, foodProductId: entry.foodProductId ?? "")
                }
            }
        }
        
        // MARK: - Product Mapping Service Initialization
        
        private func initializeProductMappingService() async {
            print("NutritionView: Initializing product mapping service")
            
            async let alcoholTask: Void = loadAlcoholProductsForMapping()
            async let caffeineTask: Void = loadCaffeineProductsForMapping()
            
            _ = await [alcoholTask, caffeineTask]
            
            print("NutritionView: Product mapping service initialized")
        }
        
        private func loadAlcoholProductsForMapping() async {
            do {
                let alcoholAPI = AlcoholAPI(httpClient: foodSearchAPI.authenticatedHTTPClient)
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
                        print("NutritionView: Failed to load category \(category): \(error)")
                    }
                }
                
                ProductMappingService.shared.updateAlcoholProducts(allBeverages)
                print("NutritionView: Loaded \(allBeverages.count) alcohol products for mapping")
            } catch {
                print("NutritionView: Failed to load alcohol products for mapping: \(error)")
            }
        }
        
        private func loadCaffeineProductsForMapping() async {
            do {
                let caffeineAPI = CaffeineAPI(httpClient: foodSearchAPI.authenticatedHTTPClient)
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
                        print("NutritionView: Failed to load category \(category): \(error)")
                    }
                }
                
                ProductMappingService.shared.updateCaffeineProducts(allProducts)
                print("NutritionView: Loaded \(allProducts.count) caffeine products for mapping")
            } catch {
                print("NutritionView: Failed to load caffeine products for mapping: \(error)")
            }
        }
    }
    
    // MARK: - Subviews
    
    struct CalorieProgressView: View {
        @Binding var summary: DailyNutritionSummary // This binding is now from viewModel.summary
        // let accentColor: Color // Removed, will use black/gray for progress bar
        
        var totalCalories: Double {
            Double(summary.caloriesEaten + summary.caloriesLeft)
        }
        var progress: Double {
            guard totalCalories > 0 else { return 0 }
            return Double(summary.caloriesEaten) / totalCalories
        }
        
        var body: some View {
            VStack(spacing: 8) {
                HStack {
                    Text("Calories")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.white) // MODIFIED: Text color to white
                    Spacer()
                }
                
                // Custom Progress Bar
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.gray.opacity(0.3)) // Light gray track
                            .frame(height: 12)
                        Capsule()
                            .fill(Color.black) // Black progress fill
                            .frame(width: geometry.size.width * CGFloat(progress), height: 12)
                            .animation(.easeInOut, value: progress)
                    }
                }
                .frame(height: 12)
                
                HStack {
                    VStack(alignment: .leading) {
                        Text("\(summary.caloriesEaten)")
                            .font(.title3).fontWeight(.medium)
                            .foregroundColor(.white) // MODIFIED: Text color to white
                        Text("Eaten")
                            .font(.caption).opacity(0.7)
                            .foregroundColor(.white) // MODIFIED: Text color to white
                    }
                    Spacer()
                    VStack(alignment: .trailing) {
                        Text("\(summary.caloriesLeft)")
                            .font(.title3).fontWeight(.medium)
                            .foregroundColor(.white) // MODIFIED: Text color to white
                        Text("Left")
                            .font(.caption).opacity(0.7)
                            .foregroundColor(.white) // MODIFIED: Text color to white
                    }
                }
            }
            .padding(.horizontal) // Keep horizontal padding to prevent touching edges
            .onAppear {
                print("CalorieProgressView: onAppear - Cals: \(summary.caloriesEaten), Progress: \(progress)")
            }
            .onChange(of: summary.caloriesEaten) { _, newValue in
                print("CalorieProgressView: caloriesEaten changed to \(newValue)")
            }
        }
    }
    
    struct MacroCardView: View {
        @Binding var summary: DailyNutritionSummary
        let carbColor = Color(red: 0.1, green: 0.4, blue: 0.1) // Dark Green for Carbs
        let proteinColor = Color(red: 0.2, green: 0.5, blue: 0.2) // Medium Dark Green for Protein
        let fatColor = Color(red: 0.15, green: 0.35, blue: 0.15) // Darker Green for Fat
        
        var body: some View {
            CardContainer {
                VStack(alignment: .leading, spacing: 15) {
                    Text("Macro Nutrients")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.black)
                        .padding(.bottom, 5)
                    
                    HStack(spacing: 15) {
                        MacroDetailView(
                            name: "Carbs",
                            eaten: summary.carbsEaten,
                            goal: summary.carbsGoal,
                            color: carbColor,
                            unit: "g"
                        )
                        .frame(maxWidth: .infinity)
                        
                        MacroDetailView(
                            name: "Protein",
                            eaten: summary.proteinEaten,
                            goal: summary.proteinGoal,
                            color: proteinColor,
                            unit: "g"
                        )
                        .frame(maxWidth: .infinity)
                        
                        MacroDetailView(
                            name: "Fat",
                            eaten: summary.fatEaten,
                            goal: summary.fatGoal,
                            color: fatColor,
                            unit: "g"
                        )
                        .frame(maxWidth: .infinity)
                    }
                }
            }
            .frame(height: 200)
            .onAppear {
                print("MacroCardView: onAppear - Protein: \(summary.proteinEaten), Carbs: \(summary.carbsEaten), Fat: \(summary.fatEaten)")
            }
            .onChange(of: summary.proteinEaten) { _, newValue in
                print("MacroCardView: proteinEaten changed to \(newValue)")
            }
            .onChange(of: summary.carbsEaten) { _, newValue in
                print("MacroCardView: carbsEaten changed to \(newValue)")
            }
            .onChange(of: summary.fatEaten) { _, newValue in
                print("MacroCardView: fatEaten changed to \(newValue)")
            }
        }
    }
    
    struct MacroDetailView: View {
        let name: String
        let eaten: Double
        let goal: Double
        let color: Color
        let unit: String
        
        var progress: Double {
            guard goal > 0 else { return 0 }
            return min(eaten / goal, 1.0)
        }
        
        var body: some View {
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .stroke(Color.gray.opacity(0.2), lineWidth: 6)
                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(color, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .animation(.easeInOut, value: progress)
                    Text(String(format: "%.0f%@", eaten, unit))
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.black)
                }
                .frame(width: 60, height: 60)
                Text(name)
                    .font(.headline)
                    .fontWeight(.medium)
                    .foregroundColor(.black)
                Text(String(format: "of %.0f%@", goal, unit))
                    .font(.caption2)
                    .opacity(0.7)
                    .foregroundColor(.black)
            }
        }
    }
    
    struct NutrientProgressView: View {
        let name: String
        let value: Double
        let goal: Double
        let unit: String
        let barColor: Color
        
        var progress: Double {
            guard goal > 0 else { return 0 }
            return min(value / goal, 1.0)
        }
        
        var body: some View {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(name)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.black)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    
                    Spacer()
                    
                    Text("\(String(format: "%.1f", value))/\(String(format: "%.0f", goal))\(unit)")
                        .font(.caption)
                        .foregroundColor(.black.opacity(0.7))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        // Background
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.gray.opacity(0.2))
                            .frame(height: 8)
                        
                        // Progress
                        RoundedRectangle(cornerRadius: 4)
                            .fill(barColor)
                            .frame(width: geometry.size.width * progress, height: 8)
                    }
                }
                .frame(height: 8)
            }
            .frame(height: 40)
        }
    }
    
    struct MicroCardView: View {
        @Binding var summary: DailyNutritionSummary
        
        let microColors: [Color] = [
            Color(red: 0.1, green: 0.4, blue: 0.1), // Dark Green
            Color(red: 0.2, green: 0.5, blue: 0.2), // Medium Dark Green
            Color(red: 0.15, green: 0.35, blue: 0.15), // Darker Green
            Color(red: 0.25, green: 0.6, blue: 0.25), // Medium Green
            Color(red: 0.3, green: 0.7, blue: 0.3), // Lighter Green
            Color(red: 0.05, green: 0.3, blue: 0.05), // Very Dark Green
            Color(red: 0.18, green: 0.45, blue: 0.18), // Medium Dark Green
            Color(red: 0.12, green: 0.38, blue: 0.12)  // Dark Green
        ]
        
        var body: some View {
            CardContainer {
                VStack(alignment: .leading, spacing: 15) {
                    Text("Micro Nutrients")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.black)
                        .padding(.bottom, 5)
                    
                    ZStack(alignment: .leading) {
                        ScrollView(.vertical, showsIndicators: false) {
                            VStack(spacing: 16) {
                                HStack(alignment: .top, spacing: 20) {
                                    VStack(alignment: .leading, spacing: 16) {
                                        NutrientProgressView(name: "Fiber", value: summary.fiberGrams, goal: 30, unit: "g", barColor: microColors[0])
                                        NutrientProgressView(name: "Iron", value: summary.ironMilligrams, goal: 10, unit: "mg", barColor: microColors[1])
                                        NutrientProgressView(name: "Calcium", value: summary.calciumMilligrams, goal: 1000, unit: "mg", barColor: microColors[2])
                                        NutrientProgressView(name: "Vitamin A", value: summary.vitaminAMicrograms, goal: 800, unit: "mcg", barColor: microColors[3])
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    
                                    VStack(alignment: .leading, spacing: 16) {
                                        NutrientProgressView(name: "Vitamin C", value: summary.vitaminCMilligrams, goal: 85, unit: "mg", barColor: microColors[4])
                                        NutrientProgressView(name: "B12", value: summary.vitaminB12Micrograms, goal: 2.4, unit: "mcg", barColor: microColors[5])
                                        NutrientProgressView(name: "Folate", value: summary.folateMicrograms, goal: 400, unit: "mcg", barColor: microColors[6])
                                        NutrientProgressView(name: "Potassium", value: summary.potassiumMilligrams, goal: 3000, unit: "mg", barColor: microColors[7])
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                }
                            }
                            .padding(.horizontal, 4)
                        }
                        
                        // Custom scroll indicator on the left
                        VStack {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color.gray.opacity(0.5))
                                .frame(width: 4, height: 60)
                            Spacer()
                        }
                        .padding(.leading, 2)
                        .padding(.top, 10)
                    }
                }
            }
            .frame(height: 200)
            .onAppear {
                print("MicroCardView: onAppear - Fiber: \(summary.fiberGrams), Iron: \(summary.ironMilligrams), Calcium: \(summary.calciumMilligrams)")
            }
            .onChange(of: summary.fiberGrams) { _, newValue in
                print("MicroCardView: fiberGrams changed to \(newValue)")
            }
            .onChange(of: summary.ironMilligrams) { _, newValue in
                print("MicroCardView: ironMilligrams changed to \(newValue)")
            }
            .onChange(of: summary.calciumMilligrams) { _, newValue in
                print("MicroCardView: calciumMilligrams changed to \(newValue)")
            }
        }
    }
    
    struct LiveDiaryView: View {
        @ObservedObject var viewModel: NutritionViewModel
        @Binding var showAddFoodView: Bool
        let onEntryTap: (FoodEntry) -> Void
        
        var body: some View {
            VStack(spacing: 0) {
                // Header with + button
                HStack {
                    Text("Today's Diary")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    Button(action: {
                        showAddFoodView = true
                    }) {
                        Image(systemName: "plus")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 32, height: 32)
                            .background(Color.black)
                            .clipShape(Circle())
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 15)
                
                // Content area
                if viewModel.todaysFoodEntries.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "fork.knife.circle")
                            .font(.system(size: 48))
                            .foregroundColor(.white.opacity(0.6))
                        
                        Text("No foods logged today")
                            .font(.headline)
                            .foregroundColor(.white.opacity(0.8))
                        
                        Text("Tap the + button to add your first meal")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.6))
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
                    .background(
                        RoundedRectangle(cornerRadius: 15, style: .continuous)
                            .fill(Color.white.opacity(0.1))
                    )
                    .padding(.horizontal)
                } else {
                    VStack(spacing: 0) {
                        // Instruction text
                        HStack {
                            Image(systemName: "info.circle")
                                .foregroundColor(.white.opacity(0.8))
                            Text("Swipe left on any entry to delete")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.8))
                            Spacer()
                        }
                        .padding(.horizontal)
                        .padding(.bottom, 10)
                        
                        // Food entries in scrollable view
                        ScrollView {
                            VStack(spacing: 8) {
                                let sortedEntries = viewModel.todaysFoodEntries.sorted { entry1, entry2 in
                                    // Sort by most recent first (newest entries at top)
                                    // Use timeConsumed for more accurate sorting of when food was actually logged
                                    let formatter = ISO8601DateFormatter()
                                    let date1 = formatter.date(from: entry1.timeConsumed) ?? Date.distantPast
                                    let date2 = formatter.date(from: entry2.timeConsumed) ?? Date.distantPast
                                    return date1 > date2
                                }
                                
                                ForEach(sortedEntries, id: \.id) { entry in
                                    FoodDiaryEntryRow(
                                        entry: entry,
                                        onTap: {
                                            onEntryTap(entry)
                                        },
                                        onDelete: {
                                            Task {
                                                await viewModel.deleteFoodEntry(entry)
                                            }
                                        }
                                    )
                                }
                            }
                        }
                        .refreshable {
                            // Pull to refresh functionality
                            await viewModel.refreshDiary()
                        }
                        .onAppear {
                            // Force reload when view appears
                            Task {
                                await viewModel.reloadCurrentLog()
                                await viewModel.loadTodaysFoodEntriesPublic()
                            }
                        }
                        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
                            // Reload when app comes back from background
                            Task {
                                await viewModel.reloadCurrentLog()
                                await viewModel.loadTodaysFoodEntriesPublic()
                            }
                        }
                        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
                            // Reload when app becomes active (e.g., returning from another app)
                            Task {
                                await viewModel.refreshDiary()
                            }
                        }
                    }
                }
                
                Spacer()
            }
        }
    }
    
    struct FoodDiaryEntryRow: View {
        let entry: FoodEntry
        let onTap: () -> Void
        let onDelete: () -> Void
        
        @State private var offset: CGFloat = 0
        @State private var showingDeleteButton = false
        
        private func getEntryIcon() -> String {
            // For alcohol entries, show the category icon instead of meal icon
            if entry.isAlcoholicBeverage, let alcoholIcon = entry.alcoholIcon {
                return alcoholIcon
            }
            
            // For caffeine entries, show the category icon
            if entry.isCaffeineProduct, let caffeineIcon = entry.caffeineIcon {
                return caffeineIcon
            }
            
            // For food product entries (tracked foods), show chicken drumstick
            if entry.foodProductId != nil {
                return "🍗"
            }
            
            // For non-alcohol/caffeine/food-product entries, show meal type icon
            switch entry.mealType.lowercased() {
            case "breakfast": return "sun.max.fill"
            case "lunch": return "cloud.sun.fill"
            case "dinner": return "moon.stars.fill"
            case "snack": return "fork.knife"
            default: return "circle.fill"
            }
        }
        
        var body: some View {
            ZStack {
                // Delete button background
                HStack {
                    Spacer()
                    Button(action: {
                        onDelete()
                    }) {
                        VStack(spacing: 4) {
                            Image(systemName: "trash.fill")
                                .font(.title2)
                                .foregroundColor(.white)
                            Text("Delete")
                                .font(.caption)
                                .foregroundColor(.white)
                        }
                        .frame(width: 80)
                        .frame(maxHeight: .infinity)
                        .background(Color.black)
                    }
                    .opacity(showingDeleteButton ? 1 : 0)
                }
                
                // Main content
                HStack(spacing: 12) {
                    // Entry icon on the left - handle different icon types
                    if entry.isAlcoholicBeverage || entry.isCaffeineProduct || entry.foodProductId != nil {
                        // Show emoji icons for alcohol, caffeine, and food products
                        Text(getEntryIcon())
                            .font(.system(size: 16))
                            .frame(width: 24, height: 24)
                    } else {
                        // Show meal type system icon
                        Image(systemName: getEntryIcon())
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.black.opacity(0.7))
                            .frame(width: 24, height: 24)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(entry.foodName)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.black)
                            .lineLimit(1)
                        
                        Text(entry.isAlcoholicBeverage ? entry.diaryDisplayText : "\(String(format: "%.0f", entry.servingSize)) \(entry.servingUnit) • \(entry.calories ?? 0) kcal")
                            .font(.system(size: 12))
                            .foregroundColor(.black.opacity(0.6))
                        
                        HStack(spacing: 8) {
                            Text("P: \(String(format: "%.1f", entry.protein ?? 0))g")
                            Text("C: \(String(format: "%.1f", entry.carbs ?? 0))g")
                            Text("F: \(String(format: "%.1f", entry.fat ?? 0))g")
                        }
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.black.opacity(0.7))
                    }
                    
                    Spacer()
                    
                    // Time indicator
                    VStack(alignment: .trailing, spacing: 2) {
                        let time = entry.timeConsumed.prefix(16).suffix(5) // Extract HH:MM from ISO string
                        Text(String(time))
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.black.opacity(0.5))
                        
                        // Don't show meal type for alcohol entries
                        if !entry.isAlcoholicBeverage {
                            Text(entry.mealType.capitalized)
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(.black.opacity(0.5))
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color.white.opacity(0.9))
                .cornerRadius(12)
                .offset(x: offset)
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            if value.translation.width < 0 {
                                offset = max(value.translation.width, -80)
                                showingDeleteButton = offset < -40
                            }
                        }
                        .onEnded { value in
                            withAnimation(.spring()) {
                                if value.translation.width < -40 {
                                    offset = -80
                                    showingDeleteButton = true
                                } else {
                                    offset = 0
                                    showingDeleteButton = false
                                }
                            }
                        }
                )
                .onTapGesture {
                    if offset == 0 {
                        onTap()
                    } else {
                        withAnimation(.spring()) {
                            offset = 0
                            showingDeleteButton = false
                        }
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 1) // Small gap between entries
        }
    }
    
    // Define DateNavigator again
    struct DateNavigator: View {
        @Binding var currentDate: Date // This binding is now from viewModel.currentDate
        
        var body: some View {
            HStack {
                Button {
                    currentDate = Calendar.current.date(byAdding: .day, value: -1, to: currentDate) ?? currentDate
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.title2)
                        .frame(width: 44, height: 44) // Ensure tappable area
                }
                
                Spacer()
                
                HStack(spacing: 5) {
                    Image(systemName: "calendar")
                        .font(.subheadline)
                    Text(currentDate, style: .date)
                        .textCase(.uppercase)
                        .font(.system(size: 14, weight: .semibold))
                }
                
                Spacer()
                
                Button {
                    currentDate = Calendar.current.date(byAdding: .day, value: 1, to: currentDate) ?? currentDate
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.title2)
                        .frame(width: 44, height: 44) // Ensure tappable area
                }
            }
            .foregroundColor(.white.opacity(0.9))
        }
    }
    
    // MARK: - Goal Editor
    enum GoalTarget: String, Identifiable {
        case calories, protein, carbs, fat
        var id: String { self.rawValue }
        
        var title: String {
            switch self {
            case .calories: "Calorie Goal"
            case .protein: "Protein Goal (g)"
            case .carbs: "Carbs Goal (g)"
            case .fat: "Fat Goal (g)"
            }
        }
        
        var keyboardType: UIKeyboardType {
            return .decimalPad
        }
    }
    
    struct GoalEditorView: View {
        @ObservedObject var viewModel: NutritionViewModel
        let target: GoalTarget
        
        @State private var value: String = ""
        @Environment(\.presentationMode) var presentationMode
        
        private var currentValue: String {
            switch target {
            case .calories:
                return String(format: "%.0f", Double(viewModel.summary.caloriesGoal))
            case .carbs:
                return String(format: "%.0f", viewModel.summary.carbsGoal)
            case .protein:
                return String(format: "%.0f", viewModel.summary.proteinGoal)
            case .fat:
                return String(format: "%.0f", viewModel.summary.fatGoal)
            }
        }
        
        var body: some View {
            NavigationView {
                Form {
                    Section(header: Text("Current: \(currentValue)")) {
                        TextField("New Goal", text: $value)
                            .keyboardType(target.keyboardType)
                    }
                }
                .navigationTitle(target.title)
                .navigationBarItems(
                    leading: Button("Cancel") { presentationMode.wrappedValue.dismiss() },
                    trailing: Button("Save") {
                        if let doubleValue = Double(value) {
                            viewModel.updateGoal(for: target, value: doubleValue)
                            presentationMode.wrappedValue.dismiss()
                        }
                    }.disabled(value.isEmpty || Double(value) == nil)
                )
            }
        }
    }
    
    // --- Food Search View ---
    struct FoodSearchView: View {
        @EnvironmentObject var authManager: AuthenticationManager
        @ObservedObject var viewModel: NutritionViewModel
        @Binding var isPresented: Bool
        @Binding var activeScreen: NutritionScreen
        
        @State private var searchText: String = ""
        @State private var searchResults: [FoodProduct] = []
        @State private var isLoadingFoodSearch: Bool = false
        @State private var foodSearchErrorMessage: String?
        @State private var showCreateFoodView: Bool = false
        @State private var showBarcodeNoResultsView: Bool = false
        
        @StateObject private var barcodeScannerViewModel: BarcodeScannerViewModel
        @State private var searchSubject = PassthroughSubject<String, Never>()
        @State private var currentSearchTask: Task<Void, Never>? // Track current search task for cancellation
        
        // Colors to match NutritionView
        private var gradientStartColor: Color { Color("Nutrition").opacity(0.6) }
        private var gradientEndColor: Color { Color("Nutrition") }
        private var accentColor: Color { Color.blue }
        
        // Create FoodSearchAPI instance
        private var foodSearchAPI: FoodSearchAPI {
            FoodSearchAPI(httpClient: authManager.httpClient)
        }
        
        init(viewModel: NutritionViewModel, isPresented: Binding<Bool>, activeScreen: Binding<NutritionScreen>) {
            self.viewModel = viewModel
            self._isPresented = isPresented
            self._activeScreen = activeScreen
            self._barcodeScannerViewModel = StateObject(wrappedValue: BarcodeScannerViewModel(authenticationManager: viewModel.authManager))
        }
        
        var body: some View {
            NavigationView {
                ZStack {
                    // Background gradient
                    LinearGradient(
                        gradient: Gradient(colors: [gradientStartColor, gradientEndColor]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .edgesIgnoringSafeArea(.all)
                    
                    VStack(spacing: 0) {
                        // Search Bar
                        HStack {
                            Image(systemName: "magnifyingglass")
                                .foregroundColor(.white)
                            TextField("Search for food...", text: $searchText)
                                .foregroundColor(.white)
                                .accentColor(.white)
                                .padding(.leading, 8)
                            
                            if !searchText.isEmpty {
                                Button(action: {
                                    // Cancel any pending search
                                    currentSearchTask?.cancel()
                                    currentSearchTask = nil
                                    
                                    // Clear everything
                                    searchText = ""
                                    searchResults = []
                                    foodSearchErrorMessage = nil
                                    isLoadingFoodSearch = false
                                }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.white.opacity(0.7))
                                }
                            }
                            
                            Button(action: {
                                barcodeScannerViewModel.showScannerSheet = true
                            }) {
                                Image(systemName: "barcode.viewfinder")
                                    .font(.title2)
                                    .foregroundColor(.white)
                            }
                            .padding(.leading, 8)
                        }
                        .padding(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))
                        .background(Color.white.opacity(0.15))
                        .cornerRadius(15)
                        .padding([.horizontal, .top])
                        
                        if isLoadingFoodSearch {
                            Spacer()
                            VStack(spacing: 12) {
                                // Custom spinning loader with dedicated animation state
                                SpinningLoaderView()
                                
                                Text("Searching our database")
                                    .foregroundColor(.white)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                            }
                            Spacer()
                        } else if let errorMessage = foodSearchErrorMessage {
                            Spacer()
                            Text("Error: \(errorMessage)")
                                .foregroundColor(.red)
                                .padding()
                            Spacer()
                        } else if searchResults.isEmpty && !searchText.isEmpty {
                            Spacer()
                            NoResultsFoundView(message: "Sorry we cannot find that item", onCreateFood: {
                                activeScreen = .createFood
                            })
                            Spacer()
                        } else if searchText.isEmpty {
                            VStack(alignment: .leading, spacing: 16) {
                                Text("Recent Foods")
                                    .font(.title2)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.white)
                                    .padding(.horizontal)
                                
                                if viewModel.recentSearches.isEmpty {
                                    Text("No recent foods yet")
                                        .foregroundColor(.white.opacity(0.7))
                                        .padding()
                                } else {
                                    List {
                                        ForEach(viewModel.recentSearches) { food in
                                            Button(action: {
                                                // Check if this food has mapping to specialized products
                                                if let mapping = food.mapping {
                                                    switch mapping.type {
                                                    case "alcohol":
                                                        if let alcoholBeverage = mapping.specializedProduct.toAlcoholicBeverage() {
                                                            activeScreen = .alcoholProductDetail(alcoholBeverage)
                                                        } else {
                                                            // Fallback to regular food view if conversion fails
                                                            viewModel.selectedFoodForConfirmation = food
                                                        }
                                                    case "caffeine":
                                                        if let caffeineProduct = mapping.specializedProduct.toCaffeineProduct() {
                                                            activeScreen = .caffeineProductDetail(caffeineProduct)
                                                        } else {
                                                            // Fallback to regular food view if conversion fails
                                                            viewModel.selectedFoodForConfirmation = food
                                                        }
                                                    default:
                                                        // Regular food product
                                                        viewModel.selectedFoodForConfirmation = food
                                                    }
                                                } else {
                                                    // No mapping, treat as regular food
                                                    viewModel.selectedFoodForConfirmation = food
                                                }
                                                
                                                viewModel.addToRecentSearches(food) // Move to top of recents
                                            }) {
                                                FoodSearchResultRow(food: food)
                                            }
                                            .buttonStyle(PlainButtonStyle())
                                            .listRowBackground(Color.clear)
                                            .listRowSeparator(.hidden)
                                        }
                                    }
                                    .listStyle(PlainListStyle())
                                    .scrollContentBackground(.hidden)
                                }
                            }
                            Spacer()
                        } else {
                            // Show results immediately with incremental loading
                            VStack(spacing: 0) {
                                List {
                                    ForEach(searchResults) { food in
                                        Button(action: {
                                            // Cancel any pending searches immediately when user selects
                                            currentSearchTask?.cancel()
                                            currentSearchTask = nil
                                            
                                            // Check if this food has direct mapping to specialized products
                                            if let mapping = food.mapping {
                                                switch mapping.type {
                                                case "alcohol":
                                                    if let alcoholBeverage = mapping.specializedProduct.toAlcoholicBeverage() {
                                                        activeScreen = .alcoholProductDetail(alcoholBeverage)
                                                    } else {
                                                        // Fallback to regular food view if conversion fails
                                                        viewModel.selectedFoodForConfirmation = food
                                                    }
                                                case "caffeine":
                                                    if let caffeineProduct = mapping.specializedProduct.toCaffeineProduct() {
                                                        activeScreen = .caffeineProductDetail(caffeineProduct)
                                                    } else {
                                                        // Fallback to regular food view if conversion fails
                                                        viewModel.selectedFoodForConfirmation = food
                                                    }
                                                default:
                                                    // Regular food product
                                                    viewModel.selectedFoodForConfirmation = food
                                                }
                                            } else {
                                                // No direct mapping, try fuzzy mapping
                                                if let mappingResult = ProductMappingService.shared.mapFoodProduct(food) {
                                                    switch mappingResult {
                                                    case .alcohol(let alcoholBeverage):
                                                        print("Fuzzy mapped search result '\(food.productName ?? "")' to alcohol product '\(alcoholBeverage.name)'")
                                                        activeScreen = .alcoholProductDetail(alcoholBeverage)
                                                    case .caffeine(let caffeineProduct):
                                                        print("Fuzzy mapped search result '\(food.productName ?? "")' to caffeine product '\(caffeineProduct.name)'")
                                                        activeScreen = .caffeineProductDetail(caffeineProduct)
                                                    }
                                                } else {
                                                    // No mapping found, treat as regular food
                                                    viewModel.selectedFoodForConfirmation = food
                                                }
                                            }
                                            
                                            viewModel.addToRecentSearches(food)
                                        }) {
                                            FoodSearchResultRow(food: food)
                                        }
                                        .buttonStyle(PlainButtonStyle())
                                        .listRowBackground(Color.clear)
                                        .listRowSeparator(.hidden)
                                    }
                                    
                                    // Show loading indicator at bottom if still searching
                                    if isLoadingFoodSearch && !searchResults.isEmpty {
                                        HStack {
                                            SpinningLoaderView()
                                                .scaleEffect(0.7) // Smaller loader for bottom
                                            
                                            Text("Searching for more results...")
                                                .foregroundColor(.white.opacity(0.8))
                                                .font(.caption)
                                                .fontWeight(.medium)
                                            
                                            Spacer()
                                        }
                                        .padding(.vertical, 12)
                                        .listRowBackground(Color.clear)
                                        .listRowSeparator(.hidden)
                                    }
                                }
                                .listStyle(PlainListStyle())
                                .scrollContentBackground(.hidden)
                            }
                        }
                    }
                }
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .principal) {
                        HStack {
                            Image(systemName: "fork.knife.circle.fill")
                                .foregroundColor(.white)
                            Text("Add to Meal")
                                .foregroundColor(.white)
                        }
                    }
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("Cancel") { isPresented = false }
                            .foregroundColor(.white)
                    }
                }
                .onChange(of: searchText) { _, newValue in
                    // Cancel any existing search immediately when user types
                    currentSearchTask?.cancel()
                    currentSearchTask = nil
                    
                    // Clear results immediately if search is empty
                    let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
                    if trimmed.isEmpty {
                        searchResults = []
                        foodSearchErrorMessage = nil
                        isLoadingFoodSearch = false
                        return
                    }
                    
                    // If search is too short, clear results immediately
                    if trimmed.count < 3 {  // Changed from 2 to 3
                        searchResults = []
                        isLoadingFoodSearch = false
                        return
                    }
                    
                    searchSubject.send(newValue)
                }
                .onReceive(searchSubject
                    .debounce(for: .milliseconds(250), scheduler: DispatchQueue.main) // Reduced from 400ms for faster response
                    .removeDuplicates()
                ) { debouncedQuery in
                    // Cancel previous search before starting new one
                    currentSearchTask?.cancel()
                    currentSearchTask = nil
                    
                    // Only search if query is meaningful (3+ characters)
                    let trimmed = debouncedQuery.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard trimmed.count >= 3 else {
                        searchResults = []
                        isLoadingFoodSearch = false
                        return
                    }
                    
                    // Create new search task with immediate execution
                    currentSearchTask = Task { @MainActor in
                        await performSearch(query: debouncedQuery)
                    }
                }
            }
            .preferredColorScheme(.dark)
            .onDisappear {
                // Cancel any pending search when view disappears
                currentSearchTask?.cancel()
                currentSearchTask = nil
            }
            .fullScreenCover(isPresented: $barcodeScannerViewModel.showScannerSheet) {
                BarcodeScannerView(
                    viewModel: barcodeScannerViewModel,
                    onProductFound: { product in
                        // Route to the unified FoodDetailConfirmationView for barcode scans
                        viewModel.selectedFoodForConfirmation = product
                    },
                    onAlcoholFound: { alcoholBeverage in
                        // Direct alcohol product match - navigate to detail view
                        print("Scanned alcohol product: \(alcoholBeverage.name)")
                        activeScreen = .alcoholProductDetail(alcoholBeverage)
                    },
                    onCaffeineFound: { caffeineProduct in
                        // Direct caffeine product match - navigate to detail view
                        print("Scanned caffeine product: \(caffeineProduct.name)")
                        activeScreen = .caffeineProductDetail(caffeineProduct)
                    },
                    onMappedAlcoholFound: { foodProduct, alcoholBeverage in
                        // Fuzzy matched alcohol product - navigate to alcohol detail view
                        print("Mapped food product '\(foodProduct.productName ?? "")' to alcohol product '\(alcoholBeverage.name)'")
                        activeScreen = .alcoholProductDetail(alcoholBeverage)
                    },
                    onMappedCaffeineFound: { foodProduct, caffeineProduct in
                        // Fuzzy matched caffeine product - navigate to caffeine detail view
                        print("Mapped food product '\(foodProduct.productName ?? "")' to caffeine product '\(caffeineProduct.name)'")
                        activeScreen = .caffeineProductDetail(caffeineProduct)
                    },
                    onProductNotFound: {
                        // Show the unified no results view instead of immediately opening create food
                        showBarcodeNoResultsView = true
                    }
                )
            }
            .sheet(isPresented: $showCreateFoodView) {
                CreateFoodView(onDismiss: {
                    showCreateFoodView = false
                })
                .environmentObject(authManager)
            }
            .sheet(isPresented: $showBarcodeNoResultsView) {
                NavigationView {
                    ZStack {
                        LinearGradient(
                            gradient: Gradient(colors: [Color("Nutrition").opacity(0.6), Color("Nutrition")]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        .edgesIgnoringSafeArea(.all)
                        
                        NoResultsFoundView(
                            message: "Barcode not found in our database. Would you like to add this food manually?",
                            onCreateFood: {
                                showBarcodeNoResultsView = false
                                showCreateFoodView = true
                            }
                        )
                    }
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarLeading) {
                            Button("Cancel") {
                                showBarcodeNoResultsView = false
                            }
                            .foregroundColor(.white)
                        }
                    }
                }
            }
        }
        
        // MARK: - Search Implementation
        @MainActor
        private func performSearch(query: String) async {
            let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Clear results if query is empty
            guard !trimmedQuery.isEmpty else {
                searchResults = []
                foodSearchErrorMessage = nil
                isLoadingFoodSearch = false
                return
            }
            
            // Allow searches with minimum 3 characters to match backend optimization
            guard trimmedQuery.count >= 3 else {
                searchResults = []
                isLoadingFoodSearch = false
                return
            }
            
            // Check if task was cancelled before starting
            guard !Task.isCancelled else { return }
            
            // Immediately clear existing results and start loading state
            searchResults = []
            isLoadingFoodSearch = true
            foodSearchErrorMessage = nil
            
            print("FoodSearchView: Performing search for query: '\(trimmedQuery)'")
            
            // Use Task for better cancellation support
            let searchTask = Task {
                return await withCheckedContinuation { (continuation: CheckedContinuation<Result<[FoodProduct], NetworkError>, Never>) in
                    foodSearchAPI.searchFood(query: trimmedQuery) { result in
                        continuation.resume(returning: result)
                    }
                }
            }
            
            do {
                let result = try await searchTask.value
                
                // Update UI immediately on main thread
                guard !Task.isCancelled else { return }
                
                isLoadingFoodSearch = false
                
                switch result {
                case .success(let products):
                    print("FoodSearchView: Search successful, found \(products.count) products")
                    
                    // Show results immediately - no delay
                    searchResults = products
                    foodSearchErrorMessage = nil
                    
                case .failure(let error):
                    print("FoodSearchView: Search failed with error: \(error)")
                    searchResults = []
                    foodSearchErrorMessage = "Search failed: \(error.localizedDescription)"
                }
            } catch {
                isLoadingFoodSearch = false
                searchResults = []
                foodSearchErrorMessage = "Search was cancelled"
            }
        }
    }
    
    // MARK: - Search Result Row Component
    struct FoodSearchResultRow: View {
        let food: FoodProduct
        
        /// Safely converts nutrition values to prevent NaN/infinity from reaching CoreGraphics
        private func safeNutritionValue(_ value: Double) -> Int {
            // Handle NaN, infinity, and negative values
            guard value.isFinite && !value.isNaN && value >= 0 else {
                return 0
            }
            // Cap extremely large values to prevent UI issues
            let cappedValue = min(value, 99999)
            return Int(cappedValue.rounded())
        }
        
        var body: some View {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(food.productName ?? "Unnamed Product")
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    if let brands = food.brands, !brands.isEmpty {
                        Text(brands)
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.7))
                    }
                    
                    HStack {
                        // Safe nutrition info with proper NaN/infinity handling
                        HStack(spacing: 12) {
                            NutritionBadge(
                                value: safeNutritionValue(food.calories),
                                unit: "kcal",
                                color: .vibrantPurple,
                                label: "Calories"
                            )
                            NutritionBadge(
                                value: safeNutritionValue(food.protein),
                                unit: "g",
                                color: .vibrantTeal,
                                label: "Protein"
                            )
                            NutritionBadge(
                                value: safeNutritionValue(food.carbs),
                                unit: "g",
                                color: .vibrantBlue,
                                label: "Carbs"
                            )
                            NutritionBadge(
                                value: safeNutritionValue(food.fat),
                                unit: "g",
                                color: .vibrantPink,
                                label: "Fat"
                            )
                        }
                        
                        Spacer()
                        
                        // Show nutrition basis instead of nutrition score
                        Text(food.nutritionBasis == "per_serving" ? "per serving" : "per 100g")
                            .font(.caption)
                            .fontWeight(.medium)
                            .padding(6)
                            .background(Color.white.opacity(0.2))
                            .foregroundColor(.white)
                            .cornerRadius(8)
                    }
                }
            }
            .padding()
            .background(Color.white.opacity(0.1))
            .cornerRadius(15)
        }
    }
    
    struct NutritionView_Previews: PreviewProvider {
        static var previews: some View {
            let auth = PreviewConstants.sampleAuthManagerUpdated
            NavigationView {
                NutritionView(
                    viewModel: NutritionViewModel(authManager: auth)
                )
                .environmentObject(auth)
            }
            .preferredColorScheme(.dark)
        }
    }
    
    extension Color {
        static func fromHex(_ hex: String) -> Color {
            let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
            var int: UInt64 = 0
            Scanner(string: hex).scanHexInt64(&int)
            let a, r, g, b: UInt64
            switch hex.count {
            case 3: (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
            case 6: (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
            case 8: (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
            default: (a, r, g, b) = (1, 1, 1, 0)
            }
            
            return Color(
                .sRGB,
                red: Double(r) / 255,
                green: Double(g) / 255,
                blue: Double(b) / 255,
                opacity: Double(a) / 255
            )
        }
    }
    
    // ========================
    // Reusable Card Container
    // ========================
    struct CardContainer<Content: View>: View {
        let content: Content
        init(@ViewBuilder content: () -> Content) {
            self.content = content()
        }
        var body: some View {
            content
                .padding(20)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.white)
                        .shadow(color: Color.black.opacity(0.15), radius: 8, x: 0, y: 4)
                        .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 2)
                )
                .padding(.horizontal)
        }
    }
    
    // MARK: - No Results Found View
    struct NoResultsFoundView: View {
        let message: String
        let onCreateFood: () -> Void
        
        var body: some View {
            VStack(spacing: 20) {
                Text(message)
                    .font(.headline)
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                
                // Create food button
                Button(action: onCreateFood) {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                        Text("Add Food Manually")
                            .font(.headline)
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(.white)
                    .padding()
                    .background(Color.white.opacity(0.2))
                    .cornerRadius(15)
                }
                
                Image(systemName: "leaf.circle.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.white.opacity(0.6))
            }
            .padding()
        }
    }
    

    
    

