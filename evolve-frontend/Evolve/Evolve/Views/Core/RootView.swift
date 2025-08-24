import SwiftUI

// RoundedCorner struct should be accessible here, or defined globally if used in multiple files.
// For now, assuming it will be copied or made available globally.
// If not, we need to define it in this file or ensure LandingView (if it still contains it) is imported and struct is public.
// For this edit, I will assume RoundedCorner is available.

struct RootView: View {
    @EnvironmentObject var authManager: AuthenticationManager // Receive from environment
    @State private var landingAppeared: Bool = false
    let testing: Bool // Receive the testing flag
    

    var body: some View {
        Group {
            if authManager.currentUser == nil {
                if testing {
                    LoginView()
                        .onAppear { print("Showing Testing LoginView") }
                } else {
                    LandingView()
                        .onAppear { print("Showing LandingView (unauthenticated)"); landingAppeared = true }
                }
            } else if testing {
                // Skip onboarding for testing - go directly to main app
                MainNavigationView()
                    .onAppear {
                        print("Testing mode: Skipping onboarding, showing MainNavigationView")
                        landingAppeared = false
                    }
            } else {
                // NEW BEHAVIOR: Always show MainNavigationView for authenticated users
                // The Dashboard will show resume onboarding UI if not completed
                MainNavigationView()
                    .onAppear {
                        print("Showing MainNavigationView, authenticated as: \(authManager.currentUser?.displayName ?? "Unknown")")
                        landingAppeared = false
                    }
            }
        }
        .liquidGlassTheme()
    }
}

struct RootView_Previews: PreviewProvider {
    static var previews: some View {
        // Provide a value for testing in the preview
        RootView(testing: true)
            .environmentObject(AuthenticationManager()) // Provide a mock authManager
    }
} 
