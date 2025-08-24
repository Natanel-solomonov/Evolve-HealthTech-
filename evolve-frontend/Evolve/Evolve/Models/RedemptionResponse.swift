import Foundation

/// Model representing the response when a user redeems a promotion
struct RedemptionResponse: Codable {
    let message: String
    let redemption: AffiliatePromotionRedemption
    let pointsSpent: Int
    let remainingPoints: Int
    let discountCode: DiscountCodeInfo
    
    enum CodingKeys: String, CodingKey {
        case message, redemption
        case pointsSpent = "points_spent"
        case remainingPoints = "remaining_points"
        case discountCode = "discount_code"
    }
}

/// Model representing discount code information provided after redemption
struct DiscountCodeInfo: Codable {
    let code: String
    let instructions: String
    let affiliateWebsite: String?
    let validUntil: String? // ISO date string
    
    enum CodingKeys: String, CodingKey {
        case code, instructions
        case affiliateWebsite = "affiliate_website"
        case validUntil = "valid_until"
    }
} 