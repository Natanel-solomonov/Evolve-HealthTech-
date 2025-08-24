import Foundation

struct Exercise: Codable, Identifiable, Hashable {
    let id: UUID
    let name: String
    let force: String?
    let level: String
    let mechanic: String?
    let equipment: String // Backend default is 'None', can be blank.
    let isCardio: Bool    // Backend default False
    let primaryMuscles: [String] // Assumed JSON array of strings
    let secondaryMuscles: [String]? // Changed to optional
    let instructions: [String]   // Assumed JSON array of strings
    let category: String
    let picture1: String? // URL
    let picture2: String? // URL
    let isDiagnostic: Bool // Added, backend default False
    let cluster: String?   // Added, backend nullable

    enum CodingKeys: String, CodingKey {
        case id, name, force, level, mechanic, equipment, instructions, category, picture1, picture2, cluster
        case isCardio // Assuming JSON key is "isCardio"
        case primaryMuscles = "primary_muscles"
        case secondaryMuscles = "secondary_muscles"
        case isDiagnostic // Assuming JSON key is "isDiagnostic"
    }
} 
