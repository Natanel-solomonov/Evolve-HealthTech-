import Foundation
import SwiftUI
import MessageUI

@MainActor
class StreakViewModel: ObservableObject {
    @Published var streakData: StreakData?
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var shareMessage: String?
    @Published var showingShareSheet = false
    
    var authManager: AuthenticationManager

    // Computed property to always use the latest authManager
    var foodSearchAPI: FoodSearchAPI {
        FoodSearchAPI(httpClient: authManager.httpClient)
    }

    init(authenticationManager: AuthenticationManager) {
        self.authManager = authenticationManager
    }
    
    func fetchStreakData() {
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                let data = try await self.foodSearchAPI.fetchStreakData()
                await MainActor.run {
                    self.streakData = data
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = "Failed to load streak data: \(error.localizedDescription)"
                    self.isLoading = false
                }
            }
        }
    }
    
    func shareStreak() {
        Task {
            do {
                let response = try await self.foodSearchAPI.shareStreak()
                await MainActor.run {
                    self.shareMessage = response.message
                    self.showingShareSheet = true
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = "Failed to share streak: \(error.localizedDescription)"
                }
            }
        }
    }
}

struct StreakView: View {
    let onBack: () -> Void
    @StateObject private var viewModel = StreakViewModel(authenticationManager: AuthenticationManager())
    @EnvironmentObject var authManager: AuthenticationManager
    @Environment(\.theme) private var theme: any Theme
    
    // Colors matching the nutrition theme
    private let gradientStartColor = Color("Nutrition").opacity(0.6)
    private let gradientEndColor = Color("Nutrition")
    private let cardBackgroundColor = Color.white
    
    init(onBack: @escaping () -> Void) {
        self.onBack = onBack
    }
    
    var body: some View {
        ZStack {
            // Background gradient
            theme.background.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                streakHeader
                    .padding(.top, (UIApplication.shared.connectedScenes.first as? UIWindowScene)?.windows.first?.safeAreaInsets.top ?? 0)
                
                // Content
                ScrollView {
                    VStack(spacing: 24) {
                        // Main streak card
                        streakCard
                            .padding(.horizontal, 16)
                            .padding(.top, 24)
                        
                        // Progress section (only show if streak > 0)
                        if let streakData = viewModel.streakData, streakData.currentStreak > 0 {
                            progressSection
                                .padding(.horizontal, 16)
                        }
                        
                        Spacer(minLength: 100)
                    }
                }
            }
        }
        .onAppear {
            viewModel.authManager = authManager
            viewModel.fetchStreakData()
        }
        .sheet(isPresented: $viewModel.showingShareSheet) {
            if let message = viewModel.shareMessage {
                ShareSheet(items: [message])
            }
        }
    }
    
    private var streakHeader: some View {
        HStack {
            Button(action: onBack) {
                Image(systemName: "chevron.left")
                    .font(.title2)
                    .foregroundColor(theme.primaryText)
            }
            
            Spacer()
            
            Text("Your Streaks")
                .font(.system(size: 18))
                .fontWeight(.bold)
                .foregroundColor(theme.primaryText)
            
            Spacer()
            
            // Invisible button for spacing
            Button(action: {}) {
                Image(systemName: "chevron.left")
                    .font(.title2)
                    .foregroundColor(.clear)
            }
            .disabled(true)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }
    
    private var streakCard: some View {
        VStack(spacing: 0) {
            // Card header with title and share button
            HStack {
                Text("Your Streaks")
                    .font(.system(size: 20))
                    .fontWeight(.bold)
                    .foregroundColor(theme.primaryText)
                
                Spacer()
                
                HStack(spacing: 8) {
                    Button(action: {
                        viewModel.shareStreak()
                    }) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(theme.primaryText.opacity(0.7))
                    }
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(theme.primaryText.opacity(0.4))
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 16)
            
            if viewModel.isLoading {
                // Loading state
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.2)
                    Text("Loading streak data...")
                        .font(.system(size: 14))
                        .foregroundColor(theme.primaryText.opacity(0.6))
                }
                .padding(.vertical, 40)
            } else if let streakData = viewModel.streakData {
                // Streak content
                VStack(spacing: 24) {
                    // Calendar icon and streak count
                    VStack(spacing: 16) {
                        // Calendar icon with circular background
                        ZStack {
                            Circle()
                                .fill(Color("Nutrition").opacity(0.2))
                                .frame(width: 80, height: 80)
                            
                            Image(systemName: "calendar")
                                .font(.system(size: 32, weight: .medium))
                                .foregroundColor(Color("Nutrition"))
                        }
                        
                        // Streak count
                        VStack(spacing: 4) {
                            Text("\(streakData.currentStreak)")
                                .font(.system(size: 48, weight: .bold, design: .rounded))
                                .foregroundColor(theme.primaryText)
                            
                            Text("day streak")
                                .font(.system(size: 16))
                                .foregroundColor(theme.primaryText.opacity(0.6))
                        }
                        
                        // Message based on streak
                        Text(streakMessage(for: streakData.currentStreak))
                            .font(.system(size: 16))
                            .foregroundColor(theme.primaryText.opacity(0.7))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 16)
                    }
                    
                    // Stats row (only if streak > 0)
                    if streakData.currentStreak > 0 {
                        HStack(spacing: 32) {
                            VStack(spacing: 4) {
                                Text("\(streakData.longestStreak)")
                                    .font(.system(size: 20))
                                    .fontWeight(.bold)
                                    .foregroundColor(theme.primaryText)
                                Text("Best Streak")
                                    .font(.system(size: 12))
                                    .foregroundColor(theme.primaryText.opacity(0.6))
                            }
                            
                            Rectangle()
                                .fill(theme.primaryText.opacity(0.1))
                                .frame(width: 1, height: 40)
                            
                            VStack(spacing: 4) {
                                Text("\(streakData.streakPoints)")
                                    .font(.system(size: 20))
                                    .fontWeight(.bold)
                                    .foregroundColor(theme.primaryText)
                                Text("Points Earned")
                                    .font(.system(size: 12))
                                    .foregroundColor(theme.primaryText.opacity(0.6))
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                }
                .padding(.bottom, 24)
            } else {
                // Error state
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 32))
                        .foregroundColor(.orange)
                    
                    Text(viewModel.errorMessage ?? "Failed to load streak data")
                        .font(.system(size: 14))
                        .foregroundColor(theme.primaryText.opacity(0.6))
                        .multilineTextAlignment(.center)
                    
                    Button("Retry") {
                        viewModel.fetchStreakData()
                    }
                    .font(.system(size: 14))
                    .fontWeight(.medium)
                    .foregroundColor(Color("Nutrition"))
                }
                .padding(.vertical, 40)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 16)
                .themedFill(theme.cardStyle)
                .shadow(color: theme.defaultShadow.color, radius: theme.defaultShadow.radius, x: theme.defaultShadow.x, y: theme.defaultShadow.y)
        )
    }
    
    private var progressSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let streakData = viewModel.streakData {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Progress to Next Milestone")
                        .font(.system(size: 18))
                        .fontWeight(.semibold)
                        .foregroundColor(theme.primaryText)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("\(10 - streakData.daysUntilMilestone) of 10 days")
                                .font(.system(size: 14))
                                .foregroundColor(theme.primaryText.opacity(0.8))
                            
                            Spacer()
                            
                            Text("\(streakData.daysUntilMilestone) days to go")
                                .font(.system(size: 14))
                                .fontWeight(.medium)
                                .foregroundColor(theme.primaryText)
                        }
                        
                        // Progress bar
                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                // Background
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(theme.primaryText.opacity(0.3))
                                    .frame(height: 12)
                                
                                // Progress
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(theme.primaryText)
                                    .frame(width: geometry.size.width * (streakData.progressPercentage / 100), height: 12)
                                    .animation(.easeInOut(duration: 0.8), value: streakData.progressPercentage)
                            }
                        }
                        .frame(height: 12)
                        
                        Text("Keep logging food daily to reach your \(streakData.nextMilestone)-day streak milestone!")
                            .font(.system(size: 13))
                            .foregroundColor(theme.primaryText.opacity(0.8))
                            .multilineTextAlignment(.leading)
                    }
                }
                .padding(20)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.white.opacity(0.2))
                )
            }
        }
    }
    
    private func streakMessage(for streak: Int) -> String {
        switch streak {
        case 0:
            return "Start logging to begin your streak!"
        case 1:
            return "Great start! Keep it up tomorrow."
        case 2...6:
            return "Building momentum! \(10 - streak % 10) more days to your next milestone."
        case 7...9:
            return "So close to your 10-day milestone!"
        default:
            if streak % 10 == 0 {
                return "🎉 Milestone achieved! You're unstoppable!"
            } else {
                return "Amazing consistency! \(10 - streak % 10) more days to your next milestone."
            }
        }
    }
}

// MARK: - Share Sheet
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Preview
struct StreakView_Previews: PreviewProvider {
    static var previews: some View {
        StreakView(onBack: {})
            .environmentObject(AuthenticationManager())
    }
}
