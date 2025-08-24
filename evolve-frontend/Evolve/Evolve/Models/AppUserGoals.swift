    import Foundation

struct UserGoalDetail: Codable, Identifiable {
    let id: Int
    let goalCategories: [String]
    let text: String

    enum CodingKeys: String, CodingKey {
        case id
        case goalCategories = "goal_categories"
        case text
    }
}

struct AppUserGoals: Codable, Identifiable {
    let id: Int
    let user: String
    let goalsGeneral: [String]?
    let details: [UserGoalDetail]?
    
    enum CodingKeys: String, CodingKey {
        case id, user, details
        case goalsGeneral = "goals_general"
    }
}
