import Foundation

struct AffiliatePromotionRedemption: Codable, Identifiable, Hashable {
    let id: UUID
    // Backend serializer sends the full nested AffiliatePromotion object
    let promotion: AffiliatePromotion
    
    // Backend serializer sends user's phone number as a string for the 'user' field
    let user: String 
    
    let redeemedAt: String // From backend DateTimeField (auto_now_add=True)
    
    enum CodingKeys: String, CodingKey {
        case id, promotion, user // user key is direct match
        case redeemedAt = "redeemed_at"
    }
} 