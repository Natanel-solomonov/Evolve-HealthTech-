import Foundation

/// Model for promotion discount code info (used in promotions and redemptions)
struct PromotionDiscountCodeInfo: Codable, Identifiable, Hashable {
    let id: UUID
    let code: String
    let isUsed: Bool
    
    enum CodingKeys: String, CodingKey {
        case id, code
        case isUsed = "is_used"
    }
} 