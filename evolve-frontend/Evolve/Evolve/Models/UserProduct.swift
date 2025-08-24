import Foundation

/// Model representing a product/service that a user has redeemed from an affiliate promotion
struct UserProduct: Codable, Identifiable, Hashable {
    let id: UUID
    let user: String // User's phone number
    let sourcePromotion: AffiliatePromotion?
    let productName: String
    let name: String // Frontend compatibility field (same as productName)
    let productDescription: String?
    let productImage: String?
    let imageName: String? // Frontend compatibility field for image handling
    let category: String
    let categoryDisplay: String?
    let status: String
    let statusDisplay: String?
    let redeemedAt: String
    let expiresAt: String?
    let lastUsedAt: String?
    let affiliateName: String
    let pointsSpent: Int
    let originalValue: String? // Decimal as string
    let userNotes: String?
    let isFavorite: Bool
    let isExpired: Bool
    let daysUntilExpiry: Int?
    let createdAt: String
    let updatedAt: String
    
    enum CodingKeys: String, CodingKey {
        case id, user, category, status, affiliateName, userNotes, isFavorite, isExpired, createdAt, updatedAt
        case sourcePromotion = "source_promotion"
        case productName = "product_name"
        case name
        case productDescription = "product_description"
        case productImage = "product_image"
        case imageName = "imageName"
        case categoryDisplay = "category_display"
        case statusDisplay = "status_display"
        case redeemedAt = "redeemed_at"
        case expiresAt = "expires_at"
        case lastUsedAt = "last_used_at"
        case pointsSpent = "points_spent"
        case originalValue = "original_value"
        case daysUntilExpiry = "days_until_expiry"
    }
}

/// Model for updating user product preferences
struct UserProductUpdate: Codable {
    let userNotes: String?
    let isFavorite: Bool?
    let status: String?
    
    enum CodingKeys: String, CodingKey {
        case userNotes = "user_notes"
        case isFavorite = "is_favorite"
        case status
    }
}

/// Model for user product statistics
struct UserProductStats: Codable {
    let totalProducts: Int
    let activeProducts: Int
    let favoritesCount: Int
    let recentProducts: Int
    let totalSavings: Double
    let totalPointsSpent: Int
    let categoryBreakdown: [String: Int]
    let statusBreakdown: [String: Int]
    
    enum CodingKeys: String, CodingKey {
        case totalProducts = "total_products"
        case activeProducts = "active_products"
        case favoritesCount = "favorites_count"
        case recentProducts = "recent_products"
        case totalSavings = "total_savings"
        case totalPointsSpent = "total_points_spent"
        case categoryBreakdown = "category_breakdown"
        case statusBreakdown = "status_breakdown"
    }
} 