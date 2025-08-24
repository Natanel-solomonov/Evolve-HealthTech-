import SwiftUI

struct LoginView: View {
    @EnvironmentObject var authManager: AuthenticationManager
    @State private var isLoading: Bool = false // State to track loading for authentication
    @Environment(\.theme) private var theme: any Theme
    
    var body: some View {
        NavigationView {
            Group {
                if authManager.users.isEmpty {
                    // Show progress view only if users haven't loaded initially
                    // We handle loading for authentication separately
                    if !isLoading {
                        ProgressView("Loading users...")
                            .font(.system(size: 15))
                    } else {
                        // Show a progress view while authenticating
                        ProgressView("Authenticating...")
                            .font(.system(size: 15))
                    }
                } else {
                    List(authManager.users) { user in // Iterates over [SimpleAppUser]
                        Button(action: {
                            // Trigger the new async function
                            isLoading = true // Show loading indicator
                            Task {
                                await authManager.fetchAndAuthenticateUser(phone: user.phone, firstName: user.firstName, lastName: user.lastName)
                                // isLoading will be set to false if there's an error within fetchAndAuthenticateUser,
                                // or the view will change upon successful auth, effectively stopping the indicator.
                                // For robustness, you might want fetchAndAuthenticateUser to return a success/failure
                                // and explicitly set isLoading = false here on any outcome if it doesn't navigate away.
                                // However, given the print statements in fetchAndAuthenticateUser for errors,
                                // and that successful login changes the view state, this should be okay for a test view.
                                if authManager.currentUser == nil { // If auth failed and didn't navigate
                                    isLoading = false
                                }
                            }
                        }) {
                            HStack {
                                Text("\(user.firstName) \(user.lastName)") // Access SimpleAppUser property
                                    .font(.system(size: 17))
                                Spacer()
                                Text(user.phone) // Access SimpleAppUser property
                                    .foregroundColor(theme.secondaryText)
                                    .font(.system(size: 15))
                            }
                            .padding(.vertical, 4)
                        }
                        .disabled(isLoading) // Disable button while authenticating
                    }
                }
            }
            .navigationTitle("Test Harness")
            // Show overlay progress view when authenticating
            .overlay {
                 if isLoading && !authManager.users.isEmpty { // Show only during auth, not initial load
                     ProgressView("Authenticating...")
                         .padding()
                         .background(theme.background.opacity(0.1))
                         .cornerRadius(8)
                         .font(.system(size: 15))
                 }
            }
        }
        .task {
            // Initial fetch of simple user list
            if authManager.users.isEmpty {
                 await authManager.fetchSimpleUsers()
            }
        }
    }
}

struct LoginView_Previews: PreviewProvider {
    static var previews: some View {
        LoginView().environmentObject(AuthenticationManager())
    }
}
