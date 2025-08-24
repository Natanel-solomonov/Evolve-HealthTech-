import Foundation
import Combine
// Combine is not strictly needed if not using ObservableObject for Combine-based publishing directly in API methods.

// Assuming Codable structs are defined elsewhere:
// struct FriendGroup: Codable, Identifiable { /* ... */ }
// struct Member: Codable, Identifiable { /* ... */ }
// struct CreateMemberInput: Codable { /* ... e.g., let friendGroupId: Int, let userId: Int, let isAdmin: Bool */ }
// struct UpdateMemberInput: Codable { /* ... e.g., let isAdmin: Bool */ }
// struct FriendGroupEvent: Codable, Identifiable { /* ... */ }

// NetworkError is expected from AuthenticationManager.swift

class FriendGroupAPI: ObservableObject {
    private let httpClient: AuthenticatedHTTPClient

    init(httpClient: AuthenticatedHTTPClient) {
        self.httpClient = httpClient
    }

    func fetchFriendGroups() async throws -> [FriendGroup] {
        try await httpClient.request(endpoint: "/friend-groups/", method: "GET", requiresAuth: true)
    }

    func fetchFriendGroupDetail(id: Int) async throws -> FriendGroup {
        try await httpClient.request(endpoint: "/friend-groups/\(id)/", method: "GET", requiresAuth: true)
    }

    // Assuming CreateFriendGroupRequest struct exists if more fields than just name are needed.
    // For just name, a dictionary can be encoded if the httpClient.request supports it, or a simple struct.
    struct CreateGroupBody: Codable { let name: String }
    func createFriendGroup(name: String) async throws -> FriendGroup {
        let body = CreateGroupBody(name: name)
        return try await httpClient.request(endpoint: "/friend-groups/", method: "POST", body: body, requiresAuth: true)
    }

    func deleteFriendGroup(id: Int) async throws {
        let (_, httpResponse) = try await httpClient.requestData(endpoint: "/friend-groups/\(id)/", method: "DELETE", requiresAuth: true)
        guard (200...299).contains(httpResponse.statusCode) else { // Expect 204
            throw NetworkError.serverError(statusCode: httpResponse.statusCode, data: nil) // Or more specific error
        }
        // Success (204 No Content)
    }

    func addMember(input: CreateMemberInput) async throws -> Member {
        // Endpoint for MemberListView POST is /members/
        return try await httpClient.request(endpoint: "/members/", method: "POST", body: input, requiresAuth: true)
    }

    func updateMember(memberId: Int, input: UpdateMemberInput) async throws -> Member {
        // Endpoint for MemberDetailView PATCH/PUT is /members/\(memberId)/
        return try await httpClient.request(endpoint: "/members/\(memberId)/", method: "PATCH", body: input, requiresAuth: true)
    }

    func removeMember(memberId: Int) async throws {
        let (_, httpResponse) = try await httpClient.requestData(endpoint: "/members/\(memberId)/", method: "DELETE", requiresAuth: true)
        guard (200...299).contains(httpResponse.statusCode) else { // Expect 204
            throw NetworkError.serverError(statusCode: httpResponse.statusCode, data: nil)
        }
        // Success (204 No Content)
    }

    func leaveGroup(groupId: Int, currentUserPhone: String) async throws {
        // First, fetch the friend group to find the current user's membership
        let friendGroup = try await fetchFriendGroupDetail(id: groupId)
        
        // Find the current user's membership in this friend group
        guard let currentMembership = friendGroup.members.first(where: { member in
            member.user.phone == currentUserPhone
        }) else {
            throw NetworkError.custom(message: "User is not a member of this friend group")
        }
        
        // Use the existing removeMember method to delete the membership
        try await removeMember(memberId: currentMembership.id)
    }
    
    func fetchFriendGroupEvents(groupId: Int) async throws -> [FriendGroupEvent] {
        // Endpoint for FriendGroupEventListView GET is /friend-groups/\(groupId)/events/
        try await httpClient.request(endpoint: "/friend-groups/\(groupId)/events/", method: "GET", requiresAuth: true)
    }

    func transferAdmin(groupId: Int, newAdminMemberId: Int, currentUserPhone: String) async throws {
        print("FriendGroupAPI: Starting transferAdmin - groupId: \(groupId), newAdminMemberId: \(newAdminMemberId), currentUserPhone: \(currentUserPhone)")
        
        // First, fetch the friend group to find the current admin's membership
        let friendGroup = try await fetchFriendGroupDetail(id: groupId)
        print("FriendGroupAPI: Fetched friend group with \(friendGroup.members.count) members")
        
        // Find the current user's membership (should be admin)
        guard let currentMembership = friendGroup.members.first(where: { member in
            member.user.phone == currentUserPhone && member.isAdmin
        }) else {
            print("FriendGroupAPI: ERROR - Current user is not an admin. Phone: \(currentUserPhone)")
            print("FriendGroupAPI: Available members:")
            for member in friendGroup.members {
                print("  - \(member.user.firstName) \(member.user.lastName) (phone: \(member.user.phone), isAdmin: \(member.isAdmin), id: \(member.id))")
            }
            throw NetworkError.custom(message: "Current user is not an admin of this friend group")
        }
        
        print("FriendGroupAPI: Found current admin membership - ID: \(currentMembership.id)")
        
        // Verify the target member exists and is not already admin
        guard friendGroup.members.contains(where: { member in
            member.id == newAdminMemberId && !member.isAdmin
        }) else {
            print("FriendGroupAPI: ERROR - Target member not found or is already admin. Target ID: \(newAdminMemberId)")
            print("FriendGroupAPI: Available non-admin members:")
            for member in friendGroup.members.filter({ !$0.isAdmin }) {
                print("  - \(member.user.firstName) \(member.user.lastName) (id: \(member.id))")
            }
            throw NetworkError.custom(message: "Target member not found or is already an admin")
        }
        
        print("FriendGroupAPI: Target member validation passed")
        
        // Transfer admin privileges:
        // 1. Make the target member an admin
        print("FriendGroupAPI: Making member \(newAdminMemberId) an admin...")
        let makeAdminInput = UpdateMemberInput(isAdmin: true)
        _ = try await updateMember(memberId: newAdminMemberId, input: makeAdminInput)
        print("FriendGroupAPI: Successfully promoted member \(newAdminMemberId) to admin")
        
        // 2. Remove admin privileges from current user
        print("FriendGroupAPI: Removing admin privileges from current user (member \(currentMembership.id))...")
        let removeAdminInput = UpdateMemberInput(isAdmin: false) 
        _ = try await updateMember(memberId: currentMembership.id, input: removeAdminInput)
        print("FriendGroupAPI: Successfully removed admin privileges from current user")
        
        print("FriendGroupAPI: Admin transfer completed successfully")
    }
    
    struct ChangeCoverImageBody: Codable { 
        let coverImage: String 
        
        enum CodingKeys: String, CodingKey {
            case coverImage = "cover_image"
        }
    }
    
    struct RenameGroupBody: Codable {
        let name: String
    }
    
    func renameGroup(groupId: Int, newName: String, currentUserPhone: String) async throws {
        print("FriendGroupAPI: Starting renameGroup - groupId: \(groupId), newName: \(newName), currentUserPhone: \(currentUserPhone)")
        
        // First, fetch the friend group to verify the current user is an admin
        let friendGroup = try await fetchFriendGroupDetail(id: groupId)
        print("FriendGroupAPI: Fetched friend group with \(friendGroup.members.count) members")
        
        // Find the current user's membership (should be admin)
        guard let currentMembership = friendGroup.members.first(where: { member in
            member.user.phone == currentUserPhone && member.isAdmin
        }) else {
            print("FriendGroupAPI: ERROR - Current user is not an admin. Phone: \(currentUserPhone)")
            print("FriendGroupAPI: Available members:")
            for member in friendGroup.members {
                print("  - \(member.user.firstName) \(member.user.lastName) (phone: \(member.user.phone), isAdmin: \(member.isAdmin), id: \(member.id))")
            }
            throw NetworkError.custom(message: "Current user is not an admin of this friend group")
        }
        
        print("FriendGroupAPI: Found current admin membership - ID: \(currentMembership.id)")
        
        // Update the group name
        print("FriendGroupAPI: Updating group name to \(newName)...")
        let body = RenameGroupBody(name: newName)
        let (_, httpResponse) = try await httpClient.requestData(
            endpoint: "/friend-groups/\(groupId)/", 
            method: "PATCH", 
            body: body,
            requiresAuth: true
        )
        
        guard (200...299).contains(httpResponse.statusCode) else {
            print("FriendGroupAPI: ERROR - Failed to update group name. Status code: \(httpResponse.statusCode)")
            throw NetworkError.serverError(statusCode: httpResponse.statusCode, data: nil)
        }
        
        print("FriendGroupAPI: Group name updated successfully")
    }
    
    func changeCoverImage(groupId: Int, newImageUrl: String, currentUserPhone: String) async throws {
        print("FriendGroupAPI: Starting changeCoverImage - groupId: \(groupId), newImageUrl: \(newImageUrl), currentUserPhone: \(currentUserPhone)")
        
        // First, fetch the friend group to verify the current user is an admin
        let friendGroup = try await fetchFriendGroupDetail(id: groupId)
        print("FriendGroupAPI: Fetched friend group with \(friendGroup.members.count) members")
        
        // Find the current user's membership (should be admin)
        guard let currentMembership = friendGroup.members.first(where: { member in
            member.user.phone == currentUserPhone && member.isAdmin
        }) else {
            print("FriendGroupAPI: ERROR - Current user is not an admin. Phone: \(currentUserPhone)")
            print("FriendGroupAPI: Available members:")
            for member in friendGroup.members {
                print("  - \(member.user.firstName) \(member.user.lastName) (phone: \(member.user.phone), isAdmin: \(member.isAdmin), id: \(member.id))")
            }
            throw NetworkError.custom(message: "Current user is not an admin of this friend group")
        }
        
        print("FriendGroupAPI: Found current admin membership - ID: \(currentMembership.id)")
        
        // Update the cover image
        print("FriendGroupAPI: Updating cover image to \(newImageUrl)...")
        let body = ChangeCoverImageBody(coverImage: newImageUrl)
        let (_, httpResponse) = try await httpClient.requestData(
            endpoint: "/friend-groups/\(groupId)/", 
            method: "PATCH", 
            body: body,
            requiresAuth: true
        )
        
        guard (200...299).contains(httpResponse.statusCode) else {
            print("FriendGroupAPI: ERROR - Failed to update cover image. Status code: \(httpResponse.statusCode)")
            throw NetworkError.serverError(statusCode: httpResponse.statusCode, data: nil)
        }
        
        print("FriendGroupAPI: Cover image updated successfully")
    }
}
