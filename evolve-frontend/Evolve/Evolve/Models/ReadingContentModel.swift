import Foundation

struct ReadingContentModel: Codable, Identifiable, Equatable, Hashable {
    let id: UUID
    let title: String
    let duration: String
    let description: String?
    let coverImage: String?
    let category: [String]
    var contentCards: [ContentCardModel]?

    // Conform to snake_case decoding
    enum CodingKeys: String, CodingKey {
        case id
        case title
        case duration
        case description
        case coverImage = "cover_image"
        case category
        case contentCards = "content_cards"
    }
    
    // Custom decoder to handle potential issues with content_cards
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        id = try container.decode(UUID.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        duration = try container.decode(String.self, forKey: .duration)
        description = try container.decodeIfPresent(String.self, forKey: .description)
        coverImage = try container.decodeIfPresent(String.self, forKey: .coverImage)
        category = try container.decode([String].self, forKey: .category)
        
        // Attempt to decode contentCards, with fallback
        do {
            contentCards = try container.decodeIfPresent([ContentCardModel].self, forKey: .contentCards)
        } catch DecodingError.keyNotFound(let key, _) where key.stringValue == CodingKeys.contentCards.rawValue {
            print("ReadingContentModel Custom Decoder: 'content_cards' key not found by direct decode. Setting to nil.")
            contentCards = nil 
        } catch {
            print("ReadingContentModel Custom Decoder: Error decoding 'content_cards': \\(error). Setting to nil.")
            contentCards = nil
        }
    }
    
    // Conformance to Equatable (based on ID)
    static func == (lhs: ReadingContentModel, rhs: ReadingContentModel) -> Bool {
        return lhs.id == rhs.id
    }
    
    // Conformance to Hashable (based on ID)
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
} 
