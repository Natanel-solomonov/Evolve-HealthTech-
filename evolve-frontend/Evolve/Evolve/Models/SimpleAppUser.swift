import Foundation

// struct AppUserSimple: Codable, Hashable {
//     let name: String
//     let phone: String
// }

struct SimpleAppUser: Codable, Identifiable, Equatable, Hashable {
    let id: String
    let firstName: String
    let lastName: String
    let phone: String

    // Conform to Identifiable using phone, assuming phone is unique for this context.
    // The backend AppUserSimpleSerializer now provides 'id', 'first_name', 'last_name', and 'phone'.
//    var id: String { phone }
    
    enum CodingKeys: String, CodingKey {
        case id
        case firstName = "first_name"
        case lastName = "last_name"
        case phone
    }
} 
