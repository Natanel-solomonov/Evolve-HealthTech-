import SwiftUI

/**
 * InviteMembersView: Allows admins to invite new members to an existing friend circle
 * 
 * Features:
 * - Phone number input and validation
 * - Multiple member invitation support
 * - Real-time invitation sending
 * - Error handling and success feedback
 */
struct InviteMembersView: View {
    @EnvironmentObject var authManager: AuthenticationManager
    @Environment(\.theme) private var theme: any Theme
    @Environment(\.dismiss) private var dismiss
    
    let friendCircle: FriendGroup
    let onDismiss: () -> Void
    let onMembersInvited: () -> Void
    
    @State private var phoneNumber = ""
    @State private var inviteePhones: [String] = []
    @State private var isInviting = false
    @State private var errorMessage: String? = nil
    @State private var successMessage: String? = nil
    
    var body: some View {
        NavigationView {
            ZStack {
                theme.background
                    .ignoresSafeArea()
                
                VStack(alignment: .leading, spacing: 24) {
                    // Header
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Invite Members")
                            .font(.system(size: 32, weight: .bold))
                            .foregroundColor(theme.primaryText)
                        
                        Text("Add friends to \(friendCircle.name)")
                            .font(.body)
                            .foregroundColor(theme.secondaryText)
                    }
                    
                    // Phone number input
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Phone Number")
                            .font(.headline)
                            .foregroundColor(theme.primaryText)
                        
                        HStack {
                            TextField("Enter phone number (e.g., +1234567890)", text: $phoneNumber)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .keyboardType(.phonePad)
                                .submitLabel(.done)
                                .onSubmit {
                                    addPhoneNumber()
                                }
                            
                            Button(action: addPhoneNumber) {
                                Image(systemName: "plus.circle.fill")
                                    .font(.title2)
                                    .foregroundColor(theme.accent)
                            }
                            .disabled(phoneNumber.isEmpty)
                        }
                    }
                    
                    // Added phone numbers
                    if !inviteePhones.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Members to Invite (\(inviteePhones.count))")
                                .font(.headline)
                                .foregroundColor(theme.primaryText)
                            
                            ForEach(inviteePhones, id: \.self) { phone in
                                HStack {
                                    Text(phone)
                                        .foregroundColor(theme.primaryText)
                                    
                                    Spacer()
                                    
                                    Button(action: {
                                        inviteePhones.removeAll { $0 == phone }
                                    }) {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundColor(theme.secondaryText)
                                    }
                                }
                                .padding(.vertical, 8)
                                .padding(.horizontal, 12)
                                .background(Color.gray.opacity(0.1))
                                .cornerRadius(8)
                            }
                        }
                    }
                    
                    // Success message
                    if let successMessage = successMessage {
                        Text(successMessage)
                            .font(.subheadline)
                            .foregroundColor(.green)
                            .padding()
                            .background(Color.green.opacity(0.1))
                            .cornerRadius(8)
                    }
                    
                    Spacer()
                    
                    // Action buttons
                    VStack(spacing: 12) {
                        Button(action: sendInvitations) {
                            if isInviting {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(theme.accent)
                                    .cornerRadius(12)
                            } else {
                                Text("Send Invitations")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(inviteePhones.isEmpty ? theme.accent.opacity(0.5) : theme.accent)
                                    .cornerRadius(12)
                            }
                        }
                        .disabled(inviteePhones.isEmpty || isInviting)
                        
                        Button(action: onDismiss) {
                            Text("Cancel")
                                .font(.headline)
                                .foregroundColor(theme.secondaryText)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.gray.opacity(0.2))
                                .cornerRadius(12)
                        }
                        .disabled(isInviting)
                    }
                }
                .padding()
            }
            .navigationBarHidden(true)
            .alert("Error", isPresented: .constant(errorMessage != nil)) {
                Button("OK") {
                    errorMessage = nil
                }
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func addPhoneNumber() {
        let trimmedPhone = phoneNumber.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Basic validation
        if !trimmedPhone.isEmpty && !inviteePhones.contains(trimmedPhone) {
            // Ensure phone number starts with +
            let formattedPhone = trimmedPhone.hasPrefix("+") ? trimmedPhone : "+\(trimmedPhone)"
            inviteePhones.append(formattedPhone)
            phoneNumber = ""
        }
    }
    
    private func sendInvitations() {
        Task {
            await performInvitations()
        }
    }
    
    @MainActor
    private func performInvitations() async {
        isInviting = true
        errorMessage = nil
        successMessage = nil
        
        do {
            guard let token = authManager.authToken else {
                throw NSError(domain: "Auth", code: 401, userInfo: [NSLocalizedDescriptionKey: "Not authenticated"])
            }
            
            var successCount = 0
            var errors: [String] = []
            
            // Send individual invitations for each phone number
            for phone in inviteePhones {
                do {
                    guard let url = URL(string: "\(AppConfig.apiBaseURL)/friend-circle-invitations/") else {
                        throw NSError(domain: "URL", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])
                    }
                    
                    let requestBody: [String: Any] = [
                        "friend_group_id": friendCircle.id,
                        "invitee_phone": phone
                    ]
                    
                    var request = URLRequest(url: url)
                    request.httpMethod = "POST"
                    request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
                    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
                    
                    let (_, response) = try await URLSession.shared.data(for: request)
                    
                    guard let httpResponse = response as? HTTPURLResponse else {
                        throw NSError(domain: "Network", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid response"])
                    }
                    
                    if httpResponse.statusCode == 201 {
                        successCount += 1
                    } else {
                        errors.append("Failed to invite \(phone)")
                    }
                } catch {
                    errors.append("Error inviting \(phone): \(error.localizedDescription)")
                }
            }
            
            // Show results
            if successCount > 0 {
                successMessage = "Successfully sent \(successCount) invitation\(successCount == 1 ? "" : "s")!"
                onMembersInvited() // Refresh the parent view
                
                // Clear the invited phones after success
                inviteePhones.removeAll()
                
                // Auto-dismiss after a delay if all invitations were successful
                if errors.isEmpty {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        onDismiss()
                    }
                }
            }
            
            if !errors.isEmpty {
                errorMessage = errors.joined(separator: "\n")
            }
            
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isInviting = false
    }
}