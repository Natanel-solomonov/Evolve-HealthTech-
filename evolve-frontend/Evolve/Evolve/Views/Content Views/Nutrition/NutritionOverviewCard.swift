import SwiftUI

// Codable struct for the BMR API response
struct BMRResponse: Codable {
    let bmr: Double
    // Optional fields from serializer for debugging/future use
    let sex: String?
    let weight_lb: Double?
    let height_in: Double?
    let birthday: String? // Dates are often passed as ISO strings
    let age: Int?
}

struct NutritionCardView: View {
    @EnvironmentObject var authManager: AuthenticationManager
    @State private var bmrData: BMRResponse? = nil
    @State private var isLoading: Bool = false
    @State private var errorMessage: String?
    @Environment(\.theme) private var theme: any Theme

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Nutrition Overview")
                    .font(.system(size: 22))
                    .fontWeight(.bold)
                    .foregroundColor(theme.primaryText)
                Spacer()
                if isLoading {
                    ProgressView()
                } else if let bmrValue = bmrData?.bmr {
                    VStack(alignment: .trailing) {
                        Text("\(Int(bmrValue)) kcal")
                            .font(.system(size: 17))
                            .fontWeight(.semibold)
                            .foregroundColor(theme.accent)
                        Text("Est. BMR")
                            .font(.system(size: 12))
                            .foregroundColor(theme.secondaryText)
                    }
                } else if let errorMsg = errorMessage {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.red)
                        Text(errorMsg)
                            .font(.system(size: 12))
                            .foregroundColor(.red)
                            .lineLimit(2) // Allow for slightly longer error messages
                            .multilineTextAlignment(.trailing)
                    }
                    .onTapGesture {
                        Task {
                            await fetchBMR()
                        }
                    }
                } else {
                    Text("-- kcal")
                        .font(.system(size: 17))
                        .foregroundColor(theme.secondaryText)
                }
            }

            // Placeholder for other nutrition info
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(UIColor.secondarySystemBackground))
                    .frame(height: 100)
                
                Text("More nutrition stats coming soon!")
                    .font(.system(size: 16))
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 20)
                .themedFill(theme.cardStyle)
                .shadow(color: theme.defaultShadow.color, radius: theme.defaultShadow.radius, x: theme.defaultShadow.x, y: theme.defaultShadow.y)
        )
        .padding() // Outer padding for dashboard consistency
        .onAppear {
            // Only fetch if BMR is not already loaded and user is logged in.
            if bmrData == nil && authManager.isUserLoggedIn {
                Task {
                    await fetchBMR()
                }
            } else if !authManager.isUserLoggedIn && errorMessage == nil {
                errorMessage = "Login to see BMR."
                print("NutritionCardView: User not logged in on appear.")
            }
        }
        // React to user login/logout after the view has appeared
        .onChange(of: authManager.currentUser) { oldUser, newUser in
            if newUser != nil && bmrData == nil { // User logged in, and no BMR data yet
                Task {
                    await fetchBMR()
                }
            } else if newUser == nil { // User logged out
                bmrData = nil
                errorMessage = "Login to see BMR."
                isLoading = false // Ensure loading state is reset
                print("NutritionCardView: User logged out, cleared BMR data.")
            }
        }
    }

    private func fetchBMR() async {
        guard authManager.isUserLoggedIn else {
            errorMessage = "Login to see BMR."
            isLoading = false
            print("NutritionCardView: Cannot fetch BMR, user not logged in.")
            return
        }

        isLoading = true
        errorMessage = nil
        print("NutritionCardView: Attempting to fetch BMR.")

        do {
            let response: BMRResponse = try await authManager.httpClient.request(
                endpoint: "/user/bmr/", // Ensure this matches your Django URL
                method: "GET",
                requiresAuth: true
            )
            self.bmrData = response
            print("NutritionCardView: Successfully fetched BMR: \(response.bmr). Full data: \(response)")
        } catch let networkError as NetworkError {
            print("NutritionCardView: NetworkError fetching BMR: \(networkError)")
            switch networkError {
            case .unauthorized, .sessionExpired:
                errorMessage = "Session expired. Please login."
                // authManager.logout() // Or handle globally
            case .serverError(let statusCode, let details):
                let detailsString = details.flatMap { String(data: $0, encoding: .utf8) } ?? "N/A"
                if statusCode == 404 {
                    errorMessage = "Profile data missing for BMR."
                    print("NutritionCardView: BMR fetch returned 404. Details: \(detailsString)")
                } else if statusCode == 400 {
                    errorMessage = "Profile incomplete for BMR."
                    print("NutritionCardView: BMR fetch returned 400 (Bad Request - likely missing info). Details: \(detailsString)")
                } else {
                    errorMessage = "Server Error (\(statusCode))."
                }
            case .decodingError(let specificError):
                print("NutritionCardView: Decoding error - \(specificError). Raw data might be helpful to log here if possible.")
                errorMessage = "Data error from server."
            case .requestFailed(let specificError):
                print("NutritionCardView: Request failed - \(specificError)")
                errorMessage = "Network connection issue."
            default:
                errorMessage = "Could not load BMR."
            }
        } catch {
            print("NutritionCardView: Unexpected error fetching BMR: \(error)")
            errorMessage = "An unexpected error occurred."
        }
        isLoading = false
    }
}

// PreviewProvider for NutritionCardView
struct NutritionCardView_Previews: PreviewProvider {
    @MainActor
    static var previews: some View {
        // Mock AuthenticationManager for previews
        let loggedOutAuthManager = AuthenticationManager()

        let loggedInAuthManager = AuthenticationManager()
        // Create a mock user for the logged-in state.
        // Ensure AppUser.Info and AppUser initializers match your actual model structure.
        let previewUserInfo = AppUser.Info(
            height: 70, // inches
            birthday: "1990-01-01",
            weight: 160, // pounds
            sex: "M"
        )
        let previewUser = AppUser(
            id: "00000000-0000-0000-0000-000000000001",
            phone: "+11234567890",
            backupEmail: "preview@example.com",
            firstName: "Preview",
            lastName: "User",
            isPhoneVerified: true,
            dateJoined: "2023-01-01T00:00:00Z",
            lifetimePoints: 100,
            availablePoints: 100,
            lifetimeSavings: 0,
            isOnboarded: true,
            currentStreak: 5,
            longestStreak: 12,
            streakPoints: 100,
            info: previewUserInfo,
            equipment: nil,
            exerciseMaxes: nil,
            muscleFatigue: nil,
            goals: nil,
            scheduledActivities: [],
            completionLogs: [],
            calorieLogs: [],
            feedback: nil,
            assignedPromotions: [],
            promotionRedemptions: []
        )
        loggedInAuthManager.currentUser = previewUser
        
        // Mock HTTPClient for successful BMR response
        // This part is more complex if you want to fully mock httpClient behavior in previews.
        // For simplicity, we're relying on the onAppear logic which won't actually fetch in previews
        // unless you set up a mock HTTP client in AuthenticationManager or directly here.
        // The view will show "-- kcal" or error states based on currentUser.

        return Group {
            VStack {
                Text("Nutrition Card (Logged In)")
                    .font(.system(size: 12)).padding(.bottom)
                NutritionCardView()
                    .environmentObject(loggedInAuthManager)
                    .liquidGlassTheme()
            }
            .padding()
            .previewDisplayName("Logged In - Legacy")

            VStack {
                Text("Nutrition Card (Logged Out)")
                    .font(.system(size: 12)).padding(.bottom)
                NutritionCardView()
                    .environmentObject(loggedOutAuthManager)
                    .liquidGlassTheme()
            }
            .padding()
            .previewDisplayName("Logged Out - Legacy")
            
            VStack {
                 Text("Nutrition Card (BMR Loaded)")
                     .font(.system(size: 12)).padding(.bottom)
                 NutritionCardView()
                     .environmentObject(loggedInAuthManager)
                     .environment(\.theme, LiquidGlassTheme())
            }
            .padding()
            .previewDisplayName("BMR Loaded - Liquid Glass")

            VStack {
                 Text("Nutrition Card (Error State)")
                     .font(.system(size: 12)).padding(.bottom)
                 NutritionCardView()
                     .environmentObject(loggedInAuthManager)
                     .environment(\.theme, LiquidGlassTheme())
            }
            .padding()
            .previewDisplayName("Error State - Liquid Glass")

        }
        .previewLayout(.sizeThatFits)
        .background(Color(UIColor.systemGroupedBackground))
    }
}

// Define a private extension for Color if not already globally available
private extension Color {
    static let evolvePurple = Color(red: 0.588, green: 0.549, blue: 0.961) // RGB: 150, 140, 245
}

// Add a helper in AuthenticationManager or ensure it exists
// extension AuthenticationManager {
//     func isUserLoggedIn() -> Bool {
//         return currentUser != nil && authToken != nil // Or however you define "logged in"
//     }
// }
