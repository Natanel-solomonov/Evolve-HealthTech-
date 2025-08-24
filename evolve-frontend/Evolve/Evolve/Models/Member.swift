import Foundation

// AppUserSimple should be defined in its own file: Models/SimpleAppUser.swift
// struct AppUserSimple: Codable, Hashable {
//     let name: String
//     let phone: String
// }

struct Member: Codable, Identifiable, Hashable {
    let id: Int
    let friendGroup: Int // Represents the ID of the friend circle
    let user: SimpleAppUser
    let dateJoined: Date
    let isAdmin: Bool

    enum CodingKeys: String, CodingKey {
        case id
        case friendGroup = "friend_group"
        case user
        case dateJoined = "date_joined"
        case isAdmin
    }

    // Implement Hashable
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    // Implement Equatable based on id for Identifiable conformance
    static func == (lhs: Member, rhs: Member) -> Bool {
        lhs.id == rhs.id
    }
}

// Input structs for creating/updating members can remain if used elsewhere,
// but are not part of the core Member model for reading data.
struct CreateMemberInput: Codable {
    let friendGroupId: Int
    let userId: Int
    let isAdmin: Bool

    enum CodingKeys: String, CodingKey {
        case friendGroupId = "friend_group_id"
        case userId = "user_id"
        case isAdmin
    }
}

struct UpdateMemberInput: Codable {
    let isAdmin: Bool
    
    enum CodingKeys: String, CodingKey {
        case isAdmin
    }
} 
