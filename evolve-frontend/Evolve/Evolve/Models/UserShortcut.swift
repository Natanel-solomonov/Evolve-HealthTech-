import Foundation

struct UserShortcut: Codable, Identifiable, Hashable {
    let id: UUID
    let shortcut: Shortcut
    let order: Int
} 