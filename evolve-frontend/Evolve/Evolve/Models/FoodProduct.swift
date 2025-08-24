import Foundation

// Helper to handle mixed types in nutriments, if needed.
// For now, assuming [String: Double]? can work if server sends numbers for relevant fields.
// If nutriments contains non-numeric values that are needed, [String: AnyCodable]? or similar is better.

struct FoodProduct: Codable, Identifiable, Hashable {
    let id: String
    let productName: String?
    let brands: String?
    let nutriscoreGrade: String?
    
    // Direct nutritional values (per serving) from the backend
    let calories: Double
    let protein: Double
    let carbs: Double
    let fat: Double
    
    // Micronutrients
    let calcium: Double
    let iron: Double
    let potassium: Double
    let vitamin_a: Double
    let vitamin_c: Double
    let vitamin_b12: Double
    let fiber: Double
    let folate: Double

    // Keep nutriments for any other potential data, but it's no longer the primary source for key values
    let nutriments: [String: JSONValue]
    
    // Indicates whether nutrition data is per-serving or per-100g
    let nutritionBasis: String

    // Mapping information for specialized products (alcohol/caffeine)
    let mapping: SpecializedProductMapping?

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case idAlt = "id" // Accept "id" as an alternative
        case productName = "product_name"
        case brands
        case nutriscoreGrade = "nutriscore_grade"
        case nutriments
        
        // Add new top-level keys
        case calories, protein, carbs, fat
        case calcium, iron, potassium
        case vitamin_a = "vitamin_a"
        case vitamin_c = "vitamin_c"
        case vitamin_b12 = "vitamin_b12"
        case fiber, folate
        case nutritionBasis = "nutrition_basis"
        case mapping
    }
    
    // Custom init to provide default values for missing nutritional fields
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // Try _id first, then id
        if let idValue = try? container.decode(String.self, forKey: .id) {
            self.id = idValue
        } else if let idAltValue = try? container.decode(String.self, forKey: .idAlt) {
            self.id = idAltValue
        } else {
            throw DecodingError.keyNotFound(CodingKeys.id, .init(codingPath: decoder.codingPath, debugDescription: "No id or _id found"))
        }
        
        // Decode required fields
        self.productName = try container.decodeIfPresent(String.self, forKey: .productName)
        self.brands = try container.decodeIfPresent(String.self, forKey: .brands)
        self.nutriscoreGrade = try container.decodeIfPresent(String.self, forKey: .nutriscoreGrade)
        self.nutriments = try container.decodeIfPresent([String: JSONValue].self, forKey: .nutriments) ?? [:]
        
        // Decode nutritional values with defaults
        self.calories = try container.decodeIfPresent(Double.self, forKey: .calories) ?? 0
        self.protein = try container.decodeIfPresent(Double.self, forKey: .protein) ?? 0
        self.carbs = try container.decodeIfPresent(Double.self, forKey: .carbs) ?? 0
        self.fat = try container.decodeIfPresent(Double.self, forKey: .fat) ?? 0
        self.calcium = try container.decodeIfPresent(Double.self, forKey: .calcium) ?? 0
        self.iron = try container.decodeIfPresent(Double.self, forKey: .iron) ?? 0
        self.potassium = try container.decodeIfPresent(Double.self, forKey: .potassium) ?? 0
        self.vitamin_a = try container.decodeIfPresent(Double.self, forKey: .vitamin_a) ?? 0
        self.vitamin_c = try container.decodeIfPresent(Double.self, forKey: .vitamin_c) ?? 0
        self.vitamin_b12 = try container.decodeIfPresent(Double.self, forKey: .vitamin_b12) ?? 0
        self.fiber = try container.decodeIfPresent(Double.self, forKey: .fiber) ?? 0
        self.folate = try container.decodeIfPresent(Double.self, forKey: .folate) ?? 0
        self.nutritionBasis = try container.decodeIfPresent(String.self, forKey: .nutritionBasis) ?? "per_serving"
        self.mapping = try container.decodeIfPresent(SpecializedProductMapping.self, forKey: .mapping)
    }

    // Add a new, non-Decodable initializer for creating from custom food data
    init(id: String, productName: String?, brands: String?, calories: Double, protein: Double, carbs: Double, fat: Double) {
        self.id = id
        self.productName = productName
        self.brands = brands
        self.nutriscoreGrade = nil // Custom foods don't have this
        self.calories = calories
        self.protein = protein
        self.carbs = carbs
        self.fat = fat
        
        // Set defaults for other fields
        self.calcium = 0
        self.iron = 0
        self.potassium = 0
        self.vitamin_a = 0
        self.vitamin_c = 0
        self.vitamin_b12 = 0
        self.fiber = 0
        self.folate = 0
        self.nutriments = [:] // Empty dict as it's not applicable
        self.nutritionBasis = "per_serving" // Default for custom foods
        self.mapping = nil // Custom foods don't have mapping
    }

    // Add a comprehensive initializer that accepts all micronutrient parameters
    init(id: String, productName: String?, brands: String?, calories: Double, protein: Double, carbs: Double, fat: Double, calcium: Double, iron: Double, potassium: Double, vitamin_a: Double, vitamin_c: Double, vitamin_b12: Double, fiber: Double, folate: Double) {
        self.id = id
        self.productName = productName
        self.brands = brands
        self.nutriscoreGrade = nil // Custom foods don't have this
        self.calories = calories
        self.protein = protein
        self.carbs = carbs
        self.fat = fat
        self.calcium = calcium
        self.iron = iron
        self.potassium = potassium
        self.vitamin_a = vitamin_a
        self.vitamin_c = vitamin_c
        self.vitamin_b12 = vitamin_b12
        self.fiber = fiber
        self.folate = folate
        self.nutriments = [:] // Empty dict as it's not applicable
        self.nutritionBasis = "per_serving" // Default for custom foods
        self.mapping = nil // Custom foods don't have mapping
    }

    // Helper computed properties for easy access to nutriments (per 100g/ml)
    // Updated to use the correct _100g keys from the backend
    var caloriesPer100g: Double {
        // Use energy-kcal_100g for calories per 100g, fallback to energy_100g converted from kJ
        (nutriments["energy-kcal_100g"]?.doubleValue ?? (nutriments["energy_100g"]?.doubleValue ?? 0.0) * 0.239006)
    }
    var proteinPer100g: Double {
        nutriments["proteins_100g"]?.doubleValue ?? 0.0
    }
    var carbsPer100g: Double {
        nutriments["carbohydrates_100g"]?.doubleValue ?? 0.0
    }
    var fatPer100g: Double {
        nutriments["fat_100g"]?.doubleValue ?? 0.0
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encodeIfPresent(productName, forKey: .productName)
        try container.encodeIfPresent(brands, forKey: .brands)
        try container.encodeIfPresent(nutriscoreGrade, forKey: .nutriscoreGrade)
        try container.encode(nutriments, forKey: .nutriments)
        try container.encode(calories, forKey: .calories)
        try container.encode(protein, forKey: .protein)
        try container.encode(carbs, forKey: .carbs)
        try container.encode(fat, forKey: .fat)
        try container.encode(calcium, forKey: .calcium)
        try container.encode(iron, forKey: .iron)
        try container.encode(potassium, forKey: .potassium)
        try container.encode(vitamin_a, forKey: .vitamin_a)
        try container.encode(vitamin_c, forKey: .vitamin_c)
        try container.encode(vitamin_b12, forKey: .vitamin_b12)
        try container.encode(fiber, forKey: .fiber)
        try container.encode(folate, forKey: .folate)
        try container.encode(nutritionBasis, forKey: .nutritionBasis)
        try container.encodeIfPresent(mapping, forKey: .mapping)
    }
}
