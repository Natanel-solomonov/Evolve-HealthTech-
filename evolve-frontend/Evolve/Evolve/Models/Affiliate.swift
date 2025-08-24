import Foundation

struct Affiliate: Codable, Identifiable, Hashable {
    let id: UUID
    let name: String
    let contactEmail: String?
    let contactPhone: String?
    let logo: String? // Path or full URL depending on backend serialization of ImageField
    let website: String?
    let location: String?
    var isActive: Bool?   // Made optional and var
    
    enum CodingKeys: String, CodingKey {
        case id, name, logo, website, location // direct match or already camelCase
        case contactEmail = "contact_email"
        case contactPhone = "contact_phone"
        case isActive = "is_active"
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        contactEmail = try container.decodeIfPresent(String.self, forKey: .contactEmail)
        contactPhone = try container.decodeIfPresent(String.self, forKey: .contactPhone)
        logo = try container.decodeIfPresent(String.self, forKey: .logo)
        website = try container.decodeIfPresent(String.self, forKey: .website)
        location = try container.decodeIfPresent(String.self, forKey: .location)
        
        do {
            isActive = try container.decodeIfPresent(Bool.self, forKey: .isActive)
        } catch DecodingError.keyNotFound(let key, _) where key.stringValue == CodingKeys.isActive.rawValue {
            print("Affiliate Custom Decoder: 'is_active' key not found by direct decode. Setting to nil.")
            isActive = nil // Or set a default like false if appropriate
        } catch {
            print("Affiliate Custom Decoder: Error decoding 'is_active': \\(error). Setting to nil.")
            isActive = nil
        }
    }
    
    // Custom initializer for previews or manual creation if needed (ensure all properties are covered)
    // This is a basic example; you might need to adjust if you use it for previews with specific data.
    init(id: UUID, name: String, contactEmail: String?, contactPhone: String?, logo: String?, website: String?, location: String?, isActive: Bool?) {
        self.id = id
        self.name = name
        self.contactEmail = contactEmail
        self.contactPhone = contactPhone
        self.logo = logo
        self.website = website
        self.location = location
        self.isActive = isActive
    }

    // Computed property for the full logo URL
    // This assumes 'logo' field from JSON is a relative path.
    // If backend sends full URL for ImageField, this might need adjustment or AppConfig.apiBaseURL might be different for media.
    var fullLogoURL: URL? {
        guard let logoPath = logo else { return nil }
        // Assuming AffiliateAPI.mediaBaseURLString is accessible and correct for constructing this URL.
        // If logoPath is already a full URL, this concatenation might be wrong.
        if logoPath.starts(with: "http://") || logoPath.starts(with: "https://") {
            return URL(string: logoPath)
        }
        let base = AppConfig.apiBaseURL.replacingOccurrences(of: "/api", with: "") // Ensure no trailing /api
        return URL(string: base + logoPath)
    }
} 