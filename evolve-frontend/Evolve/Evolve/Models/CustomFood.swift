import Foundation

struct CustomFoods: Codable, Identifiable, Hashable {
    let id: Int
    let user: String // User ID
    let name: String
    let barcodeId: String?
    
    // Macronutrients
    let calories: Double
    let protein: Double
    let carbs: Double
    let fat: Double
    
    // Micronutrients
    let calcium: Double?
    let iron: Double?
    let potassium: Double?
    let vitaminA: Double?
    let vitaminC: Double?
    let vitaminB12: Double?
    
    let createdAt: String
    let updatedAt: String
    
    enum CodingKeys: String, CodingKey {
        case id, user, name, calories, protein, carbs, fat, calcium, iron, potassium
        case barcodeId = "barcode_id"
        case vitaminA = "vitamin_a"
        case vitaminC = "vitamin_c"
        case vitaminB12 = "vitamin_b12"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
} 
