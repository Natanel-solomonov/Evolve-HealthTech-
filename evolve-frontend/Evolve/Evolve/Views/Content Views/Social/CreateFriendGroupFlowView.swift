import SwiftUI

/**
 * CreateFriendGroupFlowView: Multi-step flow for creating a friend group
 * 
 * Steps:
 * 1. Name and cover image selection
 * 2. Add members by phone number
 * 3. Review and create
 */
struct CreateFriendGroupFlowView: View {
    @EnvironmentObject var authManager: AuthenticationManager
    @Environment(\.theme) private var theme: any Theme
    @Environment(\.dismiss) private var dismiss
    
    // Callback
    let onDismiss: () -> Void
    
    // Flow state
    @State private var currentStep = 1
    @State private var isCreating = false
    @State private var errorMessage: String? = nil
    
    // Step 1: Basic info
    @State private var circleName = ""
    @State private var selectedCoverImage = "friendgroupimage0"
    
    // Step 2: Members
    @State private var phoneNumber = ""
    @State private var inviteePhones: [String] = []
    
    // Available cover images
    private let coverImages = [
        "friendgroupimage0", "friendgroupimage1", "friendgroupimage2",
        "friendgroupimage3", "friendgroupimage4", "friendgroupimage5"
    ]
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background
                theme.background
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Progress indicator
                    progressBar
                        .padding(.horizontal)
                        .padding(.top, 10)
                    
                    // Content based on current step
                    Group {
                        switch currentStep {
                        case 1:
                            basicInfoStep
                        case 2:
                            addMembersStep
                        case 3:
                            reviewStep
                        default:
                            EmptyView()
                        }
                    }
                    .padding()
                    
                    Spacer()
                    
                    // Navigation buttons
                    navigationButtons
                        .padding()
                }
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
    
    // MARK: - Progress Bar
    
    private var progressBar: some View {
        HStack(spacing: 8) {
            ForEach(1...3, id: \.self) { step in
                Capsule()
                    .fill(step <= currentStep ? theme.accent : theme.secondaryText.opacity(0.3))
                    .frame(height: 4)
            }
        }
    }
    
    // MARK: - Step 1: Basic Info
    
    private var basicInfoStep: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Create Friend Group")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(theme.primaryText)
                
                Text("Choose a name and cover image")
                    .font(.body)
                    .foregroundColor(theme.secondaryText)
            }
            
            // Name input
            VStack(alignment: .leading, spacing: 8) {
                Text("Circle Name")
                    .font(.headline)
                    .foregroundColor(theme.primaryText)
                
                TextField("Enter circle name", text: $circleName)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .submitLabel(.done)
            }
            
            // Cover image selection
            VStack(alignment: .leading, spacing: 12) {
                Text("Cover Image")
                    .font(.headline)
                    .foregroundColor(theme.primaryText)
                
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 80))], spacing: 12) {
                    ForEach(coverImages, id: \.self) { imageName in
                        Button(action: {
                            selectedCoverImage = imageName
                        }) {
                            Image(imageName)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 80, height: 80)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(
                                            selectedCoverImage == imageName ? theme.accent : Color.clear,
                                            lineWidth: 3
                                        )
                                )
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Step 2: Add Members
    
    private var addMembersStep: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Add Members")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(theme.primaryText)
                
                Text("Enter phone numbers to invite friends")
                    .font(.body)
                    .foregroundColor(theme.secondaryText)
            }
            
            // Phone number input
            HStack {
                TextField("Phone number (e.g., +1234567890)", text: $phoneNumber)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .keyboardType(.phonePad)
                    .submitLabel(.done)
                
                Button(action: addPhoneNumber) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundColor(theme.accent)
                }
                .disabled(phoneNumber.isEmpty)
            }
            
            // Added phone numbers
            if !inviteePhones.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Invited Members")
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
        }
    }
    
    // MARK: - Step 3: Review
    
    private var reviewStep: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Review & Create")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(theme.primaryText)
                
                Text("Review your friend group details")
                    .font(.body)
                    .foregroundColor(theme.secondaryText)
            }
            
            // Circle preview
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 16) {
                    Image(selectedCoverImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 80, height: 80)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(circleName)
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(theme.primaryText)
                        
                        Text("\(inviteePhones.count + 1) members")
                            .font(.subheadline)
                            .foregroundColor(theme.secondaryText)
                    }
                    
                    Spacer()
                }
                
                if !inviteePhones.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Members to invite:")
                            .font(.headline)
                            .foregroundColor(theme.primaryText)
                        
                        ForEach(inviteePhones, id: \.self) { phone in
                            Text(phone)
                                .foregroundColor(theme.secondaryText)
                        }
                    }
                }
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(12)
        }
    }
    
    // MARK: - Navigation Buttons
    
    private var navigationButtons: some View {
        HStack {
            // Back/Cancel button
            Button(action: {
                if currentStep > 1 {
                    currentStep -= 1
                } else {
                    onDismiss()
                }
            }) {
                Text(currentStep > 1 ? "Back" : "Cancel")
                    .font(.headline)
                    .foregroundColor(theme.secondaryText)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(12)
            }
            
            // Next/Create button
            Button(action: nextAction) {
                if isCreating {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(theme.accent)
                        .cornerRadius(12)
                } else {
                    Text(currentStep == 3 ? "Create" : "Next")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(nextButtonDisabled ? theme.accent.opacity(0.5) : theme.accent)
                        .cornerRadius(12)
                }
            }
            .disabled(nextButtonDisabled || isCreating)
        }
    }
    
    // MARK: - Helper Methods
    
    private var nextButtonDisabled: Bool {
        switch currentStep {
        case 1:
            return circleName.isEmpty
        case 2:
            return false // Can proceed without adding members
        case 3:
            return false
        default:
            return true
        }
    }
    
    private func nextAction() {
        if currentStep < 3 {
            currentStep += 1
        } else {
            createFriendGroup()
        }
    }
    
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
    
    private func createFriendGroup() {
        Task {
            await performCreation()
        }
    }
    
    @MainActor
    private func performCreation() async {
        isCreating = true
        errorMessage = nil
        
        do {
            guard let token = authManager.authToken else {
                throw NSError(domain: "Auth", code: 401, userInfo: [NSLocalizedDescriptionKey: "Not authenticated"])
            }
            
            // Prepare request body
            let requestBody: [String: Any] = [
                "name": circleName,
                "cover_image": selectedCoverImage,
                "invitee_phones": inviteePhones
            ]
            
            // Create the friend group with invitations
            guard let url = URL(string: "\(AppConfig.apiBaseURL)/friend-groups/create-with-invitations/") else {
                throw NSError(domain: "URL", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])
            }
            
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw NSError(domain: "Network", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid response"])
            }
            
            if httpResponse.statusCode == 201 {
                // Success
                onDismiss()
            } else {
                // Try to parse error message
                if let errorData = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let error = errorData["error"] as? String {
                    throw NSError(domain: "API", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: error])
                } else {
                    throw NSError(domain: "API", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "Failed to create friend group"])
                }
            }
            
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isCreating = false
    }
} 