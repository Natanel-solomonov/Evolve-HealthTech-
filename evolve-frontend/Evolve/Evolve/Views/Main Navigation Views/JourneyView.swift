import SwiftUI
import Combine

private func dateFromISOString(_ string: String?) -> Date? {
    guard let string = string else { return nil }
    
    // Create ISO8601DateFormatter with fractional seconds support
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    
    // Try with fractional seconds first
    if let date = formatter.date(from: string) {
        return date
    }
    
    // Fallback to standard ISO8601 without fractional seconds
    let fallbackFormatter = ISO8601DateFormatter()
    fallbackFormatter.formatOptions = [.withInternetDateTime]
    
    if let date = fallbackFormatter.date(from: string) {
        return date
    }
    
    // Final fallback using DateFormatter for more flexibility
    let dateFormatter = DateFormatter()
    dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSSSSXXXXX" // Handles microseconds
    dateFormatter.locale = Locale(identifier: "en_US_POSIX")
    dateFormatter.timeZone = TimeZone(secondsFromGMT: 0)
    
    return dateFormatter.date(from: string)
}

// MARK: - Journey Feed Item
enum JourneyFeedItem: Identifiable {
    case journey(JourneyEntry)
    case completedActivity(UserCompletedLog)

    var id: AnyHashable {
        switch self {
        case .journey(let entry):
            return entry.id
        case .completedActivity(let log):
            return log.id
        }
    }

    var date: Date {
        switch self {
        case .journey(let entry):
            return entry.date
        case .completedActivity(let log):
            return dateFromISOString(log.completedAt) ?? Date()
        }
    }
    
    var tags: [String] {
        switch self {
        case .journey(let entry):
            return [entry.type] // Use type for filtering (e.g., "Journal", "Meditation")
        case .completedActivity(let log):
            return [log.activity?.activityType ?? "Other"] // Use activity type for filtering
        }
    }
    
    var displayTypes: [String] {
        switch self {
        case .journey(let entry):
            return [entry.type] // Use type for display
        case .completedActivity(let log):
            return [log.activity?.activityType ?? "Other"] // Use activity type for display
        }
    }
}

// MARK: - Journey Entry Model
struct JourneyEntry: Identifiable {
    let id = UUID()
    let title: String
    let content: String
    let date: Date
    let mood: String?
    let category: String // For color and filtering (e.g., "Mind", "Fitness")
    let type: String     // For display text (e.g., "Journal", "Meditation")
}

// MARK: - Journey View
struct JourneyView: View {
    @EnvironmentObject var authManager: AuthenticationManager
    @State private var selectedTab = 0
    @State private var selectedFilter = "All"
    @StateObject private var cinematicManager = CinematicStateManager()
    @State private var searchText = ""
    @State private var showingAddEntry = false
    @State private var showingLogMood = false
    @State private var showingLogFood = false
    @State private var isSearching = false
    @Environment(\.theme) private var theme: any Theme
    
    // Background styling - same as DashboardView
    private let leftGradientColor: Color = Color("Fitness")
    private let rightGradientColor: Color = Color("Sleep")
    @State private var useGradientBackground = false
    @Environment(\.dynamicThemeColor) private var dynamicThemeColor
    
    // Activity data management
    @State private var journeyFeedItems: [JourneyFeedItem] = []
    @State private var isLoadingActivities = false
    @State private var errorMessage: String?
    
    // Dynamic filters based on logged activity types
    private var availableFilters: [String] {
        let activityTypes = Set(journeyFeedItems.flatMap { $0.tags })
        let sortedTypes = Array(activityTypes).sorted()
        return sortedTypes.isEmpty ? [] : ["All"] + sortedTypes
    }
    
    private var shouldShowFilters: Bool {
        return !journeyFeedItems.isEmpty && availableFilters.count > 1
    }
    
    init() {
        // This will change the background of all segmented controls in the app
        // to achieve the desired "whiter" and "more opaque" effect.
        UISegmentedControl.appearance().backgroundColor = .white.withAlphaComponent(0.85)
    }
    
    var body: some View {
        if theme is LiquidGlassTheme {
            // LiquidGlassTheme - shows search bar only on Log tab
            liquidGlassView
        } else {
            // Legacy theme
            standardView
        }
    }
    
    @ViewBuilder
    private var standardView: some View {
        GeometryReader { geometry in
            ZStack {
                // Background – same as DashboardView
                GridBackground()
                    .cinematicBackground(isActive: cinematicManager.isAnyActive)
                
                if useGradientBackground {
                    TopHorizontalGradient(leftColor: leftGradientColor, rightColor: rightGradientColor)
                        .frame(height: geometry.size.height * 0.6)
                        .frame(maxHeight: .infinity, alignment: .top)
                        .ignoresSafeArea()
                } else {
                    TopSolidColor(color: dynamicThemeColor)
                        .frame(height: geometry.size.height * 0.6)
                        .frame(maxHeight: .infinity, alignment: .top)
                        .ignoresSafeArea()
                }
                
                VStack(spacing: 0) {
                    // Content based on selected tab
                    if selectedTab == 0 {
                        StatsView(headerView: AnyView(
                            VStack(spacing: 20) {
                                JourneyHeaderView(onSettingsTap: {
                                    cinematicManager.present("settings")
                                })
                                    .padding(.horizontal)
                                
                                HStack {
                                    Spacer()
                                    Picker("View", selection: $selectedTab) {
                                        Text("Stats").tag(0)
                                        Text("Activity").tag(1)
                                    }
                                    .pickerStyle(SegmentedPickerStyle())
                                    .frame(width: 200)
                                    Spacer()
                                }
                                .padding(.horizontal)
                            }
                        ))
                    } else {
                        LogView(
                            items: filteredItems,
                            filters: availableFilters,
                            selectedFilter: $selectedFilter,
                            shouldShowFilters: shouldShowFilters,
                            isLoading: isLoadingActivities,
                            errorMessage: errorMessage,
                            onRetry: loadCompletedActivities,
                            headerView: AnyView(
                                VStack(spacing: 20) {
                                    JourneyHeaderView(onSettingsTap: {
                                        cinematicManager.present("settings")
                                    })
                                        .padding(.horizontal)
                                    
                                    HStack {
                                        Spacer()
                                        Picker("View", selection: $selectedTab) {
                                            Text("Stats").tag(0)
                                            Text("Activity").tag(1)
                                        }
                                        .pickerStyle(SegmentedPickerStyle())
                                        .frame(width: 200)
                                        Spacer()
                                    }
                                    .padding(.horizontal)
                                }
                            )
                        )
                    }
                }
                
                // Cinematic settings overlay
                if cinematicManager.isActive("settings") {
                    SettingsView<AuthenticationManager>(
                        onDismiss: {
                            cinematicManager.dismiss("settings")
                        }
                    )
                    .environmentObject(authManager)
                    .cinematicOverlay()
                }
            }
        }
        .onAppear(perform: loadCompletedActivities)
        .onChange(of: authManager.currentUser) { _, _ in
            loadCompletedActivities()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ActivityCompleted"))) { _ in
            // Reload activities when a new completion log is created
            loadCompletedActivities()
        }
        .sheet(isPresented: $showingAddEntry) {
            Text("Add Entry View")
                .presentationDetents([.medium, .large])
        }
        .fullScreenCover(isPresented: $showingLogMood) {
            ComingSoonViewWrapper(isPresented: $showingLogMood)
        }
        .fullScreenCover(isPresented: $showingLogFood) {
            ComingSoonViewWrapper(isPresented: $showingLogFood)
        }
    }
    
    @ViewBuilder
    private var liquidGlassView: some View {
        GeometryReader { geometry in
            ZStack {
                // Background – same as DashboardView
                GridBackground()
                    .cinematicBackground(isActive: cinematicManager.isAnyActive)
                
                if useGradientBackground {
                    TopHorizontalGradient(leftColor: leftGradientColor, rightColor: rightGradientColor)
                        .frame(height: geometry.size.height * 0.6)
                        .frame(maxHeight: .infinity, alignment: .top)
                        .ignoresSafeArea()
                } else {
                    TopSolidColor(color: dynamicThemeColor)
                        .frame(height: geometry.size.height * 0.6)
                        .frame(maxHeight: .infinity, alignment: .top)
                        .ignoresSafeArea()
                }
                
                VStack(spacing: 0) {
                    // Content based on selected tab
                    if selectedTab == 0 {
                        StatsView(headerView: AnyView(
                            VStack(spacing: 20) {
                                JourneyHeaderView(onSettingsTap: {
                                    cinematicManager.present("settings")
                                })
                                    .padding(.horizontal)
                            }
                        ))
                    } else {
                        LogView(
                            items: filteredItems,
                            filters: availableFilters,
                            selectedFilter: $selectedFilter,
                            shouldShowFilters: shouldShowFilters,
                            isLoading: isLoadingActivities,
                            errorMessage: errorMessage,
                            onRetry: loadCompletedActivities,
                            headerView: AnyView(
                                                            VStack(spacing: 20) {
                                JourneyHeaderView(onSettingsTap: {
                                    cinematicManager.present("settings")
                                })
                                    .padding(.horizontal)
                            }
                            )
                        )
                    }
                }
                .safeAreaInset(edge: .bottom) {
                    journeyBottomBar
                }
                
                // Cinematic settings overlay
                if cinematicManager.isActive("settings") {
                    SettingsView<AuthenticationManager>(
                        onDismiss: {
                            cinematicManager.dismiss("settings")
                        }
                    )
                    .environmentObject(authManager)
                    .cinematicOverlay()
                }
            }
        }
        .onAppear(perform: loadCompletedActivities)
        .onChange(of: authManager.currentUser) { _, _ in
            loadCompletedActivities()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ActivityCompleted"))) { _ in
            // Reload activities when a new completion log is created
            loadCompletedActivities()
        }
        .sheet(isPresented: $showingAddEntry) {
            Text("Add Entry View")
                .presentationDetents([.medium, .large])
        }
        .fullScreenCover(isPresented: $showingLogMood) {
            ComingSoonViewWrapper(isPresented: $showingLogMood)
        }
        .fullScreenCover(isPresented: $showingLogFood) {
            ComingSoonViewWrapper(isPresented: $showingLogFood)
        }
    }
    
    @ViewBuilder
    private var journeyBottomBar: some View {
        HStack(spacing: 12) {
            if isSearching {
                // Search field and cancel button
                HStack {
                    Image(systemName: "magnifyingglass")
                        .font(.title3)
                        .foregroundColor(theme.secondaryText)
                    
                    TextField("Search entries...", text: $searchText)
                        .font(.body)
                        .textFieldStyle(.plain)
                    
                    if !searchText.isEmpty {
                        Button { searchText = "" } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.title3)
                                .foregroundColor(theme.secondaryText)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .tint(dynamicThemeColor)
                .background(.ultraThickMaterial, in: .capsule)
                .transition(.move(edge: .bottom).combined(with: .opacity))
                
                Button("Cancel") {
                    isSearching = false
                    searchText = ""
                }
                .font(.body)
                .transition(.move(edge: .bottom).combined(with: .opacity))
                
            } else {
                // Fixed width container for search button to prevent layout shifts
                HStack {
                    if selectedTab == 1 {
                        Button {
                            isSearching = true
                        } label: {
                            Image(systemName: "magnifyingglass")
                                .font(.title)
                                .foregroundColor(theme.primaryText)
                                .frame(width: 55, height: 55)
                                .background(.white, in: .circle)
                        }
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
                .frame(width: 55, height: 55) // Fixed size to prevent layout shifts
                
                Spacer()
                
                // Segmented Control - this will now stay in place
                Picker("View", selection: $selectedTab) {
                    Text("Stats").padding(.vertical, 10).tag(0)
                    Text("Activity").padding(.vertical, 10).tag(1)
                }
                .pickerStyle(SegmentedPickerStyle())
                .frame(width: 220)
                
                Spacer()
                
                // Fixed width container for add button to prevent layout shifts
                HStack {
                    if selectedTab == 1 {
                        Menu {
                            // Activity tab options
                            Button("Write entry", action: { showingAddEntry = true })
                            Button("Log mood", action: { showingLogMood = true })
                            Button("Log food", action: { showingLogFood = true })
                        } label: {
                            Image(systemName: "plus")
                                .font(.title)
                                .foregroundColor(.black)
                                .frame(width: 55, height: 55)
                                .background(.white, in: .circle)
                        }
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
                .frame(width: 55, height: 55) // Fixed size to prevent layout shifts
            }
        }
        .padding(.horizontal)
        .padding(.top, 8)
        .padding(.bottom, 4) // Less bottom padding because of home indicator area
        .animation(.snappy, value: isSearching)
        .animation(.snappy, value: selectedTab)
    }
    
    private func loadCompletedActivities() {
        // Don't load if user is not authenticated
        guard authManager.isUserLoggedIn else {
            DispatchQueue.main.async {
                self.journeyFeedItems = []
                self.isLoadingActivities = false
                self.errorMessage = nil
            }
            return
        }
        
        // Avoid multiple concurrent loads
        guard !isLoadingActivities else { return }
        
        DispatchQueue.main.async {
            self.isLoadingActivities = true
            self.errorMessage = nil
        }
        
        let userActivityAPI = UserActivityAPI(httpClient: authManager.httpClient)
        
        // Fetch completion logs from the API
        userActivityAPI.fetchCompletionLogs { result in
            DispatchQueue.main.async {
                self.isLoadingActivities = false
                
                switch result {
                case .success(let completionLogs):
                    // Convert completion logs to feed items and sort by completion date (most recent first)
                    let completionFeedItems = completionLogs
                        .compactMap { log -> JourneyFeedItem? in
                            // Ensure we have a valid completion date
                            guard dateFromISOString(log.completedAt) != nil else { 
                                print("Warning: Skipping completion log with invalid date: \(log.id)")
                                return nil 
                            }
                            return JourneyFeedItem.completedActivity(log)
                        }
                        .sorted { item1, item2 in
                            // Sort by completion date (most recent first)
                            // Handle edge cases where dates might be equal
                            let date1 = item1.date
                            let date2 = item2.date
                            if date1 == date2 {
                                // If dates are equal, sort by activity name for consistency
                                switch (item1, item2) {
                                case (.completedActivity(let log1), .completedActivity(let log2)):
                                    return log1.activityNameAtCompletion < log2.activityNameAtCompletion
                                default:
                                    return false
                                }
                            }
                            return date1 > date2
                        }
                    
                    print("Loaded \(completionFeedItems.count) completed activities (chronologically sorted)")
                    self.journeyFeedItems = completionFeedItems
                    
                    // Reset filter to "All" if current filter is no longer available
                    if !self.availableFilters.contains(self.selectedFilter) {
                        self.selectedFilter = "All"
                    }
                    
                case .failure(let error):
                    print("Failed to load completed activities: \(error)")
                    self.errorMessage = "Failed to load activities: \(error.localizedDescription)"
                    self.journeyFeedItems = []
                }
            }
        }
    }
    
    private var filteredItems: [JourneyFeedItem] {
        let baseItems = journeyFeedItems.filter { item in
            if selectedFilter == "All" {
                return true
            }
            return item.tags.contains(selectedFilter)
        }

        if searchText.isEmpty {
            return baseItems
        } else {
            return baseItems.filter { item in
                switch item {
                case .journey(let entry):
                    return entry.title.localizedCaseInsensitiveContains(searchText) ||
                           entry.content.localizedCaseInsensitiveContains(searchText)
                case .completedActivity(let log):
                    let titleMatch = log.activityNameAtCompletion.localizedCaseInsensitiveContains(searchText)
                    let descriptionMatch = log.descriptionAtCompletion?.localizedCaseInsensitiveContains(searchText) ?? false
                    let notesMatch = log.userNotesOnCompletion?.localizedCaseInsensitiveContains(searchText) ?? false
                    return titleMatch || descriptionMatch || notesMatch
                }
            }
        }
    }
}

// MARK: - Journey Header View
private struct JourneyHeaderView: View {
    @Environment(\.theme) private var theme: any Theme
    @EnvironmentObject var authManager: AuthenticationManager
    let onSettingsTap: () -> Void

    private var userInitials: String {
        guard let user = authManager.currentUser, !user.firstName.isEmpty, !user.lastName.isEmpty else {
            return ""
        }
        
        let firstInitial = String(user.firstName.first!)
        let lastInitial = String(user.lastName.first!)
        
        return "\(firstInitial)\(lastInitial)"
    }
    
    private var dynamicGreeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        let firstName = authManager.currentUser?.firstName ?? "there"
        
        switch hour {
        case 0..<12:
            return "Good morning, \(firstName)"
        case 12..<17:
            return "Good afternoon, \(firstName)"
        case 17..<21:
            return "Good evening, \(firstName)"
        default:
            return "Good night, \(firstName)"
        }
    }

    var body: some View {
        HStack {
            Text(dynamicGreeting)
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(theme.primaryText)
            
            Spacer()

            Button(action: onSettingsTap) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [Color.white, Color("OffWhite")]),
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .shadow(color: .black.opacity(0.15), radius: 4, x: 0, y: 4)
                        .frame(width: 40, height: 40)
                    
                    if userInitials.isEmpty {
                        Image(systemName: "person.fill")
                            .foregroundColor(theme.primaryText)
                    } else {
                        Text(userInitials)
                            .font(.headline)
                            .foregroundColor(theme.primaryText)
                    }
                }
            }
        }
        .padding(.top, 10)
    }
}

// MARK: - Log View
private struct LogView: View {
    let items: [JourneyFeedItem]
    let filters: [String]
    @Binding var selectedFilter: String
    let shouldShowFilters: Bool
    let isLoading: Bool
    let errorMessage: String?
    let onRetry: () -> Void
    let headerView: AnyView?
    @Environment(\.theme) private var theme: any Theme
    
    init(items: [JourneyFeedItem], filters: [String], selectedFilter: Binding<String>, shouldShowFilters: Bool = true, isLoading: Bool = false, errorMessage: String? = nil, onRetry: @escaping () -> Void = {}, headerView: AnyView? = nil) {
        self.items = items
        self.filters = filters
        self._selectedFilter = selectedFilter
        self.shouldShowFilters = shouldShowFilters
        self.isLoading = isLoading
        self.errorMessage = errorMessage
        self.onRetry = onRetry
        self.headerView = headerView
    }
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 20) {
                // Header if provided
                if let headerView = headerView {
                    headerView
                }
                
                // Overview Section
                // OverviewSection()
                
                // Activity Section Header
                HStack {
                    Text("Completed Activities")
                        .font(.system(size: 21, weight: .semibold))
                        .foregroundColor(theme.primaryText)
                    
                    Spacer()
                }
                .padding(.horizontal)
                
                // Filter Buttons - wrapping layout, only shown if there are activities
                if shouldShowFilters {
                    ActivityTypeFilterView(
                        filters: filters,
                        selectedFilter: $selectedFilter
                    )
                    .padding(.horizontal)
                    .padding(.bottom, 8)
                }
                
                // Content based on state
                if isLoading {
                    LoadingStateView()
                } else if let errorMessage = errorMessage {
                    ErrorStateView(message: errorMessage, onRetry: onRetry)
                } else if items.isEmpty {
                    EmptyStateView()
                } else {
                    // Activity entries
                    ForEach(items) { item in
                        switch item {
                        case .journey(let entry):
                            JourneyEntryCard(entry: entry)
                                .padding(.horizontal)
                        case .completedActivity(let log):
                            CompletedActivityCard(log: log)
                                .padding(.horizontal)
                        }
                    }
                }
            }
            .padding(.bottom, 100) // Space for tab bar
        }
        .refreshable {
            await withCheckedContinuation { continuation in
                onRetry()
                // Add a small delay to show the refresh animation
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    continuation.resume()
                }
            }
        }
    }
}

// MARK: - Activity Type Filter View
private struct ActivityTypeFilterView: View {
    let filters: [String]
    @Binding var selectedFilter: String
    @Environment(\.theme) private var theme: any Theme
    
    // Define the grid layout with flexible columns
    private let columns = [
        GridItem(.adaptive(minimum: 100, maximum: 160), spacing: 8)
    ]
    
    var body: some View {
        LazyVGrid(columns: columns, spacing: 8) {
            ForEach(filters, id: \.self) { filter in
                ActivityTypeFilterButton(
                    title: filter,
                    isSelected: selectedFilter == filter,
                    action: { selectedFilter = filter }
                )
            }
        }
    }
}

// MARK: - Activity Type Filter Button
private struct ActivityTypeFilterButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    @Environment(\.theme) private var theme: any Theme
    
    private var activityTypeColor: Color {
        // Map activity types to their corresponding category colors
        switch title {
        case "All": return .black
        
        // Fitness types
        case "Workout", "Weight Tracking", "Personal Record":
            return Color("Fitness")
        
        // Nutrition types
        case "Food Log", "Water Intake", "Caffeine Log", "Alcohol Log", "Recipe", "Supplement Log":
            return Color("Nutrition")
        
        // Mind types
        case "Journal", "Meditation", "Breathing", "Mood Check", "Emotions Check", "Energy Level Log", "Mindfulness":
            return Color("Mind")
        
        // Sleep types
        case "Sleep Tracking", "Sleep Debt Calculation":
            return Color("Sleep")
        
        // Other types
        case "Prescription Log", "Sex Log", "Symptoms Log", "Cycle Log", "Routine", "Other":
            return .black
        
        default: return theme.accent
        }
    }
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(isSelected ? .white : theme.primaryText)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .frame(minHeight: 36) // Ensure minimum tap target size
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 18)
                        .fill(isSelected ? activityTypeColor : Color.clear)
                        .overlay(
                            RoundedRectangle(cornerRadius: 18)
                                .stroke(isSelected ? Color.clear : theme.primaryText.opacity(0.2), lineWidth: 1)
                        )
                )
        }
        .buttonStyle(PlainButtonStyle())
    }
}




// MARK: - Journey Entry Card
private struct JourneyEntryCard: View {
    let entry: JourneyEntry
    @Environment(\.theme) private var theme: any Theme
    @State private var showingMenu = false
    
    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: entry.date)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Title
            Text(entry.title)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(theme.primaryText)
            
            // Content
            Text("\(Image(systemName: "text.append")) \(entry.content)")
                .font(.system(size: 16))
                .foregroundColor(theme.secondaryText)
                .lineLimit(3)
            
            // Tags - Show type with category color
            TagView(category: entry.category, displayText: entry.type)
            
            // Footer
            HStack {
                Text(formattedDate)
                    .font(.system(size: 14))
                    .foregroundColor(theme.secondaryText)
                
                Spacer()
                
                Button(action: { showingMenu = true }) {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 16))
                        .foregroundColor(theme.secondaryText)
                        .frame(width: 30, height: 30)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .fill(theme.background)
                .shadow(color: theme.defaultShadow.color, radius: theme.defaultShadow.radius, x: theme.defaultShadow.x, y: theme.defaultShadow.y)
        )
    }
}

// MARK: - Tag View
private struct TagView: View {
    let category: String      // Used for color (e.g., "Mind", "Fitness")
    let displayText: String   // Used for display (e.g., "Meditation", "Journal")
    @Environment(\.theme) private var theme: any Theme
    
    private var tagColor: Color {
        switch category {
        case "Fitness": return Color("Fitness")
        case "Nutrition": return Color("Nutrition")
        case "Mind": return Color("Mind")
        case "Sleep": return Color("Sleep")
        case "Other": return .black
        default: return theme.accent
        }
    }
    
    var body: some View {
        Text(displayText)
            .font(.system(size: 12, weight: .medium))
            .foregroundColor(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(tagColor)
            )
            .if(theme is LiquidGlassTheme) { view in
                view.shadow(color: tagColor.opacity(0.3), radius: 4, x: 0, y: 2)
            }
    }
}

// MARK: - Completed Activity Card
private struct CompletedActivityCard: View {
    let log: UserCompletedLog
    @Environment(\.theme) private var theme: any Theme
    @State private var showingMenu = false
    
    private var formattedDate: String {
        guard let date = dateFromISOString(log.completedAt) else { return "Unknown date" }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    private var categoryColor: Color {
        guard let category = log.activity?.category.first else { return .black }
        switch category {
        case "Fitness": return Color("Fitness")
        case "Nutrition": return Color("Nutrition")
        case "Mind": return Color("Mind")
        case "Sleep": return Color("Sleep")
        case "Other": return .black
        default: return theme.accent
        }
    }
    
    private var activityType: String {
        return log.activity?.activityType ?? "Activity"
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Title
            Text(log.activityNameAtCompletion)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(theme.primaryText)
            
            // Content - use description at completion or user notes
            if let description = log.descriptionAtCompletion, !description.isEmpty {
                Text("\(Image(systemName: "text.append")) \(description)")
                    .font(.system(size: 16))
                    .foregroundColor(theme.secondaryText)
                    .lineLimit(3)
            } else if let notes = log.userNotesOnCompletion, !notes.isEmpty {
                Text("\(Image(systemName: "note.text")) \(notes)")
                    .font(.system(size: 16))
                    .foregroundColor(theme.secondaryText)
                    .lineLimit(3)
            } else {
                Text("\(Image(systemName: "checkmark.circle.fill")) Completed successfully")
                    .font(.system(size: 16))
                    .foregroundColor(theme.secondaryText)
            }
            
            // Activity type tag and points
            HStack {
                TagView(category: log.activity?.category.first ?? "Other", displayText: activityType)
                
                Spacer()
                
                // Points awarded
                HStack(spacing: 4) {
                    Image(systemName: "star.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.yellow)
                    Text("\(log.pointsAwarded)")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(theme.secondaryText)
                }
            }
            
            // Footer
            HStack {
                Text(formattedDate)
                    .font(.system(size: 14))
                    .foregroundColor(theme.secondaryText)
                
                Spacer()
                
                Button(action: { showingMenu = true }) {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 16))
                        .foregroundColor(theme.secondaryText)
                        .frame(width: 30, height: 30)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .fill(theme.background)
                .shadow(color: theme.defaultShadow.color, radius: theme.defaultShadow.radius, x: theme.defaultShadow.x, y: theme.defaultShadow.y)
        )
    }
}

// MARK: - State Views
private struct LoadingStateView: View {
    @Environment(\.theme) private var theme: any Theme
    
    var body: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.2)
                .tint(theme.accent)
            
            Text("Loading your activities...")
                .font(.system(size: 16))
                .foregroundColor(theme.secondaryText)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 200)
    }
}

private struct ErrorStateVie5ws: View {
    let message: String
    let onRetry: () -> Void
    @Environment(\.theme) private var theme: any Theme
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundColor(theme.secondaryText)
            
            Text(message)
                .font(.system(size: 16))
                .foregroundColor(theme.secondaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Button(action: onRetry) {
                Text("Try Again")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(theme.accent, in: .capsule)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 200)
    }
}

private struct EmptyStateView: View {
    @Environment(\.theme) private var theme: any Theme
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 48))
                .foregroundColor(theme.secondaryText)
            
            Text("No completed activities yet")
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(theme.primaryText)
            
            Text("Start completing activities to see them appear here in your journey.")
                .font(.system(size: 16))
                .foregroundColor(theme.secondaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 200)
    }
}



// MARK: - Combined Nutrition Card
private struct CombinedNutritionCard: View {
    @Environment(\.theme) private var theme: any Theme
    @Binding var isSimpleView: Bool
    let contentOpacity: Double
    
    // Mock data - combining calories and macros
    // TODO: Integrate with NutritionViewModel or AuthenticationManager to get real nutrition data
    private let caloriesEaten: Int = 750
    private let caloriesGoal: Int = 2000
    private let caloriesLeft: Int = 1250
    private let carbsEaten: Double = 125.0
    private let carbsGoal: Double = 250.0
    private let proteinEaten: Double = 85.0
    private let proteinGoal: Double = 125.0
    private let fatEaten: Double = 35.0
    private let fatGoal: Double = 55.0
    
    // All dials use Nutrition color
    private let nutritionColor = Color("Nutrition")
    
    private var calorieProgress: Double {
        guard caloriesGoal > 0 else { return 0 }
        return Double(caloriesEaten) / Double(caloriesGoal)
    }
    
    var body: some View {
        Group {
            if isSimpleView {
                // Simple view - with consistent height
                HStack(spacing: 20) {
                    // Left side: Calories left text
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(caloriesLeft)")
                            .font(.system(size: 36, weight: .bold))
                            .foregroundColor(theme.primaryText)
                        
                        Text("Calories left")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(theme.secondaryText)
                        
                        // Add "out of ___" text
                        Text("out of \(caloriesGoal)")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(theme.secondaryText.opacity(0.7))
                    }
                    .opacity(contentOpacity)
                    
                    Spacer()
                    
                    // Right side: Dial progress indicator
                    ZStack {
                        // Background circle
                        Circle()
                            .stroke(Color.gray.opacity(0.2), lineWidth: 8)
                            .frame(width: 80, height: 80)
                        
                        // Progress circle
                        Circle()
                            .trim(from: 0, to: calorieProgress)
                            .stroke(
                                LinearGradient(
                                    gradient: Gradient(colors: [nutritionColor, nutritionColor.opacity(0.7)]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                style: StrokeStyle(lineWidth: 8, lineCap: .round)
                            )
                            .frame(width: 80, height: 80)
                            .rotationEffect(.degrees(-90))
                            .animation(.easeInOut(duration: 0.5), value: calorieProgress)
                        
                        // Fire icon in center
                        Image(systemName: "flame.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.black)
                    }
                    .opacity(contentOpacity)
                }
                .padding()
                .frame(height: 160) // Fixed height to match complex view
            } else {
                // Complex view - all four dials with fixed height
                HStack(spacing: 15) {
                    // Calories dial with fire icon
                    CombinedNutritionDialView(
                        name: "Calories",
                        eaten: Double(caloriesEaten),
                        goal: Double(caloriesGoal),
                        color: nutritionColor,
                        unit: "",
                        showIcon: true,
                        iconName: "flame.fill"
                    )
                    .frame(maxWidth: .infinity)
                    
                    CombinedNutritionDialView(
                        name: "Carbs",
                        eaten: carbsEaten,
                        goal: carbsGoal,
                        color: nutritionColor,
                        unit: "g",
                        showIcon: false
                    )
                    .frame(maxWidth: .infinity)
                    
                    CombinedNutritionDialView(
                        name: "Protein",
                        eaten: proteinEaten,
                        goal: proteinGoal,
                        color: nutritionColor,
                        unit: "g",
                        showIcon: false
                    )
                    .frame(maxWidth: .infinity)
                    
                    CombinedNutritionDialView(
                        name: "Fat",
                        eaten: fatEaten,
                        goal: fatGoal,
                        color: nutritionColor,
                        unit: "g",
                        showIcon: false
                    )
                    .frame(maxWidth: .infinity)
                }
                .opacity(contentOpacity)
                .padding()
                .frame(height: 160) // Fixed height to match simple view
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .fill(theme.background)
                .shadow(color: theme.defaultShadow.color.opacity(0.8), radius: theme.defaultShadow.radius * 1.5, x: theme.defaultShadow.x, y: theme.defaultShadow.y * 1.5)
        )
        .padding(.horizontal)
    }
}

// MARK: - Combined Nutrition Dial View
private struct CombinedNutritionDialView: View {
    @Environment(\.theme) private var theme: any Theme
    let name: String
    let eaten: Double
    let goal: Double
    let color: Color
    let unit: String
    let showIcon: Bool
    let iconName: String?
    
    init(name: String, eaten: Double, goal: Double, color: Color, unit: String, showIcon: Bool, iconName: String? = nil) {
        self.name = name
        self.eaten = eaten
        self.goal = goal
        self.color = color
        self.unit = unit
        self.showIcon = showIcon
        self.iconName = iconName
    }
    
    private var progress: Double {
        guard goal > 0 else { return 0 }
        return min(eaten / goal, 1.0)
    }
    
    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                // Background circle
                Circle()
                    .stroke(Color.gray.opacity(0.2), lineWidth: 6)
                    .frame(width: 60, height: 60)
                
                // Progress circle
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(color, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .frame(width: 60, height: 60)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.5), value: progress)
                
                // Center content - either icon or text
                if showIcon, let iconName = iconName {
                    Image(systemName: iconName)
                        .font(.system(size: 16))
                        .foregroundColor(.black)
                } else {
                    Text(String(format: "%.0f%@", eaten, unit))
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(theme.primaryText)
                }
            }
            
            Text(name)
                .font(.headline)
                .fontWeight(.medium)
                .foregroundColor(theme.primaryText)
            
            if showIcon {
                Text(String(format: "%.0f of %.0f", eaten, goal))
                    .font(.caption2)
                    .foregroundColor(theme.secondaryText)
            } else {
                Text(String(format: "of %.0f%@", goal, unit))
                    .font(.caption2)
                    .foregroundColor(theme.secondaryText)
            }
        }
    }
}

// MARK: - Sleep Overview Card
private struct SleepOverviewCard: View {
    @Environment(\.theme) private var theme: any Theme
    @Binding var isSimpleView: Bool
    let contentOpacity: Double
    
    // Mock sleep data
    // TODO: Integrate with SleepViewModel or AuthenticationManager to get real sleep data
    private let sleepScore: Int = 85
    private let maxSleepScore: Int = 100
    private let timeSleptHours: Double = 7.5
    private let timeSleptGoal: Double = 8.0
    private let remSleepHours: Double = 1.8
    private let deepSleepHours: Double = 1.2
    private let consistency: Int = 78
    private let maxConsistency: Int = 100
    private let weekAverageHours: Double = 7.2
    private let weekAverageGoal: Double = 8.0
    
    // Sleep color
    private let sleepColor = Color("Sleep")
    
    private var sleepProgress: Double {
        guard maxSleepScore > 0 else { return 0 }
        return Double(sleepScore) / Double(maxSleepScore)
    }
    
    var body: some View {
        Group {
            if isSimpleView {
                // Simple view - sleep score only
                HStack(spacing: 20) {
                    // Left side: Sleep score text
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(sleepScore)")
                            .font(.system(size: 36, weight: .bold))
                            .foregroundColor(theme.primaryText)
                        
                        Text("Sleep Score")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(theme.secondaryText)
                        
                        Text("out of \(maxSleepScore)")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(theme.secondaryText.opacity(0.7))
                    }
                    .opacity(contentOpacity)
                    
                    Spacer()
                    
                    // Right side: Dial progress indicator
                    ZStack {
                        // Background circle
                        Circle()
                            .stroke(Color.gray.opacity(0.2), lineWidth: 8)
                            .frame(width: 80, height: 80)
                        
                        // Progress circle
                        Circle()
                            .trim(from: 0, to: sleepProgress)
                            .stroke(
                                LinearGradient(
                                    gradient: Gradient(colors: [sleepColor, sleepColor.opacity(0.7)]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                style: StrokeStyle(lineWidth: 8, lineCap: .round)
                            )
                            .frame(width: 80, height: 80)
                            .rotationEffect(.degrees(-90))
                            .animation(.easeInOut(duration: 0.5), value: sleepProgress)
                        
                        // Sleep icon in center
                        Image(systemName: "moon.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.black)
                    }
                    .opacity(contentOpacity)
            }
                .padding()
                .frame(height: 160)
            } else {
                // Complex view - all four sleep metrics
                HStack(spacing: 15) {
                    // Sleep Score dial
                    SleepDialView(
                        name: "Score",
                        current: Double(sleepScore),
                        goal: Double(maxSleepScore),
                        color: sleepColor,
                        unit: "",
                        showIcon: true,
                        iconName: "moon.fill"
                    )
                    .frame(maxWidth: .infinity)
                    
                    // Time slept with REM/Deep breakdown
                    SleepBreakdownDialView(
                        name: "Time Slept",
                        totalHours: timeSleptHours,
                        goalHours: timeSleptGoal,
                        remHours: remSleepHours,
                        deepHours: deepSleepHours,
                        color: sleepColor
                    )
                    .frame(maxWidth: .infinity)
                    
                    SleepDialView(
                        name: "Consistency",
                        current: Double(consistency),
                        goal: Double(maxConsistency),
                        color: sleepColor,
                        unit: "%",
                        showIcon: false
                    )
                    .frame(maxWidth: .infinity)
                    
                    SleepDialView(
                        name: "Avg/Week",
                        current: weekAverageHours,
                        goal: weekAverageGoal,
                        color: sleepColor,
                        unit: "h",
                        showIcon: false
                    )
                    .frame(maxWidth: .infinity)
                }
                .opacity(contentOpacity)
                .padding()
                .frame(height: 160)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .fill(theme.background)
                .shadow(color: theme.defaultShadow.color.opacity(0.8), radius: theme.defaultShadow.radius * 1.5, x: theme.defaultShadow.x, y: theme.defaultShadow.y * 1.5)
        )
        .padding(.horizontal)
    }
}

// MARK: - Sleep Dial View
private struct SleepDialView: View {
    @Environment(\.theme) private var theme: any Theme
    let name: String
    let current: Double
    let goal: Double
    let color: Color
    let unit: String
    let showIcon: Bool
    let iconName: String?
    
    init(name: String, current: Double, goal: Double, color: Color, unit: String, showIcon: Bool, iconName: String? = nil) {
        self.name = name
        self.current = current
        self.goal = goal
        self.color = color
        self.unit = unit
        self.showIcon = showIcon
        self.iconName = iconName
    }
    
    private var progress: Double {
        guard goal > 0 else { return 0 }
        return min(current / goal, 1.0)
    }
    
    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                // Background circle
                Circle()
                    .stroke(Color.gray.opacity(0.2), lineWidth: 6)
                    .frame(width: 60, height: 60)
                
                // Progress circle
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(color, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .frame(width: 60, height: 60)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.5), value: progress)
                
                // Center content - either icon or text
                if showIcon, let iconName = iconName {
                    Image(systemName: iconName)
                        .font(.system(size: 16))
                        .foregroundColor(.black)
                } else {
                    Text(String(format: "%.0f%@", current, unit))
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(theme.primaryText)
                }
            }
            
            Text(name)
                .font(.headline)
                .fontWeight(.medium)
                .foregroundColor(theme.primaryText)
            
            if showIcon {
                Text(String(format: "%.0f of %.0f", current, goal))
                    .font(.caption2)
                    .foregroundColor(theme.secondaryText)
            } else {
                Text(String(format: "of %.0f%@", goal, unit))
                    .font(.caption2)
                    .foregroundColor(theme.secondaryText)
    }
        }
    }
}

// MARK: - Sleep Breakdown Dial View
private struct SleepBreakdownDialView: View {
    @Environment(\.theme) private var theme: any Theme
    let name: String
    let totalHours: Double
    let goalHours: Double
    let remHours: Double
    let deepHours: Double
    let color: Color
    
    private var progress: Double {
        guard goalHours > 0 else { return 0 }
        return min(totalHours / goalHours, 1.0)
    }
    
    // Calculate proportions of sleep stages
    private var remProgress: Double {
        guard totalHours > 0 else { return 0 }
        return (remHours / totalHours) * progress
    }
    
    private var deepProgress: Double {
        guard totalHours > 0 else { return 0 }
        return (deepHours / totalHours) * progress
    }
    
    private var lightProgress: Double {
        let lightHours = totalHours - remHours - deepHours
        guard totalHours > 0, lightHours > 0 else { return 0 }
        return (lightHours / totalHours) * progress
    }
    
    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                // Background circle
                Circle()
                    .stroke(Color.gray.opacity(0.2), lineWidth: 6)
                    .frame(width: 60, height: 60)
                
                // Light sleep (remainder) - lightest shade
                Circle()
                    .trim(from: 0, to: lightProgress)
                    .stroke(color.opacity(0.3), style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .frame(width: 60, height: 60)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.5), value: lightProgress)
                
                // Deep sleep - darker shade
                Circle()
                    .trim(from: lightProgress, to: lightProgress + deepProgress)
                    .stroke(color.opacity(0.7), style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .frame(width: 60, height: 60)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.5), value: deepProgress)
                
                // REM sleep - darkest shade
                Circle()
                    .trim(from: lightProgress + deepProgress, to: progress)
                    .stroke(color, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .frame(width: 60, height: 60)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.5), value: remProgress)
                
                // Center content - total hours
                Text(String(format: "%.1fh", totalHours))
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(theme.primaryText)
            }
            
            Text(name)
                .font(.headline)
                .fontWeight(.medium)
                .foregroundColor(theme.primaryText)
            
            Text("R:\(String(format: "%.1f", remHours)) D:\(String(format: "%.1f", deepHours))")
                .font(.caption2)
                .foregroundColor(theme.secondaryText)
        }
    }
}

// MARK: - Fitness Overview Card
private struct FitnessOverviewCard: View {
    @Environment(\.theme) private var theme: any Theme
    @Binding var isSimpleView: Bool
    let contentOpacity: Double
    
    // Mock fitness data
    // TODO: Integrate with FitnessViewModel or AuthenticationManager to get real fitness data
    private let stepCount: Int = 8247
    private let stepGoal: Int = 10000
    private let exerciseMinutes: Int = 45
    private let exerciseGoal: Int = 60
    private let weekMiles: Double = 12.5
    private let weekMilesGoal: Double = 20.0
    private let caloriesBurned: Int = 420
    private let caloriesBurnedGoal: Int = 500
    
    // Fitness color
    private let fitnessColor = Color("Fitness")
    
    private var stepProgress: Double {
        guard stepGoal > 0 else { return 0 }
        return Double(stepCount) / Double(stepGoal)
    }
    
    var body: some View {
        Group {
            if isSimpleView {
                // Simple view - step count only
                HStack(spacing: 20) {
                    // Left side: Step count text
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(stepCount)")
                            .font(.system(size: 36, weight: .bold))
                            .foregroundColor(theme.primaryText)
                        
                        Text("Steps today")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(theme.secondaryText)
                        
                        Text("out of \(stepGoal)")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(theme.secondaryText.opacity(0.7))
                    }
                    .opacity(contentOpacity)
                    
                    Spacer()
                    
                    // Right side: Dial progress indicator
                    ZStack {
                        // Background circle
                        Circle()
                            .stroke(Color.gray.opacity(0.2), lineWidth: 8)
                            .frame(width: 80, height: 80)
                        
                        // Progress circle
                        Circle()
                            .trim(from: 0, to: stepProgress)
                            .stroke(
                                LinearGradient(
                                    gradient: Gradient(colors: [fitnessColor, fitnessColor.opacity(0.7)]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                style: StrokeStyle(lineWidth: 8, lineCap: .round)
                            )
                            .frame(width: 80, height: 80)
                            .rotationEffect(.degrees(-90))
                            .animation(.easeInOut(duration: 0.5), value: stepProgress)
                        
                        // Steps icon in center
                        Image(systemName: "figure.walk")
                            .font(.system(size: 24))
                            .foregroundColor(.black)
                    }
                    .opacity(contentOpacity)
                }
                .padding()
                .frame(height: 160)
            } else {
                // Complex view - all four fitness metrics
                HStack(spacing: 15) {
                    // Steps dial
                    FitnessDialView(
                        name: "Steps",
                        current: Double(stepCount),
                        goal: Double(stepGoal),
                        color: fitnessColor,
                        unit: "",
                        showIcon: true,
                        iconName: "figure.walk"
                    )
                    .frame(maxWidth: .infinity)
                    
                    FitnessDialView(
                        name: "Exercise",
                        current: Double(exerciseMinutes),
                        goal: Double(exerciseGoal),
                        color: fitnessColor,
                        unit: "min",
                        showIcon: false
                    )
                    .frame(maxWidth: .infinity)
                    
                    FitnessDialView(
                        name: "Miles",
                        current: weekMiles,
                        goal: weekMilesGoal,
                        color: fitnessColor,
                        unit: "mi",
                        showIcon: false
                    )
                    .frame(maxWidth: .infinity)
                    
                    FitnessDialView(
                        name: "Burned",
                        current: Double(caloriesBurned),
                        goal: Double(caloriesBurnedGoal),
                        color: fitnessColor,
                        unit: "cal",
                        showIcon: false
                    )
                    .frame(maxWidth: .infinity)
                }
                .opacity(contentOpacity)
                .padding()
                .frame(height: 160)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .fill(theme.background)
                .shadow(color: theme.defaultShadow.color.opacity(0.8), radius: theme.defaultShadow.radius * 1.5, x: theme.defaultShadow.x, y: theme.defaultShadow.y * 1.5)
        )
        .padding(.horizontal)
        }
    }
    
// MARK: - Fitness Dial View
private struct FitnessDialView: View {
    @Environment(\.theme) private var theme: any Theme
    let name: String
    let current: Double
    let goal: Double
    let color: Color
    let unit: String
    let showIcon: Bool
    let iconName: String?
    
    init(name: String, current: Double, goal: Double, color: Color, unit: String, showIcon: Bool, iconName: String? = nil) {
        self.name = name
        self.current = current
        self.goal = goal
        self.color = color
        self.unit = unit
        self.showIcon = showIcon
        self.iconName = iconName
    }
    
    private var progress: Double {
        guard goal > 0 else { return 0 }
        return min(current / goal, 1.0)
    }
    
    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                // Background circle
                Circle()
                    .stroke(Color.gray.opacity(0.2), lineWidth: 6)
                    .frame(width: 60, height: 60)
                
                // Progress circle
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(color, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .frame(width: 60, height: 60)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.5), value: progress)
                
                // Center content - either icon or text
                if showIcon, let iconName = iconName {
                    Image(systemName: iconName)
                        .font(.system(size: 16))
                        .foregroundColor(.black)
                } else {
                    Text(String(format: "%.0f%@", current, unit))
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(theme.primaryText)
                }
            }
            
            Text(name)
                .font(.headline)
                .fontWeight(.medium)
                .foregroundColor(theme.primaryText)
            
            if showIcon {
                Text(String(format: "%.0f of %.0f", current, goal))
                    .font(.caption2)
                    .foregroundColor(theme.secondaryText)
            } else {
                Text(String(format: "of %.0f%@", goal, unit))
                    .font(.caption2)
                    .foregroundColor(theme.secondaryText)
        }
    }
    }
}

// MARK: - Mind Overview Card
private struct MindOverviewCard: View {
    @Environment(\.theme) private var theme: any Theme
    @Binding var isSimpleView: Bool
    let contentOpacity: Double
    
    // Mock mind/wellness data
    // TODO: Integrate with MindfulnessViewModel or AuthenticationManager to get real mind data
    private let activeMinutes: Int = 25
    private let activeMinutesGoal: Int = 30
    private let weeklyMeditations: Int = 4
    private let weeklyMeditationsGoal: Int = 7
    private let weeklyBreathingExercises: Int = 6
    private let weeklyBreathingGoal: Int = 10
    private let weeklyJournalEntries: Int = 3
    private let weeklyJournalGoal: Int = 5
    
    // Mind color
    private let mindColor = Color("Mind")
    
    private var activeMinutesProgress: Double {
        guard activeMinutesGoal > 0 else { return 0 }
        return Double(activeMinutes) / Double(activeMinutesGoal)
    }
    
    var body: some View {
        Group {
            if isSimpleView {
                // Simple view - active minutes only
                HStack(spacing: 20) {
                    // Left side: Active minutes text
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(activeMinutes)")
                            .font(.system(size: 36, weight: .bold))
                            .foregroundColor(theme.primaryText)
                        
                        Text("Active minutes")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(theme.secondaryText)
                        
                        Text("out of \(activeMinutesGoal)")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(theme.secondaryText.opacity(0.7))
                    }
                    .opacity(contentOpacity)
            
            Spacer()
            
                    // Right side: Dial progress indicator
                    ZStack {
                        // Background circle
                        Circle()
                            .stroke(Color.gray.opacity(0.2), lineWidth: 8)
                            .frame(width: 80, height: 80)
                        
                        // Progress circle
                        Circle()
                            .trim(from: 0, to: activeMinutesProgress)
                            .stroke(
                                LinearGradient(
                                    gradient: Gradient(colors: [mindColor, mindColor.opacity(0.7)]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                style: StrokeStyle(lineWidth: 8, lineCap: .round)
                            )
                            .frame(width: 80, height: 80)
                            .rotationEffect(.degrees(-90))
                            .animation(.easeInOut(duration: 0.5), value: activeMinutesProgress)
                        
                        // Mind icon in center
                        Image(systemName: "brain.head.profile")
                            .font(.system(size: 24))
                            .foregroundColor(.black)
                    }
                    .opacity(contentOpacity)
                }
                .padding()
                .frame(height: 160)
            } else {
                // Complex view - all four mind metrics
                HStack(spacing: 15) {
                    // Active minutes dial
                    MindDialView(
                        name: "Active",
                        current: Double(activeMinutes),
                        goal: Double(activeMinutesGoal),
                        color: mindColor,
                        unit: "min",
                        showIcon: true,
                        iconName: "brain.head.profile"
                    )
                    .frame(maxWidth: .infinity)
                    
                    MindDialView(
                        name: "Meditations",
                        current: Double(weeklyMeditations),
                        goal: Double(weeklyMeditationsGoal),
                        color: mindColor,
                        unit: "",
                        showIcon: false
                    )
                    .frame(maxWidth: .infinity)
                    
                    MindDialView(
                        name: "Breathing",
                        current: Double(weeklyBreathingExercises),
                        goal: Double(weeklyBreathingGoal),
                        color: mindColor,
                        unit: "",
                        showIcon: false
                    )
                    .frame(maxWidth: .infinity)
                    
                    MindDialView(
                        name: "Journal",
                        current: Double(weeklyJournalEntries),
                        goal: Double(weeklyJournalGoal),
                        color: mindColor,
                        unit: "",
                        showIcon: false
                    )
                    .frame(maxWidth: .infinity)
                }
                .opacity(contentOpacity)
                .padding()
                .frame(height: 160)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .fill(theme.background)
                .shadow(color: theme.defaultShadow.color.opacity(0.8), radius: theme.defaultShadow.radius * 1.5, x: theme.defaultShadow.x, y: theme.defaultShadow.y * 1.5)
        )
        .padding(.horizontal)
    }
}

// MARK: - Mind Dial View
private struct MindDialView: View {
    @Environment(\.theme) private var theme: any Theme
    let name: String
    let current: Double
    let goal: Double
    let color: Color
    let unit: String
    let showIcon: Bool
    let iconName: String?
    
    init(name: String, current: Double, goal: Double, color: Color, unit: String, showIcon: Bool, iconName: String? = nil) {
        self.name = name
        self.current = current
        self.goal = goal
        self.color = color
        self.unit = unit
        self.showIcon = showIcon
        self.iconName = iconName
    }
    
    private var progress: Double {
        guard goal > 0 else { return 0 }
        return min(current / goal, 1.0)
    }
    
    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                // Background circle
                Circle()
                    .stroke(Color.gray.opacity(0.2), lineWidth: 6)
                    .frame(width: 60, height: 60)
                
                // Progress circle
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(color, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .frame(width: 60, height: 60)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.5), value: progress)
                
                // Center content - either icon or text
                if showIcon, let iconName = iconName {
                    Image(systemName: iconName)
                        .font(.system(size: 16))
                        .foregroundColor(.black)
                } else {
                    Text(String(format: "%.0f%@", current, unit))
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(theme.primaryText)
                }
            }
            
            Text(name)
                .font(.headline)
                .fontWeight(.medium)
                .foregroundColor(theme.primaryText)
            
            if showIcon {
                Text(String(format: "%.0f of %.0f%@", current, goal, unit))
                    .font(.caption2)
                    .foregroundColor(theme.secondaryText)
            } else {
                Text(String(format: "of %.0f%@", goal, unit))
                    .font(.caption2)
                    .foregroundColor(theme.secondaryText)
            }
        }
    }
}

// MARK: - Stats View
private struct StatsView: View {
    let headerView: AnyView?
    @Environment(\.theme) private var theme: any Theme
    
    init(headerView: AnyView? = nil) {
        self.headerView = headerView
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header if provided
                if let headerView = headerView {
                    headerView
                }
                
                // My Evolve Section
                MyEvolveSection()
                
                // My Trackers Section
                MyTrackersSection()
        }
            .padding(.bottom, 100) // Space for tab bar
        }
    }
}

// MARK: - Compressed Overview Card
private struct CompressedOverviewCard: View {
    @Environment(\.theme) private var theme: any Theme
    
    // Mock data from all categories
    private let caloriesLeft: Int = 1250
    private let caloriesGoal: Int = 2000
    private let sleepScore: Int = 85
    private let maxSleepScore: Int = 100
    private let stepCount: Int = 8247
    private let stepGoal: Int = 10000
    private let activeMinutes: Int = 25
    private let activeMinutesGoal: Int = 30
    
    // Colors for each category
    private let nutritionColor = Color("Nutrition")
    private let sleepColor = Color("Sleep")
    private let fitnessColor = Color("Fitness")
    private let mindColor = Color("Mind")
    
    var body: some View {
        HStack(spacing: 15) {
            // Nutrition - Calories Left Dial
            CompressedDialView(
                name: "Calories left",
                current: Double(2000 - caloriesLeft), // calories eaten
                goal: Double(caloriesGoal),
                remaining: caloriesLeft,
                color: nutritionColor,
                unit: "",
                showIcon: true,
                iconName: "flame.fill"
            )
            .frame(maxWidth: .infinity)
            
            // Sleep - Sleep Score Dial
            CompressedDialView(
                name: "Sleep Score",
                current: Double(sleepScore),
                goal: Double(maxSleepScore),
                remaining: nil,
                color: sleepColor,
                unit: "",
                showIcon: true,
                iconName: "moon.fill"
            )
            .frame(maxWidth: .infinity)
            
            // Fitness - Steps Dial
            CompressedDialView(
                name: "Steps today",
                current: Double(stepCount),
                goal: Double(stepGoal),
                remaining: nil,
                color: fitnessColor,
                unit: "",
                showIcon: true,
                iconName: "figure.walk"
            )
            .frame(maxWidth: .infinity)
            
            // Mind - Active Minutes Dial
            CompressedDialView(
                name: "Active minutes",
                current: Double(activeMinutes),
                goal: Double(activeMinutesGoal),
                remaining: nil,
                color: mindColor,
                unit: "min",
                showIcon: true,
                iconName: "brain.head.profile"
            )
            .frame(maxWidth: .infinity)
        }
        .padding()
        .frame(height: 160)
        .background(
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .fill(theme.background)
                .shadow(color: theme.defaultShadow.color.opacity(0.8), radius: theme.defaultShadow.radius * 1.5, x: theme.defaultShadow.x, y: theme.defaultShadow.y * 1.5)
        )
        .padding(.horizontal)
    }
}

// MARK: - Compressed Dial View
private struct CompressedDialView: View {
    @Environment(\.theme) private var theme: any Theme
    let name: String
    let current: Double
    let goal: Double
    let remaining: Int?
    let color: Color
    let unit: String
    let showIcon: Bool
    let iconName: String?
    
    init(name: String, current: Double, goal: Double, remaining: Int?, color: Color, unit: String, showIcon: Bool, iconName: String? = nil) {
        self.name = name
        self.current = current
        self.goal = goal
        self.remaining = remaining
        self.color = color
        self.unit = unit
        self.showIcon = showIcon
        self.iconName = iconName
    }
    
    private var progress: Double {
        guard goal > 0 else { return 0 }
        return min(current / goal, 1.0)
    }
    
    var body: some View {
        VStack(spacing: 12) {
            // Dial with icon/text in center
            ZStack {
                // Background circle
                Circle()
                    .stroke(Color.gray.opacity(0.2), lineWidth: 6)
                    .frame(width: 60, height: 60)
                
                // Progress circle
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(
                        LinearGradient(
                            gradient: Gradient(colors: [color, color.opacity(0.7)]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        style: StrokeStyle(lineWidth: 6, lineCap: .round)
                    )
                    .frame(width: 60, height: 60)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.5), value: progress)
                
                // Center content - icon for all dials
                if let iconName = iconName {
                    Image(systemName: iconName)
                        .font(.system(size: 18))
                        .foregroundColor(.black)
                }
            }
            
            // Category name
            Text(name)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(theme.primaryText)
                .lineLimit(2)
                .multilineTextAlignment(.center)
            
            // Totals
            if let remaining = remaining {
                // For calories left - show remaining
                Text("\(remaining) left")
                    .font(.system(size: 12))
                    .foregroundColor(theme.secondaryText)
            } else {
                // For other metrics - show current out of goal
                Text("\(Int(current)) of \(Int(goal))\(unit)")
                    .font(.system(size: 12))
                    .foregroundColor(theme.secondaryText)
            }
        }
    }
}

// MARK: - Flippable Card
private struct FlippableCard<Content: View>: View {
    @Binding var isSimple: Bool
    @State private var contentOpacity: Double = 1.0
    @State private var flipRotation: Double = 0.0
    @State private var isAnimating: Bool = false
    let content: (Double) -> Content
    
    init(isSimple: Binding<Bool>, @ViewBuilder content: @escaping (Double) -> Content) {
        self._isSimple = isSimple
        self.content = content
    }
    
    var body: some View {
        content(contentOpacity)
            .rotation3DEffect(.degrees(flipRotation), axis: (x: 1.0, y: 0.0, z: 0.0))
            .contentShape(Rectangle())
            .onTapGesture {
                let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                impactFeedback.impactOccurred()
                
                guard !isAnimating else { return }
                
                isAnimating = true
                
                // Phase 1: Fade out while flipping to 90 degrees
                withAnimation(.easeInOut(duration: 0.3)) {
                    contentOpacity = 0.0
                    flipRotation = 90.0
                }
                
                // Phase 2: Switch content at midpoint, continue flip from -90 to 0 while fading in
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    isSimple.toggle()
                    flipRotation = -90.0
                    contentOpacity = 0.0
                    
                    withAnimation(.easeInOut(duration: 0.3)) {
                        contentOpacity = 1.0
                        flipRotation = 0.0
                    }
                    
                    // Reset animating
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        isAnimating = false
                    }
                }
            }
    }
}

// MARK: - Overview Section  
private struct OverviewSection: View {
    @Environment(\.theme) private var theme: any Theme
    @State private var nutritionIsSimple: Bool = true
    @State private var sleepIsSimple: Bool = true
    @State private var fitnessIsSimple: Bool = true  
    @State private var mindIsSimple: Bool = true
    @State private var isCompressed: Bool = true
    @State private var cardOffsets: [CGFloat] = [0, 180, 360, 540] // Initial expanded offsets
    
    private let expandedOffsets: [CGFloat] = [0, 180, 360, 540]
    private let compressedOffsets: [CGFloat] = [0, 0, 0, 0]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Header with chevron toggle
            HStack {
                Text("Overview")
                    .font(.system(size: 21, weight: .semibold))
                    .foregroundColor(theme.primaryText)
                
                Spacer()
                
                Button(action: {
                    let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                    impactFeedback.impactOccurred()
                    
                    animateStacking(toCompressed: !isCompressed)
                }) {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(theme.primaryText)
                        .rotationEffect(.degrees(isCompressed ? -90 : 0))
                        .animation(.easeInOut(duration: 0.3), value: isCompressed)
                }
            }
            .padding(.horizontal)
            
            if isCompressed {
                // Compressed state - single card with all metrics
                CompressedOverviewCard()
                    .transition(.opacity.animation(.easeInOut(duration: 0.3)))
            } else {
                // Expanded state - individual cards with sequential stacking animation
                ZStack {
                    ForEach(Array(0..<4), id: \.self) { index in
                        Group {
                            switch index {
                            case 0:
                                FlippableCard(isSimple: $nutritionIsSimple) { contentOpacity in
                                    CombinedNutritionCard(isSimpleView: $nutritionIsSimple, contentOpacity: contentOpacity)
                                }
                            case 1:
                                FlippableCard(isSimple: $sleepIsSimple) { contentOpacity in
                                    SleepOverviewCard(isSimpleView: $sleepIsSimple, contentOpacity: contentOpacity)
                                }
                            case 2:
                                FlippableCard(isSimple: $fitnessIsSimple) { contentOpacity in
                                    FitnessOverviewCard(isSimpleView: $fitnessIsSimple, contentOpacity: contentOpacity)
                                }
                            case 3:
                                FlippableCard(isSimple: $mindIsSimple) { contentOpacity in
                                    MindOverviewCard(isSimpleView: $mindIsSimple, contentOpacity: contentOpacity)
                                }
                            default:
                                EmptyView()
                            }
                        }
                        .offset(y: cardOffsets[index])
                        .zIndex(Double(3 - index))
                    }
                }
                .frame(minHeight: 700, alignment: .top)
                .contentShape(Rectangle())
                .transition(.opacity.animation(.easeInOut(duration: 0.3)))
            }
        }
    }
    
    private func animateStacking(toCompressed: Bool) {
        let duration: Double = 0.2
        let delayBetweenSteps: Double = 0.1
        
        if toCompressed {
            // Compression: Animate stacking first, then set isCompressed
            DispatchQueue.main.asyncAfter(deadline: .now() + delayBetweenSteps * 0) {
                withAnimation(.easeInOut(duration: duration)) {
                    cardOffsets[3] = expandedOffsets[2]
                }
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + delayBetweenSteps * 1) {
                withAnimation(.easeInOut(duration: duration)) {
                    cardOffsets[2] = expandedOffsets[1]
                    cardOffsets[3] = expandedOffsets[1]
                }
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + delayBetweenSteps * 2) {
                withAnimation(.easeInOut(duration: duration)) {
                    cardOffsets[1] = expandedOffsets[0]
                    cardOffsets[2] = expandedOffsets[0]
                    cardOffsets[3] = expandedOffsets[0]
                }
            }
            
            // Show compressed content faster - halfway through the final stacking animation
            let compressedContentTime = delayBetweenSteps * 2 + duration * 0.1
            DispatchQueue.main.asyncAfter(deadline: .now() + compressedContentTime) {
                isCompressed = true
            }
        } else {
            // Expansion: Set isCompressed first, then animate unstacking
            isCompressed = false
            
            DispatchQueue.main.asyncAfter(deadline: .now() + delayBetweenSteps * 0) {
                withAnimation(.easeInOut(duration: duration)) {
                    cardOffsets[1] = expandedOffsets[1]
                    cardOffsets[2] = expandedOffsets[1]
                    cardOffsets[3] = expandedOffsets[1]
                }
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + delayBetweenSteps * 1) {
                withAnimation(.easeInOut(duration: duration)) {
                    cardOffsets[2] = expandedOffsets[2]
                    cardOffsets[3] = expandedOffsets[2]
                }
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + delayBetweenSteps * 2) {
                withAnimation(.easeInOut(duration: duration)) {
                    cardOffsets[3] = expandedOffsets[3]
                }
            }
        }
    }
}

// MARK: - My Evolve Section
private struct MyEvolveSection: View {
    @Environment(\.theme) private var theme: any Theme
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Header with action button
            HStack {
                Text("My Evolve")
                    .font(.system(size: 21, weight: .semibold))
                    .foregroundColor(theme.primaryText)
                
                Spacer()

                Menu {
                    Button("Add New", action: {
                        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                        impactFeedback.impactOccurred()
                        // TODO: Add new tracker functionality
                    })
                    
                    Button("Edit", action: {
                        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                        impactFeedback.impactOccurred()
                        // TODO: Edit trackers functionality
                    })
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(theme.primaryText)
                }
                
                
            }
            .padding(.horizontal)
            
            // Cards for My Goals, My Plans, My Custom Routines
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    MyEvolveCard(
                        title: "My Goals",
                        icon: "target",
                        color: Color("Fitness"),
                        action: {
                            // TODO: Navigate to My Goals
                        }
                    )
                    
                    MyEvolveCard(
                        title: "My Plans",
                        icon: "calendar.badge.clock",
                        color: Color("Mind"),
                        action: {
                            // TODO: Navigate to My Plans
                        }
                    )
                    
                    MyEvolveCard(
                        title: "My Routines",
                        icon: "repeat.circle",
                        color: Color("Sleep"),
                        action: {
                            // TODO: Navigate to Custom Routines
                        }
                    )
                }
                .padding(.horizontal)
            }
        }
    }
}

// MARK: - My Evolve Card
private struct MyEvolveCard: View {
    @Environment(\.theme) private var theme: any Theme
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: {
            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
            impactFeedback.impactOccurred()
            action()
        }) {
            VStack(alignment: .center, spacing: 16) {
                // Icon with colored background
                ZStack {
                    Circle()
                        .fill(color.opacity(0.15))
                        .frame(width: 50, height: 50)
                    
                    Image(systemName: icon)
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(color)
                }
                
                // Title
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(theme.primaryText)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
            }
            .padding(20)
            .frame(width: 160, height: 120)
            .background(
                RoundedRectangle(cornerRadius: 15, style: .continuous)
                    .fill(theme.background)
                    .shadow(color: theme.defaultShadow.color.opacity(0.6), radius: theme.defaultShadow.radius, x: theme.defaultShadow.x, y: theme.defaultShadow.y)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - My Trackers Section
private struct MyTrackersSection: View {
    @Environment(\.theme) private var theme: any Theme
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Header with ellipsis menu
            HStack {
                Text("My Trackers")
                    .font(.system(size: 21, weight: .semibold))
                    .foregroundColor(theme.primaryText)
                
                Spacer()
                
                Menu {
                    Button("Add New", action: {
                        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                        impactFeedback.impactOccurred()
                        // TODO: Add new tracker functionality
                    })
                    
                    Button("Edit", action: {
                        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                        impactFeedback.impactOccurred()
                        // TODO: Edit trackers functionality
                    })
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(theme.primaryText)
                }
            }
            .padding(.horizontal)
            
            // Placeholder content for now
            VStack(spacing: 16) {
                Text("Custom trackers coming soon.")
                    .font(.system(size: 16))
                    .foregroundColor(theme.secondaryText)
                    .multilineTextAlignment(.center)
                
                
            }
            .padding()
            .frame(maxWidth: .infinity)
            .frame(height: 120)
            .background(
                RoundedRectangle(cornerRadius: 15, style: .continuous)
                    .fill(theme.background)
                    .shadow(color: theme.defaultShadow.color.opacity(0.8), radius: theme.defaultShadow.radius * 1.5, x: theme.defaultShadow.x, y: theme.defaultShadow.y * 1.5)
            )
            .padding(.horizontal)
        }
    }
}

// MARK: - Preview
struct JourneyView_Previews: PreviewProvider {
    static var previews: some View {
        let previewManager = AuthenticationManager()
        
        let sampleUser = AppUser(
            id: "1",
            phone: "+10000000000",
            backupEmail: nil,
            firstName: "Jane",
            lastName: "Doe",
            isPhoneVerified: true,
            dateJoined: ISO8601DateFormatter().string(from: Date()),
            lifetimePoints: 120,
            availablePoints: 60,
            lifetimeSavings: 15,
            isOnboarded: true,
            currentStreak: 5,
            longestStreak: 10,
            streakPoints: 50,
            info: nil,
            equipment: nil,
            exerciseMaxes: nil,
            muscleFatigue: nil,
            goals: nil,
            scheduledActivities: nil,
            completionLogs: nil,
            calorieLogs: nil,
            feedback: nil,
            assignedPromotions: nil,
            promotionRedemptions: []
        )
        
        previewManager.currentUser = sampleUser
        
        return JourneyView()
            .environmentObject(previewManager)
            .liquidGlassTheme()
    }
} 
