import SwiftUI

/**
 * InvitationListView: Displays and manages pending friend circle invitations
 * 
 * Features:
 * - Shows list of pending invitations
 * - Accept/Decline functionality
 * - Real-time updates on response
 */
struct InvitationListView: View {
    @EnvironmentObject var authManager: AuthenticationManager
    @Environment(\.theme) private var theme: any Theme
    @Environment(\.dismiss) private var dismiss
    
    let invitations: [FriendGroupInvitation]
    let onInvitationResponded: () -> Void
    
    @State private var processingInvitations: Set<String> = []
    @State private var errorMessage: String? = nil
    
    var body: some View {
        NavigationView {
            ZStack {
                theme.background
                    .ignoresSafeArea()
                
                if invitations.isEmpty {
                    // Empty state
                    VStack(spacing: 16) {
                        Image(systemName: "person.2.slash")
                            .font(.system(size: 50))
                            .foregroundColor(theme.secondaryText)
                        
                        Text("No pending invitations")
                            .font(.headline)
                            .foregroundColor(theme.primaryText)
                        
                        Text("You're all caught up!")
                            .font(.subheadline)
                            .foregroundColor(theme.secondaryText)
                    }
                    .padding()
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(invitations) { invitation in
                                InvitationRowView(
                                    invitation: invitation,
                                    isProcessing: processingInvitations.contains(invitation.id),
                                    onAccept: { handleInvitation(invitation, accept: true) },
                                    onDecline: { handleInvitation(invitation, accept: false) }
                                )
                                .environmentObject(authManager)
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("Invitations")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(theme.accent)
                }
            }
            .alert("Error", isPresented: .constant(errorMessage != nil)) {
                Button("OK") {
                    errorMessage = nil
                }
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }
    
    private func handleInvitation(_ invitation: FriendGroupInvitation, accept: Bool) {
        Task {
            await respondToInvitation(invitation, accept: accept)
        }
    }
    
    @MainActor
    private func respondToInvitation(_ invitation: FriendGroupInvitation, accept: Bool) async {
        processingInvitations.insert(invitation.id)
        
        do {
            guard let token = authManager.authToken else {
                throw NSError(domain: "Auth", code: 401, userInfo: [NSLocalizedDescriptionKey: "Not authenticated"])
            }
            
            guard let url = URL(string: "\(AppConfig.apiBaseURL)/friend-circle-invitations/\(invitation.id)/") else {
                throw NSError(domain: "URL", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])
            }
            
            var request = URLRequest(url: url)
            request.httpMethod = "PATCH"
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            
            let body = ["action": accept ? "accept" : "decline"]
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            
            let (_, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw NSError(domain: "Network", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid response"])
            }
            
            if httpResponse.statusCode == 200 {
                // Success - notify parent to refresh
                onInvitationResponded()
            } else {
                throw NSError(domain: "API", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "Failed to respond to invitation"])
            }
            
        } catch {
            errorMessage = error.localizedDescription
        }
        
        processingInvitations.remove(invitation.id)
    }
}

/**
 * InvitationRowView: Individual invitation row with accept/decline actions
 */
struct InvitationRowView: View {
    @EnvironmentObject var authManager: AuthenticationManager
    @Environment(\.theme) private var theme: any Theme
    
    let invitation: FriendGroupInvitation
    let isProcessing: Bool
    let onAccept: () -> Void
    let onDecline: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Circle info
            HStack(spacing: 12) {
                if let coverImage = invitation.friendGroup.coverImage {
                    Image(coverImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 60, height: 60)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                } else {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 60, height: 60)
                        .overlay(
                            Image(systemName: "person.3.fill")
                                .foregroundColor(theme.secondaryText)
                        )
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(invitation.friendGroup.name)
                        .font(.headline)
                        .foregroundColor(theme.primaryText)
                    
                    Text("Invited by \(invitation.inviter.fullName)")
                        .font(.subheadline)
                        .foregroundColor(theme.secondaryText)
                    
                    Text(invitation.createdAt, style: .relative)
                        .font(.caption)
                        .foregroundColor(theme.secondaryText)
                }
                
                Spacer()
            }
            
            // Action buttons
            HStack(spacing: 12) {
                Button(action: onDecline) {
                    Text("Decline")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(theme.secondaryText)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color.gray.opacity(0.2))
                        .cornerRadius(8)
                }
                .disabled(isProcessing)
                
                Button(action: onAccept) {
                    if isProcessing {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(theme.accent)
                            .cornerRadius(8)
                    } else {
                        Text("Accept")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(theme.accent)
                            .cornerRadius(8)
                    }
                }
                .disabled(isProcessing)
            }
        }
        .padding()
        .background(theme.background)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
    }
} 