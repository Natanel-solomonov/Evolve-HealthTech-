import Foundation

// MARK: - DailyCalorieTracker
struct DailyCalorieTracker: Codable, Identifiable, Hashable {
    let id: Int
    let userDetails: String
    let date: String 
    let totalCalories: Int
    let calorieGoal: Int
    let proteinGrams: Double
    let carbsGrams: Double
    let fatGrams: Double
    
    // MICRONUTRIENTS
    let fiberGrams: Double?
    let ironMilligrams: Double?
    let calciumMilligrams: Double?
    let vitaminAMicrograms: Double?
    let vitaminCMilligrams: Double?
    let vitaminB12Micrograms: Double?
    let folateMicrograms: Double?
    let potassiumMilligrams: Double?

    // ALCOHOL TRACKING - NEW FIELDS
    let alcoholGrams: Double?
    let standardDrinks: Double?

    // CAFFEINE TRACKING - NEW FIELDS
    let caffeineMg: Double?

    let createdAt: String
    let updatedAt: String
    let foodEntries: [FoodEntry]
    
    enum CodingKeys: String, CodingKey {
        case id, date
        case userDetails = "user_details"
        case totalCalories = "total_calories"
        case calorieGoal = "calorie_goal"
        case proteinGrams = "protein_grams"
        case carbsGrams = "carbs_grams"
        case fatGrams = "fat_grams"
        
        // MICRONUTRIENTS
        case fiberGrams = "fiber_grams"
        case ironMilligrams = "iron_milligrams"
        case calciumMilligrams = "calcium_milligrams"
        case vitaminAMicrograms = "vitamin_a_micrograms"
        case vitaminCMilligrams = "vitamin_c_milligrams"
        case vitaminB12Micrograms = "vitamin_b12_micrograms"
        case folateMicrograms = "folate_micrograms"
        case potassiumMilligrams = "potassium_milligrams"
        
        // ALCOHOL TRACKING
        case alcoholGrams = "alcohol_grams"
        case standardDrinks = "standard_drinks"

        // CAFFEINE TRACKING
        case caffeineMg = "caffeine_mg"

        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case foodEntries = "food_entries"
    }
}

// MARK: - FoodEntry (REVISED AND ENSURED OPTIONALS)
struct FoodEntry: Codable, Identifiable, Hashable {
    let id: Int
    let dailyLog: Int?
    let foodName: String
    let servingSize: Double
    let servingUnit: String
    let calories: Int?
    let protein: Double?
    let carbs: Double?
    let fat: Double?
    
    // MICRONUTRIENTS
    let fiberGrams: Double?
    let ironMilligrams: Double?
    let calciumMilligrams: Double?
    let vitaminAMicrograms: Double?
    let vitaminCMilligrams: Double?
    let vitaminB12Micrograms: Double?
    let folateMicrograms: Double?
    let potassiumMilligrams: Double?
    
    // ALCOHOL TRACKING - NEW FIELDS
    let alcoholicBeverage: String? // AlcoholicBeverage ID reference
    let alcoholGrams: Double?
    let standardDrinks: Double?
    let alcoholCategory: String?

    // CAFFEINE TRACKING - NEW FIELDS
    let caffeineProduct: String? // CaffeineProduct ID reference
    let caffeineMg: Double?
    let caffeineCategory: String?

    let mealType: String 
    let timeConsumed: String
    let createdAt: String?
    let updatedAt: String?
    let foodProductId: String?
    let customFoodId: Int?

    enum CodingKeys: String, CodingKey {
        case id
        case dailyLog = "daily_log"
        case foodName = "food_name"
        case servingSize = "serving_size"
        case servingUnit = "serving_unit"
        case calories, protein, carbs, fat
        
        // MICRONUTRIENTS
        case fiberGrams = "fiber_grams"
        case ironMilligrams = "iron_milligrams"
        case calciumMilligrams = "calcium_milligrams"
        case vitaminAMicrograms = "vitamin_a_micrograms"
        case vitaminCMilligrams = "vitamin_c_milligrams"
        case vitaminB12Micrograms = "vitamin_b12_micrograms"
        case folateMicrograms = "folate_micrograms"
        case potassiumMilligrams = "potassium_milligrams"
        
        // ALCOHOL TRACKING
        case alcoholicBeverage = "alcoholic_beverage"
        case alcoholGrams = "alcohol_grams"
        case standardDrinks = "standard_drinks"
        case alcoholCategory = "alcohol_category"
        
        // CAFFEINE TRACKING
        case caffeineProduct = "caffeine_product"
        case caffeineMg = "caffeine_mg"
        case caffeineCategory = "caffeine_category"
        
        case mealType = "meal_type"
        case timeConsumed = "time_consumed"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case foodProductId = "food_product_id"
        case customFoodId = "custom_food_id"
    }
}

// MARK: - AlcoholicBeverage Model (NEW)
struct AlcoholicBeverage: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let brand: String?
    let category: String
    let alcoholContentPercent: Double
    let alcoholGrams: Double
    let calories: Double
    let carbsGrams: Double
    let servingSizeML: Double
    let servingDescription: String
    let description: String?
    let popularityScore: Int
    let createdAt: String
    let updatedAt: String
    
    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case name, brand, category, description
        case alcoholContentPercent = "alcohol_content_percent"
        case alcoholGrams = "alcohol_grams"
        case calories
        case carbsGrams = "carbs_grams"
        case servingSizeML = "serving_size_ml"
        case servingDescription = "serving_description"
        case popularityScore = "popularity_score"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
    
    // Computed properties for category display and icon
    var categoryDisplay: String {
        switch category {
        case "beer": return "Beer (bottle/can or pint)"
        case "wine": return "Glass of wine"
        case "sparkling": return "Champagne / sparkling wine (flute)"
        case "fortified": return "Fortified wine / dessert wine (small glass)"
        case "liquor": return "Shot of liquor (straight spirit)"
        case "cocktail": return "Mixed drink / Cocktail"
        default: return category.capitalized
        }
    }
    
    var categoryIcon: String {
        switch category {
        case "beer": return "🍺"
        case "wine": return "🍷"
        case "sparkling": return "🥂"
        case "fortified": return "🍷"
        case "liquor": return "🥃"
        case "cocktail": return "🍸"
        default: return "🍹"
        }
    }
}

// MARK: - Alcohol Category Model (NEW)
struct AlcoholCategory: Codable, Identifiable, Hashable {
    let key: String
    let name: String
    let icon: String
    let count: Int
    
    var id: String { key }
}

// MARK: - Alcohol API Response Models (NEW)
struct AlcoholCategoriesResponse: Codable {
    let categories: [AlcoholCategory]
}

struct AlcoholSearchResponse: Codable {
    let beverages: [AlcoholicBeverage]
    let totalCount: Int
    let hasMore: Bool
    
    enum CodingKeys: String, CodingKey {
        case beverages
        case totalCount = "total_count"
        case hasMore = "has_more"
    }
}

struct AlcoholCategoryResponse: Codable {
    let beverages: [AlcoholicBeverage]
    let totalCount: Int
    let hasMore: Bool
    
    enum CodingKeys: String, CodingKey {
        case beverages
        case totalCount = "total_count"
        case hasMore = "has_more"
    }
}

// MARK: - Product Mapping Response Models (NEW)
enum BarcodeProductResult: Equatable, Hashable {
    case food(FoodProduct)
    case alcohol(SpecializedProductData)
    case caffeine(SpecializedProductData)
}

struct SpecializedProductMapping: Codable, Equatable, Hashable {
    let type: String // 'alcohol' or 'caffeine'
    let specializedProduct: SpecializedProductData
    
    enum CodingKeys: String, CodingKey {
        case type
        case specializedProduct = "specialized_product"
    }
}

struct SpecializedProductData: Codable, Equatable, Hashable {
    let id: String
    let name: String
    let brand: String?
    let category: String
    
    // Alcohol-specific fields
    let alcoholContentPercent: Double?
    let alcoholGrams: Double?
    let carbsGrams: Double?
    let servingSizeML: Double?
    let servingDescription: String?
    
    // Caffeine-specific fields  
    let subCategory: String?
    let caffeineMgPerServing: Double?
    let sugarGPerServing: Double?
    let servingSizeDesc: String?
    let caloriesPerServing: Double?  // Backend returns 'calories_per_serving' for caffeine
    
    // Common fields
    let calories: Double?  // Backend returns 'calories' for alcohol
    let categoryDisplay: String?
    let categoryIcon: String?
    
    enum CodingKeys: String, CodingKey {
        case id, name, brand, category, calories
        case alcoholContentPercent = "alcohol_content_percent"
        case alcoholGrams = "alcohol_grams"
        case carbsGrams = "carbs_grams"
        case servingSizeML = "serving_size_ml"
        case servingDescription = "serving_description"
        case subCategory = "sub_category"
        case caffeineMgPerServing = "caffeine_mg_per_serving"
        case sugarGPerServing = "sugar_g_per_serving"
        case servingSizeDesc = "serving_size_desc"
        case caloriesPerServing = "calories_per_serving"  // For caffeine products
        case categoryDisplay = "category_display"
        case categoryIcon = "category_icon"
    }
}

struct BarcodeResponse: Codable, Equatable, Hashable {
    let type: String?
    let specializedProduct: SpecializedProductData?
    let originalFoodProduct: FoodProduct?
    
    // For regular food products (when type is nil)
    let id: String?
    let productName: String?
    let brands: String?
    let calories: Double?
    let protein: Double?
    let carbs: Double?
    let fat: Double?
    let isCustom: Bool?
    
    enum CodingKeys: String, CodingKey {
        case type
        case specializedProduct = "specialized_product"
        case originalFoodProduct = "original_food_product"
        case id
        case productName = "product_name"
        case brands
        case calories, protein, carbs, fat
        case isCustom = "is_custom"
    }
}

// MARK: - JSONValue (unchanged)
enum JSONValue: Codable, Hashable {
    case string(String)
    case int(Int)
    case double(Double)
    case bool(Bool)
    case null

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let stringValue = try? container.decode(String.self) {
            self = .string(stringValue)
        } else if let intValue = try? container.decode(Int.self) {
            self = .int(intValue)
        } else if let doubleValue = try? container.decode(Double.self) {
            self = .double(doubleValue)
        } else if let boolValue = try? container.decode(Bool.self) {
            self = .bool(boolValue)
        } else if container.decodeNil() {
            self = .null
        } else {
            throw DecodingError.typeMismatch(JSONValue.self, DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Unsupported JSON value"))
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let value): try container.encode(value)
        case .int(let value): try container.encode(value)
        case .double(let value): try container.encode(value)
        case .bool(let value): try container.encode(value)
        case .null: try container.encodeNil()
        }
    }
    
    var doubleValue: Double? {
        switch self {
        case .double(let val): return val
        case .int(let val): return Double(val)
        case .string(let val): return Double(val)
        default: return nil
        }
    }
    
    var intValue: Int? {
         switch self {
         case .int(let val): return val
         case .double(let val): return Int(val)
         case .string(let val): return Int(val)
         default: return nil
         }
     }
    
    var stringValue: String? {
         switch self {
         case .string(let val): return val
         case .int(let val): return String(val)
         case .double(let val): return String(val)
         case .bool(let val): return String(val)
         default: return nil
         }
     }
}

struct DailyLogResponse: Decodable {
    let id: Int
    let userDetails: String
    let date: String
    let totalCalories: Int
    let calorieGoal: Int
    let proteinGrams: Double
    let carbsGrams: Double
    let fatGrams: Double
    let fiberGrams: Double?
    let ironMilligrams: Double?
    let calciumMilligrams: Double?
    let vitaminAMicrograms: Double?
    let vitaminCMilligrams: Double?
    let vitaminB12Micrograms: Double?
    let folateMicrograms: Double?
    let potassiumMilligrams: Double?
    
    // ALCOHOL TRACKING - NEW FIELDS
    let alcoholGrams: Double?
    let standardDrinks: Double?
    
    // CAFFEINE TRACKING - NEW FIELDS
    let caffeineMg: Double?
    
    let createdAt: String
    let updatedAt: String
    let foodEntries: [FoodEntry]

    enum CodingKeys: String, CodingKey {
        case id
        case userDetails = "user_details"
        case date
        case totalCalories = "total_calories"
        case calorieGoal = "calorie_goal"
        case proteinGrams = "protein_grams"
        case carbsGrams = "carbs_grams"
        case fatGrams = "fat_grams"
        case fiberGrams = "fiber_grams"
        case ironMilligrams = "iron_milligrams"
        case calciumMilligrams = "calcium_milligrams"
        case vitaminAMicrograms = "vitamin_a_micrograms"
        case vitaminCMilligrams = "vitamin_c_milligrams"
        case vitaminB12Micrograms = "vitamin_b12_micrograms"
        case folateMicrograms = "folate_micrograms"
        case potassiumMilligrams = "potassium_milligrams"
        
        // ALCOHOL TRACKING
        case alcoholGrams = "alcohol_grams"
        case standardDrinks = "standard_drinks"
        
        // CAFFEINE TRACKING
        case caffeineMg = "caffeine_mg"
        
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case foodEntries = "food_entries"
    }
} 

// MARK: - Helper Extensions for Alcohol Tracking
extension FoodEntry {
    /// Returns true if this food entry is an alcoholic beverage
    var isAlcoholicBeverage: Bool {
        return alcoholicBeverage != nil
    }
    
    /// Returns the appropriate display text for diary entries
    var diaryDisplayText: String {
        if isAlcoholicBeverage {
            let drinks = standardDrinks ?? 0.0
            let drinkText = drinks == 1.0 ? "1 standard drink" : "\(String(format: "%.1f", drinks)) standard drinks"
            return "\(calories ?? 0) cal • \(drinkText)"
        } else {
            return "\(calories ?? 0) cal • \(servingUnit)"
        }
    }
    
    /// Returns the alcohol category icon if this is an alcoholic beverage
    var alcoholIcon: String? {
        guard isAlcoholicBeverage, let category = alcoholCategory else { return nil }
        
        switch category {
        case "beer": return "🍺"
        case "wine": return "🍷"
        case "champagne": return "🥂"
        case "fortified_wine": return "🍷"
        case "liquor": return "🥃"
        case "cocktail": return "🍸"
        default: return "🍹"
        }
    }
}

extension DailyCalorieTracker {
    /// Returns the total alcohol consumption for the day
    var totalAlcoholGrams: Double {
        return alcoholGrams ?? 0.0
    }
    
    /// Returns the total standard drinks for the day
    var totalStandardDrinks: Double {
        return standardDrinks ?? 0.0
    }
    
    /// Returns unique alcohol category icons for beverages tracked today
    var alcoholCardIcons: [String] {
        let alcoholEntries = foodEntries.filter { $0.isAlcoholicBeverage }
        let categories = alcoholEntries.compactMap { $0.alcoholCategory }
        let uniqueCategories = Array(Set(categories))
        
        return uniqueCategories.compactMap { category in
            switch category {
            case "beer": return "🍺"
            case "wine": return "🍷"
            case "champagne": return "🥂"
            case "fortified_wine": return "🍷"
            case "liquor": return "🥃"
            case "cocktail": return "🍸"
            default: return "🍹"
            }
        }
    }
    
    /// Returns true if any alcoholic beverages were tracked today
    var hasAlcoholEntries: Bool {
        return foodEntries.contains { $0.isAlcoholicBeverage }
    }
    
    // MARK: - Caffeine Tracking Extensions
    
    /// Returns the total caffeine consumption for the day
    var totalCaffeineMg: Double {
        return caffeineMg ?? 0.0
    }
    
    /// Returns unique caffeine category icons for products tracked today
    var caffeineCardIcons: [String] {
        let caffeineEntries = foodEntries.filter { $0.isCaffeineProduct }
        let categories = caffeineEntries.compactMap { $0.caffeineCategory }
        let uniqueCategories = Array(Set(categories))
        
        return uniqueCategories.compactMap { category in
            switch category {
            case "coffee": return "☕"
            case "energy_drink": return "⚡"
            case "tea": return "🫖"
            case "soda": return "🥤"
            case "supplement": return "💊"
            default: return "🥤"
            }
        }
    }
    
    /// Returns true if any caffeine products were tracked today
    var hasCaffeineEntries: Bool {
        return foodEntries.contains { $0.isCaffeineProduct }
        }
}

// MARK: - CaffeineProduct Model (NEW)
struct CaffeineProduct: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let brand: String?
    let category: String
    let subCategory: String?
    let flavorOrVariant: String?
    let servingSizeML: Double
    let servingSizeDesc: String
    let caffeineMgPerServing: Double
    let caffeineMgPer100ML: Double?
    let caloriesPerServing: Double
    let sugarGPerServing: Double?
    let upc: String?
    let source: String?
    let createdAt: String
    let updatedAt: String
    
    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case name, brand, category
        case subCategory = "sub_category"
        case flavorOrVariant = "flavor_or_variant"
        case servingSizeML = "serving_size_ml"
        case servingSizeDesc = "serving_size_desc"
        case caffeineMgPerServing = "caffeine_mg_per_serving"
        case caffeineMgPer100ML = "caffeine_mg_per_100ml"
        case caloriesPerServing = "calories_per_serving"
        case sugarGPerServing = "sugar_g_per_serving"
        case upc, source
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

// MARK: - CaffeineCategory Model (NEW)
struct CaffeineCategory: Codable, Identifiable, Hashable {
    let key: String
    let name: String
    let icon: String
    let count: Int
    
    var id: String { key }
}

// MARK: - CaffeineProduct Extensions
extension CaffeineProduct {
    /// Returns the display name for the product category
    var categoryDisplay: String {
        switch category {
        case "energy_drink": return "Energy Drink"
        case "coffee": return "Coffee"
        case "tea": return "Tea"
        case "soda": return "Soda/Soft Drink"
        case "supplement": return "Supplement"
        default: return category.capitalized
        }
    }
    
    /// Returns the appropriate emoji icon for the product category
    var categoryIcon: String {
        switch category {
        case "energy_drink": return "⚡"
        case "coffee": return "☕"
        case "tea": return "🫖"
        case "soda": return "🥤"
        case "supplement": return "💊"
        default: return "🥤"
        }
    }
    
    /// Returns a formatted display name with brand and flavor
    var displayName: String {
        var components: [String] = []
        
        if let brand = brand, !brand.isEmpty {
            components.append(brand)
        }
        
        components.append(name)
        
        if let flavor = flavorOrVariant, !flavor.isEmpty {
            components.append("(\(flavor))")
        }
        
        return components.joined(separator: " ")
    }
    
    /// Returns formatted caffeine amount with unit
    var caffeineDisplay: String {
        return "\(Int(caffeineMgPerServing))mg"
    }
    
    /// Returns formatted serving size information
    var servingDisplay: String {
        return servingSizeDesc
    }
}

extension FoodEntry {
    /// Returns true if this entry represents a caffeine product
    var isCaffeineProduct: Bool {
        return caffeineProduct != nil && caffeineMg != nil
    }
    
    /// Returns the appropriate emoji icon for the caffeine category
    var caffeineIcon: String? {
        guard isCaffeineProduct, let category = caffeineCategory else { return nil }
        
        switch category {
        case "coffee": return "☕"
        case "energy_drink": return "⚡"
        case "tea": return "🫖"
        case "soda": return "🥤"
        case "supplement": return "💊"
        default: return "🥤"
        }
    }
}

// MARK: - SpecializedProductData Extensions
extension SpecializedProductData {
    /// Converts to AlcoholicBeverage if all required fields are present
    func toAlcoholicBeverage() -> AlcoholicBeverage? {
        guard let alcoholContentPercent = alcoholContentPercent,
              let alcoholGrams = alcoholGrams,
              let carbsGrams = carbsGrams,
              let servingSizeML = servingSizeML,
              let servingDescription = servingDescription,
              let calories = calories else {
            return nil
        }
        
        return AlcoholicBeverage(
            id: id,
            name: name,
            brand: brand,
            category: category,
            alcoholContentPercent: alcoholContentPercent,
            alcoholGrams: alcoholGrams,
            calories: calories,
            carbsGrams: carbsGrams,
            servingSizeML: servingSizeML,
            servingDescription: servingDescription,
            description: nil,
            popularityScore: 50,
            createdAt: "",
            updatedAt: ""
        )
    }
    
    /// Converts to CaffeineProduct if all required fields are present
    func toCaffeineProduct() -> CaffeineProduct? {
        guard let caffeineMgPerServing = caffeineMgPerServing,
              let servingSizeML = servingSizeML,
              let servingSizeDesc = servingSizeDesc,
              let caloriesPerServing = caloriesPerServing else {
            return nil
        }
        
        return CaffeineProduct(
            id: id,
            name: name,
            brand: brand,
            category: category,
            subCategory: subCategory,
            flavorOrVariant: nil,
            servingSizeML: servingSizeML,
            servingSizeDesc: servingSizeDesc,
            caffeineMgPerServing: caffeineMgPerServing,
            caffeineMgPer100ML: nil,
            caloriesPerServing: caloriesPerServing,
            sugarGPerServing: sugarGPerServing,
            upc: nil,
            source: nil,
            createdAt: "",
            updatedAt: ""
        )
    }
}

// MARK: - Water Tracking Models (NEW)

struct WaterEntry: Codable, Identifiable, Hashable {
    let id: Int
    let amountMl: Double
    let containerType: String
    let timeConsumed: String
    let createdAt: String
    let updatedAt: String
    
    enum CodingKeys: String, CodingKey {
        case id
        case amountMl = "amount_ml"
        case containerType = "container_type"
        case timeConsumed = "time_consumed"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

enum WaterContainerType: String, CaseIterable {
    case glass = "glass"
    case cup = "cup"
    case bottleSmall = "bottle_small"
    case bottleLarge = "bottle_large"
    case bottleXL = "bottle_xl"
    case custom = "custom"
    
    var displayName: String {
        switch self {
        case .glass: return "Glass"
        case .cup: return "Cup"
        case .bottleSmall: return "Small Bottle"
        case .bottleLarge: return "Large Bottle"
        case .bottleXL: return "XL Bottle"
        case .custom: return "Custom"
        }
    }
    
    var defaultAmountMl: Double {
        switch self {
        case .glass: return 250
        case .cup: return 240
        case .bottleSmall: return 330
        case .bottleLarge: return 500
        case .bottleXL: return 1000
        case .custom: return 250
        }
    }
    
    var icon: String {
        switch self {
        case .glass: return "🥤"
        case .cup: return "☕"
        case .bottleSmall: return "🍼"
        case .bottleLarge: return "🧴"
        case .bottleXL: return "💧"
        case .custom: return "💧"
        }
    }
}

struct WaterSettings: Codable {
    let waterGoalMl: Double
    let preferredUnit: String
    
    enum CodingKeys: String, CodingKey {
        case waterGoalMl = "water_goal_ml"
        case preferredUnit = "preferred_unit"
    }
}

struct WaterDailySummary: Codable {
    let date: String
    let waterConsumedMl: Double
    let waterGoalMl: Double
    let progressPercentage: Double
    let entriesCount: Int
    let entries: [WaterEntry]
    
    enum CodingKeys: String, CodingKey {
        case date
        case waterConsumedMl = "water_consumed_ml"
        case waterGoalMl = "water_goal_ml"
        case progressPercentage = "progress_percentage"
        case entriesCount = "entries_count"
        case entries
    }
}

