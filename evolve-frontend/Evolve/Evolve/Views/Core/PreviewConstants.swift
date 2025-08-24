import SwiftUI

// MARK: - PreviewConstants
struct PreviewConstants {
    @MainActor
    static var sampleAuthManagerUpdated: AuthenticationManager = {
        let authManager = AuthenticationManager()
        
        // Create a sample user info
        let sampleUserInfo = AppUser.Info(
            height: 70.0, // inches
            birthday: "1990-01-01",
            weight: 150.0, // lbs
            sex: "M"
        )

        // Create a sample user
        let sampleUser = AppUser(
            id: "1",
            phone: "+19876543210", 
            backupEmail: nil,
            firstName: "Preview",
            lastName: "User",
            isPhoneVerified: true,
            dateJoined: "2023-01-01T12:00:00Z",
            lifetimePoints: 1000,
            availablePoints: 500,
            lifetimeSavings: 50,
            isOnboarded: true,
            currentStreak: 0,
            longestStreak: 0,
            streakPoints: 0,
            info: sampleUserInfo,
            equipment: nil,
            exerciseMaxes: nil,
            muscleFatigue: nil,
            goals: nil, // Explicitly nil for clarity, or can be omitted
            scheduledActivities: nil, // Explicitly nil, or can be omitted
            completionLogs: nil, // Explicitly nil, or can be omitted
            calorieLogs: nil, // Explicitly nil, or can be omitted
            feedback: nil,
            assignedPromotions: nil, // Explicitly nil, or can be omitted
            promotionRedemptions: [] // Explicitly nil, or can be omitted
        )
        
        authManager.currentUser = sampleUser
        authManager.authToken = "samplePreviewToken"
        // refreshToken is not strictly necessary for previews unless testing refresh logic
        // authManager.refreshToken = "samplePreviewRefreshToken"
        
        return authManager
    }()

    // You can add more static constants here as needed for previews
    // For example:
    // static let sampleActivity = Activity(id: "prev-act-1", name: "Morning Run", ...)
}
// Ensure AppUser and AuthenticationManager are accessible here.
// If they are in a different module, you might need to import that module.
// For example: import YourAppModule

// Note: You'll need to make sure that the AppUser struct and AuthenticationManager class
// definitions are available in the scope of this file. If they are part of your app's
// main target and this file is also in that target, it should work.
// Otherwise, you might need to adjust import statements or target memberships.

// Also, ensure that any custom types used within AppUser (like UserInfo)
// are also defined and accessible.

// If you need to access AppUser or AuthenticationManager in other parts of the app,
// you might need to import the module where they are defined.
// For example: import YourAppModule

// If AppUser or AuthenticationManager are in a different module, you might need to
// adjust import statements or target memberships.

// If you need to access custom types used within AppUser (like UserInfo, UserScheduledActivity, etc.),
// you might need to provide minimal versions or sample data for those as well if they are complex.

// If you need to access AppUser or AuthenticationManager in other parts of the app,
// you might need to import the module where they are defined.
// For example: import YourAppModule

// If AppUser or AuthenticationManager are in a different module, you might need to
// adjust import statements or target memberships.

// If you need to access custom types used within AppUser (like UserInfo, UserScheduledActivity, etc.),
// you might need to provide minimal versions or sample data for those as well if they are complex.

