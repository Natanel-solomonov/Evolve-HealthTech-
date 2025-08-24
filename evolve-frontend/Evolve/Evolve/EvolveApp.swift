import SwiftUI

@main
struct EvolveApp: App {
    
    @StateObject private var authManager = AuthenticationManager()
    @StateObject private var contentViewModel: ContentViewModel
    let testing = false // Ensure testing is disabled
    
    init() {
        // Create a single AuthenticationManager instance
        let authManager = AuthenticationManager()
        _authManager = StateObject(wrappedValue: authManager)
        _contentViewModel = StateObject(wrappedValue: ContentViewModel(authenticationManager: authManager))
    }

    var body: some Scene {
        WindowGroup {
           RootView(testing: testing)
               .environmentObject(authManager)
               .environmentObject(contentViewModel)
               .onAppear {
                   // Run device diagnostics
                   DeviceDiagnostics.shared.logDeviceInfo()
                   DeviceDiagnostics.shared.checkKeychainAccess()
                   
                   // Only fetch content if user is properly authenticated
                   if authManager.isUserLoggedIn {
                       print("EvolveApp: User authenticated, fetching reading content data.")
                       // contentViewModel.fetchReadingContentData() // Temporarily disabled
                   } else {
                       print("EvolveApp: User not authenticated, skipping reading content fetch.")
                   }
               }
        }
    }
}
