import Foundation

struct AffiliatePromotion: Codable, Identifiable, Hashable {
    let id: UUID
    let affiliate: Affiliate // Nested Affiliate details from AffiliateSerializer
    let title: String
    let description: String
    let originalPrice: String? // Backend DecimalField is serialized as a string; use String for safe decoding
    let pointValue: Int?         // Backend IntegerField, default 0
    let productImage: String?   // Backend ImageField (URL string), nullable
    let startDate: Date         // Backend DateTimeField
    let endDate: Date           // Backend DateTimeField
    let isActive: Bool?          // Backend BooleanField, default True
    let isCurrentlyActive: Bool  // Backend computed property
    let daysUntilExpiry: Int     // Backend computed property
    let offerSpecifics: String?  // Local property for offer details (e.g., "First box free")
    
    // From AffiliatePromotionSerializer, uses AppUserSimpleSerializer
    let assignedUsers: [SimpleAppUser]? 
    
    // This field is manually added by the /users/{id}/affiliate-promotions/ backend endpoint.
    // It won't be present for /affiliate-promotions/ endpoint.
    let discountCode: PromotionDiscountCodeInfo? 
    
    enum CodingKeys: String, CodingKey {
        case id, affiliate, title, description
        case originalPrice = "original_price"
        case pointValue = "point_value"
        case productImage = "product_image"
        case startDate = "start_date"
        case endDate = "end_date"
        case isActive = "is_active"
        case isCurrentlyActive = "is_currently_active"
        case daysUntilExpiry = "days_until_expiry"
        case assignedUsers = "assigned_users"
        case discountCode = "discount_code" // Key name as added by backend view
        case offerSpecifics = "offer_specifics" // Local property
    }

    // Custom decoder to handle offerSpecifics which might not be in backend response
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        id = try container.decode(UUID.self, forKey: .id)
        affiliate = try container.decode(Affiliate.self, forKey: .affiliate)
        title = try container.decode(String.self, forKey: .title)
        description = try container.decode(String.self, forKey: .description)
        originalPrice = try container.decodeIfPresent(String.self, forKey: .originalPrice)
        pointValue = try container.decodeIfPresent(Int.self, forKey: .pointValue)
        productImage = try container.decodeIfPresent(String.self, forKey: .productImage)
        startDate = try container.decode(Date.self, forKey: .startDate)
        endDate = try container.decode(Date.self, forKey: .endDate)
        isActive = try container.decodeIfPresent(Bool.self, forKey: .isActive)
        isCurrentlyActive = try container.decode(Bool.self, forKey: .isCurrentlyActive)
        daysUntilExpiry = try container.decode(Int.self, forKey: .daysUntilExpiry)
        assignedUsers = try container.decodeIfPresent([SimpleAppUser].self, forKey: .assignedUsers)
        discountCode = try container.decodeIfPresent(PromotionDiscountCodeInfo.self, forKey: .discountCode)
        
        // offerSpecifics is a local property that might not be in backend response
        offerSpecifics = try container.decodeIfPresent(String.self, forKey: .offerSpecifics)
    }
    
    // Custom encoder
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(id, forKey: .id)
        try container.encode(affiliate, forKey: .affiliate)
        try container.encode(title, forKey: .title)
        try container.encode(description, forKey: .description)
        try container.encodeIfPresent(originalPrice, forKey: .originalPrice)
        try container.encodeIfPresent(pointValue, forKey: .pointValue)
        try container.encodeIfPresent(productImage, forKey: .productImage)
        try container.encode(startDate, forKey: .startDate)
        try container.encode(endDate, forKey: .endDate)
        try container.encodeIfPresent(isActive, forKey: .isActive)
        try container.encode(isCurrentlyActive, forKey: .isCurrentlyActive)
        try container.encode(daysUntilExpiry, forKey: .daysUntilExpiry)
        try container.encodeIfPresent(assignedUsers, forKey: .assignedUsers)
        try container.encodeIfPresent(discountCode, forKey: .discountCode)
        try container.encodeIfPresent(offerSpecifics, forKey: .offerSpecifics)
    }

    var fullProductImageURL: URL? {
        guard let path = productImage else { return nil }
        if path.starts(with: "http://") || path.starts(with: "https://") {
            return URL(string: path)
        }
        return URL(string: AppConfig.apiBaseURL + path)
    }

    // This relies on the Affiliate struct having a 'logo' String? property
    // and that logo path being relative or absolute.
    var fullAffiliateLogoURL: URL? {
        guard let logoPath = affiliate.logo else { return nil }
        if logoPath.starts(with: "http://") || logoPath.starts(with: "https://") {
            return URL(string: logoPath)
        }
        return URL(string: AppConfig.apiBaseURL + logoPath)
    }
    
    /// Returns a user-friendly expiry status message
    var expiryStatusMessage: String {
        if !isCurrentlyActive {
            return "Expired"
        } else if daysUntilExpiry == 0 {
            return "Expires today"
        } else if daysUntilExpiry == 1 {
            return "Expires tomorrow"
        } else if daysUntilExpiry <= 7 {
            return "Expires in \(daysUntilExpiry) days"
        } else {
            return "Valid until \(DateFormatter.mediumDate.string(from: endDate))"
        }
    }
}

// MARK: - DateFormatter Extension
extension DateFormatter {
    static let mediumDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()
}


