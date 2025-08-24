import Foundation

struct AppUserInfo: Codable, Identifiable, Hashable {
    var id: String { user }
    
    let user: String
    let height: Double
    let birthday: String
    let weight: Double
    let sex: String
} 
