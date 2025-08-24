import Foundation

// MARK: - Goal Model
struct Goal: Identifiable, Hashable {
    let id: UUID
    let emoji: String
    let title: String
    
    /// Central source of truth for all selectable goals
    static let all: [Goal] = [
        Goal(id: UUID(uuidString: "63CBB01B-7B7C-4E43-99E5-AB0E39A7A001")!, emoji: "🏃‍♂️", title: "Lose weight"),
        Goal(id: UUID(uuidString: "63CBB01B-7B7C-4E43-99E5-AB0E39A7A002")!, emoji: "💪", title: "Build muscle"),
        Goal(id: UUID(uuidString: "63CBB01B-7B7C-4E43-99E5-AB0E39A7A003")!, emoji: "🤸‍♀️", title: "Get more flexible"),
        Goal(id: UUID(uuidString: "63CBB01B-7B7C-4E43-99E5-AB0E39A7A004")!, emoji: "🏋️‍♀️", title: "Get stronger"),
        Goal(id: UUID(uuidString: "63CBB01B-7B7C-4E43-99E5-AB0E39A7A005")!, emoji: "🥗", title: "Eat healthier"),
        Goal(id: UUID(uuidString: "63CBB01B-7B7C-4E43-99E5-AB0E39A7A006")!, emoji: "⚡️", title: "Regulate energy"),
        Goal(id: UUID(uuidString: "63CBB01B-7B7C-4E43-99E5-AB0E39A7A007")!, emoji: "😴", title: "Sleep better"),
        Goal(id: UUID(uuidString: "63CBB01B-7B7C-4E43-99E5-AB0E39A7A008")!, emoji: "🧘‍♂️", title: "Manage stress"),
        Goal(id: UUID(uuidString: "63CBB01B-7B7C-4E43-99E5-AB0E39A7A009")!, emoji: "💧", title: "Drink more water")
    ]
} 