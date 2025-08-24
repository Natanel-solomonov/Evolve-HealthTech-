import Foundation

struct ContentCardModel: Codable, Identifiable {
    let id: Int 
    let text: String
    let boldedWords: [String]? // Backend JSONField(default=list, null=True)

    // Conform to snake_case decoding
    enum CodingKeys: String, CodingKey {
        case id
        case text
        case boldedWords = "bolded_words"
    }
} 
