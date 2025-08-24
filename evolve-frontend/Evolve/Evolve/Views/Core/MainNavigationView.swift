import SwiftUI

extension Date {
    func formattedDateString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: self)
    }
}

// Environment key for passing dynamic theme color
private struct DynamicThemeColorKey: EnvironmentKey {
    static let defaultValue: Color = Color("Fitness")
}

// Environment key for tracking modal state
private struct ModalActiveKey: EnvironmentKey {
    static let defaultValue: Bool = false
}

extension EnvironmentValues {
    var dynamicThemeColor: Color {
        get { self[DynamicThemeColorKey.self] }
        set { self[DynamicThemeColorKey.self] = newValue }
    }
    
    var isModalActive: Bool {
        get { self[ModalActiveKey.self] }
        set { self[ModalActiveKey.self] = newValue }
    }
}

struct MainNavigationView: View {
    @State private var selectedTab: Int = 0
    @State private var showMaxChatView = false
    @State private var isMaxInputActive = false
    @State private var initialMessageForChat: String?
    @State private var maxInputText: String = ""
    
    // Dynamic theme color that changes based on next scheduled activity for selected date
    @State private var dynamicThemeColor: Color = Color("Fitness")
    
    // State to track modal/workout activity across the app
    @State private var isAnyModalActive = false
    
    // Centralized selected date state for the activity section
    @State private var selectedDate: Date = Date()

    @EnvironmentObject var authManager: AuthenticationManager
    @Environment(\.theme) private var theme: any Theme
    
    // Array of available colors to randomly choose from as fallback
    private let availableColors = ["Fitness", "Nutrition", "Sleep", "Mind"]
    
    /// Determines the theme color based on selected date's next-scheduled activity's category
    private var nextActivityColor: Color {
        let dateStr = selectedDate.formattedDateString()
        let selectedDateActivities = authManager.currentUser?.scheduledActivities?.filter { $0.scheduledDate == dateStr } ?? []
        let incompleteActivities = selectedDateActivities.filter { !$0.isComplete }
        
        if let nextActivity = incompleteActivities.first,
           let firstCategory = nextActivity.activity.category.first {
            return ActivityTypeHelper.color(for: firstCategory)
        }
        
        // Fall back to random color if no next activity
        if let randomColorName = availableColors.randomElement() {
            return Color(randomColorName)
        }
        return Color("Fitness")
    }

    private let tabItems: [TabItemData] = [
        .init(icon: "house", text: "Home"),
        .init(icon: "square.grid.2x2", text: "My Journey"),
        .init(icon: "person.2", text: "Social"),
        .init(icon: "gift", text: "Rewards")
    ]

    var body: some View {
        Group {
            if theme is LiquidGlassTheme {
                liquidGlassBody
            } else {
                legacyBody
            }
        }
        .environment(\.dynamicThemeColor, dynamicThemeColor)
        .environment(\.isModalActive, isAnyModalActive)
        .onAppear {
            // Set color based on next activity when the view appears
            dynamicThemeColor = nextActivityColor
        }
        .onChange(of: authManager.currentUser) { _, _ in
            // Update color when user data changes
            dynamicThemeColor = nextActivityColor
        }
        .onChange(of: selectedDate) { _, _ in
            // Update color when selected date changes
            dynamicThemeColor = nextActivityColor
        }
    }
    
    @ViewBuilder
    private var legacyBody: some View {
        ZStack(alignment: .bottom) {
            VStack(spacing: 0) {
                switch selectedTab {
                case 0:
                    DashboardView(selectedDate: $selectedDate, isModalActive: $isAnyModalActive, authManager: authManager)
                case 1:
                    // My Journey View
                    JourneyView()
                case 2:
                    // Social View
                    SocialView(isModalActive: $isAnyModalActive)
                case 3:
                    // Offers View
                    RewardsView()
                default:
                    DashboardView(selectedDate: $selectedDate, isModalActive: $isAnyModalActive, authManager: authManager)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            // Only show tab bar when no modal is active
            if !isAnyModalActive {
                CustomTabBar(
                    selectedIndex: $selectedTab,
                    isMaxInputActive: $isMaxInputActive,
                    tabItems: tabItems,
                    onSend: { message in
                        self.initialMessageForChat = message
                        self.showMaxChatView = true
                        // Hide the input bar after sending
                        self.isMaxInputActive = false
                    }
                )
            }
        }
        .fullScreenCover(isPresented: $showMaxChatView) {
            ChatView(initialMessage: initialMessageForChat)
                .environmentObject(authManager)
        }
    }
    
    @ViewBuilder
    private var liquidGlassBody: some View {
        // Runtime check for iOS version
        if isIOS26OrLater() {
            TabView {
                Tab("Home", systemImage: "house") {
                    DashboardView(selectedDate: $selectedDate, isModalActive: $isAnyModalActive, authManager: authManager)
                }
                
                Tab("My Journey", systemImage: "square.grid.2x2") {
                    JourneyView()
                }
                
                Tab("Friends", systemImage: "person.2") {
                    SocialView(isModalActive: $isAnyModalActive)
                }
                
                Tab("Rewards", systemImage: "gift") {
                    RewardsView()
                }
                
                Tab("Max", systemImage: "sparkles") {
                    ChatView()
                }
            }
            .tint(dynamicThemeColor)
            
            
        } else {
            // Fallback for older iOS versions - will use legacy TabView appearance
            TabView {
                Tab("Home", systemImage: "house") {
                    DashboardView(selectedDate: $selectedDate, isModalActive: $isAnyModalActive, authManager: authManager)
                }
                
                Tab("My Journey", systemImage: "square.grid.2x2") {
                    JourneyView()
                }
                
                Tab("Friends", systemImage: "person.2") {
                    SocialView(isModalActive: $isAnyModalActive)
                }
                
                Tab("Offers", systemImage: "gift") {
                    RewardsView()
                }
                
                Tab("Max", systemImage: "sparkles") {
                    ChatView()
                }
            }
            .tint(dynamicThemeColor)
            .searchable(text: $maxInputText, prompt: "Ask anything")
            .onSubmit(of: .search) {
                initialMessageForChat = maxInputText
                showMaxChatView = true
                maxInputText = ""
            }
            .fullScreenCover(isPresented: $showMaxChatView) {
                ChatView(initialMessage: initialMessageForChat)
                    .environmentObject(authManager)
            }
        }
    }
    
    /// Runtime check to determine if the device is running iOS 26.0 or later
    private func isIOS26OrLater() -> Bool {
        let version = ProcessInfo.processInfo.operatingSystemVersion
        return version.majorVersion >= 26
    }
}

struct MainNavigationView_Previews: PreviewProvider {
    static var previews: some View {
        // Helper to generate specific activities for preview
        func generatePlaceholderActivities(for date: Date, count: Int) -> [UserScheduledActivity] {
            let dateString: String = {
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy-MM-dd"
                return formatter.string(from: date)
            }()
            
            // Define specific activities based on the date
            let todayActivities = [
                Activity(id: UUID(), name: "Morning Routine", description: "Start the day with intention and energy", defaultPointValue: 10, category: ["Routine"], activityType: "Routine", associatedWorkout: nil, associatedReading: nil, isArchived: false),
                Activity(id: UUID(), name: "Breakfast", description: "Nutritious meal to fuel your morning", defaultPointValue: 8, category: ["Nutrition"], activityType: "Nutrition", associatedWorkout: nil, associatedReading: nil, isArchived: false),
                Activity(id: UUID(), name: "Workout (Biceps and Triceps)", description: "45-minute arm-focused strength training session", defaultPointValue: 15, category: ["Fitness"], activityType: "Workout", associatedWorkout: Workout(id: UUID(), name: "Biceps and Triceps", description: "Complete arm strength training session", duration: "45", createdAt: ISO8601DateFormatter().string(from: Date()), updatedAt: ISO8601DateFormatter().string(from: Date()), workoutexercises: []), associatedReading: nil, isArchived: false),
                Activity(id: UUID(), name: "Lunch", description: "Balanced midday meal for sustained energy", defaultPointValue: 8, category: ["Nutrition"], activityType: "Nutrition", associatedWorkout: nil, associatedReading: nil, isArchived: false),
                Activity(id: UUID(), name: "After-Work Routine", description: "Transition from work to personal time mindfully", defaultPointValue: 6, category: ["Routine"], activityType: "Routine", associatedWorkout: nil, associatedReading: nil, isArchived: false),
                Activity(id: UUID(), name: "Dinner", description: "Satisfying evening meal with family or friends", defaultPointValue: 8, category: ["Nutrition"], activityType: "Nutrition", associatedWorkout: nil, associatedReading: nil, isArchived: false),
                Activity(id: UUID(), name: "Meditation", description: "10-minute mindfulness practice for inner peace", defaultPointValue: 8, category: ["Mind"], activityType: "Mindfulness", associatedWorkout: nil, associatedReading: nil, isArchived: false),
                Activity(id: UUID(), name: "Night Routine", description: "Wind down and prepare for restorative sleep", defaultPointValue: 10, category: ["Routine"], activityType: "Routine", associatedWorkout: nil, associatedReading: nil, isArchived: false)
            ]
            
            let otherDayActivities = [
                Activity(id: UUID(), name: "Sample Activity 1", description: "Placeholder description #1", defaultPointValue: 10, category: ["Fitness"], activityType: "Workout", associatedWorkout: nil, associatedReading: nil, isArchived: false),
                Activity(id: UUID(), name: "Sample Activity 2", description: "Placeholder description #2", defaultPointValue: 10, category: ["Nutrition"], activityType: "Nutrition", associatedWorkout: nil, associatedReading: nil, isArchived: false),
                Activity(id: UUID(), name: "Sample Activity 3", description: "Placeholder description #3", defaultPointValue: 10, category: ["Mind"], activityType: "Mindfulness", associatedWorkout: nil, associatedReading: nil, isArchived: false)
            ]
            
            // Choose activities based on whether it's today
            let isToday = Calendar.current.isDateInToday(date)
            let activities = isToday ? todayActivities : otherDayActivities
            
            var scheduled: [UserScheduledActivity] = []
            for index in 0..<min(count, activities.count) {
                let activity = activities[index]
                let userActivity = UserScheduledActivity(
                    id: UUID(),
                    user: "previewUser",
                    activity: activity,
                    scheduledDate: dateString,
                    scheduledDisplayTime: "Preview Time",
                    isGenerated: false,
                    orderInDay: index,
                    isComplete: false,
                    completedAt: nil, generatedDescription: "",
                    customNotes: nil
                )
                scheduled.append(userActivity)
            }
            return scheduled
        }

        let previewManager = AuthenticationManager()

        // Dates
        let calendar = Calendar.current
        let today = Date()
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today) ?? today
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today) ?? today
        let isoStringToday = ISO8601DateFormatter().string(from: today)

        // Aggregate activities - Today gets 8 specific activities, other days get 2-3 sample activities
        let allScheduled = generatePlaceholderActivities(for: yesterday, count: 2) +
                           generatePlaceholderActivities(for: today, count: 8) +
                           generatePlaceholderActivities(for: tomorrow, count: 3)
        
        // Sample goals data
        let sampleGoals = AppUser.GoalsData(
            goalsRaw: [
                "build_muscle",
                "get_stronger",
                "eat_healthier",
                "sleep_better"
            ],
            goalsProcessed: [
                "Increase muscle mass by 10 pounds through progressive strength training",
                "Run a 5K in under 25 minutes within 3 months",
                "Track daily macros and maintain a protein intake of 1g per pound of body weight",
                "Achieve 7-8 hours of quality sleep each night"
            ]
        )
        
        // Create preview user
        let sampleUser = AppUser(
            id: "1", phone: "+10000000000", backupEmail: nil, firstName: "Jane", lastName: "Doe", isPhoneVerified: true,
            dateJoined: isoStringToday, lifetimePoints: 120, availablePoints: 60, lifetimeSavings: 15,
            isOnboarded: true, currentStreak: 5, longestStreak: 10, streakPoints: 50, info: nil, equipment: nil, exerciseMaxes: nil, muscleFatigue: nil,
            goals: sampleGoals, scheduledActivities: allScheduled,
            completionLogs: nil, calorieLogs: nil, feedback: nil, assignedPromotions: nil,
            promotionRedemptions: []
        )
        
        previewManager.currentUser = sampleUser
        

        return MainNavigationView()
            .environmentObject(previewManager)
            .environment(\.theme, LiquidGlassTheme())
    }
}


// MARK: - TopHorizontalGradient
struct TopHorizontalGradient: View {
    let leftColor: Color
    let rightColor: Color

    var body: some View {
        LinearGradient(
            gradient: Gradient(colors: [leftColor, rightColor]),
            startPoint: .leading,
            endPoint: .trailing
        )
        .mask(
            LinearGradient(
                gradient: Gradient(colors: [Color("OffWhite"), .clear]), // Opaque to Transparent
                startPoint: .top,
                endPoint: UnitPoint(x: 0.5, y: 0.55)
            )
        )
    }
}

struct TopSolidColor: View {
    let color: Color

    var body: some View {
        Rectangle()
            .fill(color)
            .mask(
                LinearGradient(
                    gradient: Gradient(colors: [Color("OffWhite"), .clear]), // Opaque to Transparent
                    startPoint: .top,
                    endPoint: UnitPoint(x: 0.5, y: 0.55)
                )
            )
    }
}
