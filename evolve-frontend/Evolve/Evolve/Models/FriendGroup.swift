import Foundation

struct FriendGroup: Codable, Identifiable, Hashable {
    let id: Int
    let name: String
    let members: [Member]
    let coverImage: String?

    var events: [FriendGroupEvent]?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case members
        case coverImage = "cover_image"
    }

    init(id: Int, name: String, members: [Member], coverImage: String? = nil, events: [FriendGroupEvent]? = nil) {
        self.id = id
        self.name = name
        self.members = members
        self.coverImage = coverImage
        self.events = events
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: FriendGroup, rhs: FriendGroup) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Friend Group Invitation
/**
 * FriendGroupInvitation: Represents an invitation to join a friend group
 * 
 * Features:
 * - Tracks invitation status (pending, accepted, declined)
 * - Links to friend group and inviter
 * - Supports both existing and new users via phone number
 */
struct FriendGroupInvitation: Codable, Identifiable {
    let id: String
    let friendGroup: FriendGroup
    let inviter: SimpleUser
    let inviteePhone: String
    let inviteeUser: SimpleUser?
    let status: String
    let createdAt: Date
    let respondedAt: Date?
    
    private enum CodingKeys: String, CodingKey {
        case id
        case friendGroup = "friend_group"
        case inviter
        case inviteePhone = "invitee_phone"
        case inviteeUser = "invitee_user"
        case status
        case createdAt = "created_at"
        case respondedAt = "responded_at"
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        self.id = try container.decode(String.self, forKey: .id)
        self.friendGroup = try container.decode(FriendGroup.self, forKey: .friendGroup)
        self.inviter = try container.decode(SimpleUser.self, forKey: .inviter)
        self.inviteePhone = try container.decode(String.self, forKey: .inviteePhone)
        self.inviteeUser = try container.decodeIfPresent(SimpleUser.self, forKey: .inviteeUser)
        self.status = try container.decode(String.self, forKey: .status)
        
        let createdAtString = try container.decode(String.self, forKey: .createdAt)
        self.createdAt = ISO8601DateFormatter().date(from: createdAtString) ?? Date()
        
        if let respondedAtString = try container.decodeIfPresent(String.self, forKey: .respondedAt) {
            self.respondedAt = ISO8601DateFormatter().date(from: respondedAtString)
        } else {
            self.respondedAt = nil
        }
    }
    
    var isPending: Bool {
        return status == "PENDING"
    }
}

// Simple user struct for invitations
struct SimpleUser: Codable {
    let id: String
    let firstName: String
    let lastName: String
    let phone: String
    
    private enum CodingKeys: String, CodingKey {
        case id
        case firstName = "first_name"
        case lastName = "last_name"
        case phone
    }
    
    var fullName: String {
        "\(firstName) \(lastName)"
    }
} 