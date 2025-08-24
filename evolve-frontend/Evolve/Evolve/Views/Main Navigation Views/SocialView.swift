import SwiftUI
import Combine

/**
 * SocialView: Main social interface displaying user's friend groups and competitions
 * 
 * Architecture:
 * - Uses MVVM pattern with @StateObject and @EnvironmentObject
 * - Implements caching strategy via CacheManager for offline support
 * - Supports pull-to-refresh and real-time data synchronization
 * 
 * Data Flow:
 * 1. Load cached friend groups on appear
 * 2. Fetch fresh data from API in background
 * 3. Update UI with filtered user groups
 * 4. Handle user interactions (leave, view details)
 * 
 * State Management:
 * - friendCircles: Current user's groups (filtered from all groups)
 * - isLoading: Network request state
 * - selectedCircle: Navigation state for detail view
 * - refreshID: Triggers child component data refresh
 */
struct SocialView: View {
    // MARK: - Dependencies
    @EnvironmentObject var authManager: AuthenticationManager
    @StateObject private var cinematicManager = CinematicStateManager()
    @Environment(\.theme) private var theme: any Theme
    @Environment(\.dynamicThemeColor) private var dynamicThemeColor
    @Binding var isModalActive: Bool
    
    // MARK: - Initializers
    init(isModalActive: Binding<Bool> = .constant(false)) {
        self._isModalActive = isModalActive
    }
    
    // MARK: - State Properties
    @State private var friendCircles: [FriendGroup] = []
    @State private var isLoading: Bool = true
    @State private var errorMessage: String? = nil
    @State private var selectedCircle: FriendGroup? = nil
    @State private var refreshID = UUID()
    @State private var useGradientBackground = false
    @State private var pendingInvitations: [FriendGroupInvitation] = []
    @State private var showInvitations = false
    
    // MARK: - Computed Properties
    
    /// Dynamic greeting based on current time and user's first name
    private var dynamicGreeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        let firstName = authManager.currentUser?.firstName ?? "there"
        
        switch hour {
        case 0..<12: return "Good morning, \(firstName)"
        case 12..<17: return "Good afternoon, \(firstName)"
        case 17..<21: return "Good evening, \(firstName)"
        default: return "Good night, \(firstName)"
        }
    }
    
    /// User initials for profile avatar (first letter of first + last name)
    private var userInitials: String {
        guard let user = authManager.currentUser,
              !user.firstName.isEmpty,
              !user.lastName.isEmpty else { return "" }
        
        return "\(user.firstName.first!)\(user.lastName.first!)"
    }
    
    // MARK: - View Components
    
    /// Invitation banner for pending friend group invitations
    private var invitationBanner: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "person.2.badge.plus")
                    .font(.title2)
                    .foregroundColor(theme.accent)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Friend Circle Invitations")
                        .font(.headline)
                        .foregroundColor(theme.primaryText)
                    
                    Text("You have \(pendingInvitations.count) pending invitation\(pendingInvitations.count == 1 ? "" : "s")")
                        .font(.subheadline)
                        .foregroundColor(theme.secondaryText)
                }
                
                Spacer()
                
                Button(action: { showInvitations = true }) {
                    Text("View")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(theme.accent)
                }
            }
            .padding()
            .background(theme.accent.opacity(0.1))
            .cornerRadius(12)
        }
        .sheet(isPresented: $showInvitations) {
            InvitationListView(
                invitations: pendingInvitations,
                onInvitationResponded: {
                    Task {
                        await fetchPendingInvitations()
                        await fetchFriendGroups()
                    }
                }
            )
            .environmentObject(authManager)
        }
    }
    
    /// Header component with greeting and profile button
    private var headerView: some View {
        HStack {
            Text(dynamicGreeting)
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(theme.primaryText)
            
            Spacer()
            
            // Profile/Settings button
            Button(action: { cinematicManager.present("settings") }) {
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
                    .overlay(
                        Group {
                            if userInitials.isEmpty {
                                Image(systemName: "person.fill")
                                    .foregroundColor(theme.primaryText)
                            } else {
                                Text(userInitials)
                                    .font(.headline)
                                    .foregroundColor(theme.primaryText)
                            }
                        }
                    )
            }
        }
        .padding(.top, 10)
    }
    
    /// Background component with dynamic theming
    private func backgroundView(geometry: GeometryProxy) -> some View {
        ZStack {
            GridBackground()
                .cinematicBackground(isActive: cinematicManager.isAnyActive)
            
            if useGradientBackground {
                TopHorizontalGradient(leftColor: Color("Mind"), rightColor: Color("Sleep"))
                    .frame(height: geometry.size.height * 0.6)
                    .frame(maxHeight: .infinity, alignment: .top)
                    .ignoresSafeArea()
            } else {
                TopSolidColor(color: dynamicThemeColor)
                    .frame(height: geometry.size.height * 0.6)
                    .frame(maxHeight: .infinity, alignment: .top)
                    .ignoresSafeArea()
            }
        }
    }
    
    /// competitions section placeholder
    private var competitionsSection: some View {
        SectionContainer(title: "Community Competitions") {
            Text("Coming soon")
                .font(.system(size: 16))
                .foregroundColor(theme.secondaryText)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
    
    /// Friend groups section with loading states
    private var friendCirclesSection: some View {
        SectionContainer(
            title: "Friend Groups",
            action: { cinematicManager.present("createFriendGroup") },
            actionIcon: "plus"
        ) {
            Group {
                if isLoading {
                    ProgressView("Loading groups...")
                        .padding(.top, 50)
                } else if let errorMessage = errorMessage {
                    Text("Error: \(errorMessage)")
                        .foregroundColor(.red)
                        .padding()
                } else if friendCircles.isEmpty {
                    Text("No friend groups found. Create one or join one!")
                        .foregroundColor(theme.secondaryText)
                        .padding()
                } else {
                    LazyVStack(spacing: 16) {
                        ForEach(friendCircles) { group in
                            FriendGroupRowView(
                                group: group,
                                selectedCircle: $selectedCircle,
                                cinematicManager: cinematicManager,
                                isModalActive: $isModalActive,
                                authManager: authManager,
                                onLeave: { leaveGroup(groupId: group.id) },
                                onRefresh: { await refreshData() },
                                refreshID: refreshID
                            )
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Main View
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .top) {
                backgroundView(geometry: geometry)
                
                ScrollView {
                    LazyVStack(spacing: 20) {
                        headerView
                            .padding(.horizontal)
                        
                        // Pending invitations banner
                        if !pendingInvitations.isEmpty {
                            invitationBanner
                                .padding(.horizontal)
                        }
                        
                        competitionsSection
                            .padding(.bottom, 10)
                        
                        friendCirclesSection
                            .padding(.bottom, 10)
                    }
                    .padding(.bottom)
                }
                .scrollIndicators(.hidden)
                .refreshable {
                    await refreshData()
                }
                .task {
                    await loadInitialData()
                    await fetchPendingInvitations()
                }
                
                // Settings overlay
                if cinematicManager.isActive("settings") {
                    SettingsView<AuthenticationManager>(
                        onDismiss: { cinematicManager.dismiss("settings") }
                    )
                    .environmentObject(authManager)
                    .cinematicOverlay()
                }
                
                // Friend Group Detail overlay with cinematic animation
                if cinematicManager.isActive("friendGroupDetail"), let selectedCircle = selectedCircle {
                    FriendGroupDetailView(
                        friendCircle: selectedCircle,
                        onDismiss: {
                            cinematicManager.dismiss("friendGroupDetail")
                            self.selectedCircle = nil
                            self.isModalActive = false
                            Task { await fetchFriendGroups(isBackgroundRefresh: true) }
                        }
                    )
                    .cinematicOverlay()
                }
                
                // Friend Circle Creation overlay with cinematic animation
                if cinematicManager.isActive("createFriendGroup") {
                    CreateFriendGroupFlowView(
                        onDismiss: {
                            cinematicManager.dismiss("createFriendGroup")
                            self.isModalActive = false
                            Task { await fetchFriendGroups(isBackgroundRefresh: true) }
                        }
                    )
                    .environmentObject(authManager)
                    .cinematicOverlay()
                }
            }
        }
    }
    
    // MARK: - Data Management
    
    /// Initial data loading with cache-first strategy
    /// Only shows loading state if no cached content is available
    private func loadInitialData() async {
        errorMessage = nil
        
        // Try loading from cache first WITHOUT showing loading state
        if let cachedCircles = loadFromCache() {
            await updateFriendGroups(with: cachedCircles)
            // Clear any previous error messages since we have valid cached data
            await MainActor.run {
                self.errorMessage = nil
            }
            // Fetch fresh data in background to keep content up-to-date
            await fetchFriendGroups(isBackgroundRefresh: true)
            return
        }
        
        // Only show loading state if no cached data exists
        await MainActor.run {
            isLoading = true
        }
        
        // Fetch fresh data since no cache is available
        await fetchFriendGroups()
    }
    
    /// Refresh data by clearing cache and fetching fresh data
    private func refreshData() async {
        CacheManager.shared.clearCache(for: "userFriendGroups")
        await fetchFriendGroups(isBackgroundRefresh: true)
        refreshID = UUID()
    }
    
    /// Load friend groups from cache if available
    private func loadFromCache() -> [FriendGroup]? {
        guard let cachedCircles: [FriendGroup] = CacheManager.shared.load(
            from: "userFriendGroups",
            as: [FriendGroup].self
        ) else { return nil }
        
        print("SocialView: Loaded friend groups from cache")
        return cachedCircles
    }
    
    /// Fetch friend groups from API and update cache
    private func fetchFriendGroups(isBackgroundRefresh: Bool = false) async {
        if !isBackgroundRefresh {
            await MainActor.run {
                isLoading = true
                errorMessage = nil
            }
        }
        
        do {
            guard authManager.authToken != nil else {
                await handleError("Authentication token not found", isBackgroundRefresh: isBackgroundRefresh)
                return
            }
            
            let api = FriendGroupAPI(httpClient: authManager.httpClient)
            let fetchedCircles = try await api.fetchFriendGroups()
            
            // Update cache
            CacheManager.shared.save(object: fetchedCircles, to: "userFriendGroups")
            print("SocialView: Cached \(fetchedCircles.count) friend groups")
            
            await updateFriendGroups(with: fetchedCircles, isBackgroundRefresh: isBackgroundRefresh)
            
        } catch {
            await handleError(error.localizedDescription, isBackgroundRefresh: isBackgroundRefresh)
        }
    }
    
    /// Update UI with filtered friend groups for current user
    private func updateFriendGroups(with allCircles: [FriendGroup], isBackgroundRefresh: Bool = false) async {
        guard let currentUserPhone = authManager.currentUser?.phone else {
            await handleError("Current user not found", isBackgroundRefresh: isBackgroundRefresh)
            return
        }
        
        let userCircles = allCircles.filter { group in
            group.members.contains { $0.user.phone == currentUserPhone }
        }
        
        await MainActor.run {
            self.friendCircles = userCircles
            if !isBackgroundRefresh { self.isLoading = false }
        }
    }
    
    /// Handle errors consistently
    /// For background refreshes, only log errors without affecting UI state
    private func handleError(_ message: String, isBackgroundRefresh: Bool) async {
        await MainActor.run {
            // Only show error message to user if it's not a background refresh
            if !isBackgroundRefresh {
                self.errorMessage = message
                self.isLoading = false
            }
            print("SocialView Error: \(message)")
        }
    }
    
    /// Leave a friend group and update local state
    private func leaveGroup(groupId: Int) {
        Task {
            do {
                let api = FriendGroupAPI(httpClient: authManager.httpClient)
                try await api.leaveGroup(groupId: groupId, currentUserPhone: authManager.currentUser?.phone ?? "")
                
                await MainActor.run {
                    friendCircles.removeAll { $0.id == groupId }
                    CacheManager.shared.save(object: friendCircles, to: "userFriendGroups")
                    print("SocialView: Left group \(groupId)")
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = "Failed to leave group: \(error.localizedDescription)"
                    print("Error leaving group: \(error)")
                }
            }
        }
    }
    
    /// Fetch pending invitations for the current user
    private func fetchPendingInvitations() async {
        guard let token = authManager.authToken,
              let url = URL(string: "\(AppConfig.apiBaseURL)/friend-group-invitations/") else {
            return
        }
        
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            let invitations = try JSONDecoder().decode([FriendGroupInvitation].self, from: data)
            
            await MainActor.run {
                self.pendingInvitations = invitations
            }
        } catch {
            print("SocialView: Failed to fetch invitations: \(error)")
        }
    }
}

// MARK: - Supporting Views

/**
 * SectionContainer: Reusable section header with content
 * Provides consistent styling for section titles and content layout
 */
struct SectionContainer<Content: View>: View {
    let title: String
    let content: Content
    var action: (() -> Void)? = nil
    var actionIcon: String? = nil
    @Environment(\.theme) private var theme: any Theme
    
    init(title: String, 
         action: (() -> Void)? = nil,
         actionIcon: String? = nil,
         @ViewBuilder content: () -> Content) {
        self.title = title
        self.action = action
        self.actionIcon = actionIcon
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.system(size: 21, weight: .semibold))
                    .foregroundColor(theme.primaryText)
                Spacer()
                
                if let action = action, let icon = actionIcon {
                    Button(action: action) {
                        Image(systemName: icon)
                            .font(.system(size: 20, weight: .medium))
                            .foregroundColor(theme.primaryText)
                    }
                }
            }
            .padding(.horizontal)
            
            content
                .padding(.horizontal)
        }
    }
}

// MARK: - Event Fetcher (Temporarily Disabled)
// TODO: Re-enable event functionality later

/**
 * FriendGroupEventFetcher: ObservableObject for managing group event data
 * 
 * TEMPORARILY COMMENTED OUT - Will be re-enabled later
 * 
 * Responsibilities:
 * - Fetch recent events for a specific group
 * - Format event data for display
 * - Provide loading states and error handling
 * 
 * Usage: Owned by FriendGroupRowView as @StateObject
 */
/*
@MainActor
class FriendGroupEventFetcher: ObservableObject {
    @Published var eventsData: [(text: String, date: Date?)] = [(text: "Loading events...", date: nil)]
    
    private let groupId: Int
    private let api: FriendGroupAPI
    
    init(groupId: Int, authManager: AuthenticationManager) {
        self.groupId = groupId
        self.api = FriendGroupAPI(httpClient: authManager.httpClient)
        fetchRecentEvents()
    }
    
    /// Fetch and format recent events for the group
    func fetchRecentEvents() {
        Task {
            do {
                let events = try await api.fetchFriendGroupEvents(groupId: groupId)
                let recentEvents = Array(events.sorted { $0.timestamp > $1.timestamp }.prefix(3))
                
                let formattedEvents = recentEvents.map { event in
                    (text: formatEventText(event), date: event.timestamp)
                }
                
                await MainActor.run {
                    self.eventsData = formattedEvents.isEmpty
                        ? [(text: "No recent activity.", date: nil)]
                        : formattedEvents
                }
            } catch {
                await MainActor.run {
                    self.eventsData = [(text: "Error: \(error.localizedDescription)", date: nil)]
                    print("EventFetcher Error: \(error)")
                }
            }
        }
    }
    
    /// Format event data into user-readable text
    private func formatEventText(_ event: FriendGroupEvent) -> String {
        let userName = event.user?.firstName ?? "Someone"
        
        switch event.eventType {
        case "MEMBER_JOINED":
            return "\(userName) joined."
        case "MEMBER_LEFT":
            return "\(userName) left."
        case "ACTIVITY_COMPLETED":
            let activityName = event.userCompletedLog?.activity?.name ?? "an activity"
            return "\(userName) completed \(activityName)."
        default:
            return "Event: \(event.eventType)"
        }
    }
}
*/

/**
 * FriendGroupCard: Card component displaying group information
 * 
 * SIMPLIFIED VERSION - Event functionality temporarily removed
 * 
 * Layout Structure:
 * - Background: Full cover image spanning entire card
 * - Top overlay: Title and menu with gradient backdrop
 * - Bottom overlay: Member count and summary bar with gradient backdrop
 * 
 * Features:
 * - Pure 16:9 aspect ratio maintained by SwiftUI
 * - Async image loading with fallback
 * - Overlaid UI elements on cover image background
 * - Mute/unmute functionality
 * - Leave group confirmation dialog
 * 
 * Note: Event display functionality has been temporarily commented out
 * and will be re-enabled later.
 */
struct FriendGroupCard: View {
    // MARK: - Constants
    private let barHeight: CGFloat = 70
    private let cornerRadius: CGFloat = 15
    
    // MARK: - Properties
    let memberCount: Int
    let membersSummary: String
    let title: String
    // let eventsData: [(text: String, date: Date?)]  // COMMENTED OUT - Will re-enable later
    let coverImageURLString: String?
    let friendGroup: FriendGroup
    let currentUserPhone: String
    let onLeave: () -> Void
    let onRenameGroup: ((String) -> Void)?
    let onTransferAdmin: ((Member) -> Void)?
    let onCoverImageChange: ((String) -> Void)?
    
    // MARK: - State
    @State private var isMuted: Bool = false
    @State private var showingLeaveConfirm = false
    @State private var isShowingRenameSheet = false
    @State private var isShowingTransferAdmin = false
    @State private var isShowingCoverImagePicker = false
    @Environment(\.theme) private var theme: any Theme
    
    // MARK: - Computed Properties
    
    /// Check if current user is an admin of this friend group
    private var isCurrentUserAdmin: Bool {
        friendGroup.members.contains { member in
            member.user.phone == currentUserPhone && member.isAdmin
        }
    }
    
    /// Get non-admin members for admin transfer
    private var nonAdminMembers: [Member] {
        friendGroup.members.filter { !$0.isAdmin }
    }
    
    // MARK: - View Components
    
    /// Background image with loading states
    private var backgroundImage: some View {
        Group {
            // Check if coverImageURLString is a local asset first
            if let coverImageURLString = coverImageURLString,
               UIImage(named: coverImageURLString) != nil {
                // Use local asset image
                Image(coverImageURLString)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                // Use AsyncImage for remote URLs
                AsyncImage(url: URL(string: coverImageURLString ?? "")) { phase in
                    switch phase {
                    case .empty:
                        ProgressView()
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .background(Color.gray.opacity(0.3))
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    case .failure:
                        Image(systemName: "photo.fill")
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .foregroundColor(theme.secondaryText)
                            .background(Color.gray.opacity(0.1))
                    @unknown default:
                        EmptyView()
                    }
                }
            }
        }
    }
    
    /// Title and menu header
    private var headerSection: some View {
        HStack {
            Text(title)
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(.white)
                .padding(.leading)
            
            Spacer()
            
            Menu {
                if isCurrentUserAdmin {
                    // Admin-specific options
                    if onRenameGroup != nil {
                        Button("Rename Group") {
                            isShowingRenameSheet = true
                        }
                    }
                    
                    if onTransferAdmin != nil && !nonAdminMembers.isEmpty {
                        Button("Transfer Admin") {
                            isShowingTransferAdmin = true
                        }
                    }
                    
                    if onCoverImageChange != nil {
                        Button("Change Cover Image") {
                            isShowingCoverImagePicker = true
                        }
                    }
                } else {
                    // Non-admin options
                    Button(isMuted ? "Unmute" : "Mute") {
                        isMuted.toggle()
                    }
                    Button("Leave", role: .destructive) {
                        showingLeaveConfirm = true
                    }
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 22))
                    .foregroundColor(.white)
                    .padding(EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12))
                    .contentShape(Rectangle())
            }
            .alert("Leave Circle?", isPresented: $showingLeaveConfirm) {
                Button("Leave", role: .destructive) { onLeave() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Are you sure you want to leave the group \"\(title)\"? This action cannot be undone.")
                    .font(.system(size: 15))
            }
            .sheet(isPresented: $isShowingRenameSheet) {
                if let onRenameGroup = onRenameGroup {
                    RenameGroupSheet(
                        friendCircle: friendGroup,
                        onRename: onRenameGroup,
                        onDismiss: { isShowingRenameSheet = false }
                    )
                }
            }
            .sheet(isPresented: $isShowingTransferAdmin) {
                if let onTransferAdmin = onTransferAdmin {
                    TransferAdminSheet(
                        friendCircle: friendGroup,
                        nonAdminMembers: nonAdminMembers,
                        onTransfer: onTransferAdmin,
                        onDismiss: { isShowingTransferAdmin = false }
                    )
                }
            }
            .sheet(isPresented: $isShowingCoverImagePicker) {
                if let onCoverImageChange = onCoverImageChange {
                    CoverImagePickerSheet(
                        friendCircle: friendGroup,
                        onImageSelected: onCoverImageChange,
                        onDismiss: { isShowingCoverImagePicker = false }
                    )
                }
            }
        }
        .padding(.top, 16)
    }
    
    /// Members information bar
    private var membersBar: some View {
        Rectangle()
            .fill(
                LinearGradient(
                    gradient: Gradient(colors: [Color.black.opacity(0.6), Color.black.opacity(0.7)]),
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .frame(height: barHeight)
            .overlay(
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(memberCount) members")
                        .font(.system(size: 17))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text(membersSummary)
                        .font(.system(size: 15))
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.horizontal)
            )
    }
    
    // MARK: - Main View
    var body: some View {
        ZStack {
            // Background image covers entire card
            backgroundImage
            
            // Gradient overlay for better text visibility (top section)
            VStack {
                LinearGradient(
                    gradient: Gradient(colors: [Color.black.opacity(0.6), Color.clear]),
                    startPoint: .top,
                    endPoint: .center
                )
                .frame(maxHeight: .infinity)
                
                Spacer()
            }
            
            // Header section at top
            VStack {
                headerSection
                Spacer()
            }
            
            // Members bar overlaid at bottom
            VStack {
                Spacer()
                membersBar
            }
        }
        .aspectRatio(16/9, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
        .shadow(
            color: theme.defaultShadow.color,
            radius: theme.defaultShadow.radius,
            x: theme.defaultShadow.x,
            y: theme.defaultShadow.y
        )
    }
}

/**
 * FriendGroupRowView: Container view for displaying friend group cards
 * 
 * SIMPLIFIED VERSION - Event fetching temporarily removed
 * 
 * Purpose: Bridges FriendGroup model with FriendGroupCard presentation
 * - Handles user interaction (tap to open, leave group)
 * - Formats member data for display
 * 
 * State Management:
 * - Manages selection state for navigation
 * 
 * Note: Event fetching functionality has been temporarily commented out
 * and will be re-enabled later.
 */
struct FriendGroupRowView: View {
    let group: FriendGroup
    @Binding var selectedCircle: FriendGroup?
    let cinematicManager: CinematicStateManager
    @Binding var isModalActive: Bool
    @EnvironmentObject var authManager: AuthenticationManager
    let onLeave: () -> Void
    let onRefresh: () async -> Void
    let refreshID: UUID
    @State private var errorMessage: String?
    
    // @StateObject private var eventFetcher: FriendGroupEventFetcher  // COMMENTED OUT - Will re-enable later
    
    init(group: FriendGroup, selectedCircle: Binding<FriendGroup?>, cinematicManager: CinematicStateManager, isModalActive: Binding<Bool>, authManager: AuthenticationManager, onLeave: @escaping () -> Void, onRefresh: @escaping () async -> Void, refreshID: UUID) {
        self.group = group
        self._selectedCircle = selectedCircle
        self.cinematicManager = cinematicManager
        self._isModalActive = isModalActive
        self.onLeave = onLeave
        self.onRefresh = onRefresh
        self.refreshID = refreshID
        self._authManager = EnvironmentObject<AuthenticationManager>()
        // self._eventFetcher = StateObject(wrappedValue: FriendGroupEventFetcher(groupId: group.id, authManager: authManager))  // COMMENTED OUT
    }
    
    /// Generate member summary text for display
    private var membersSummary: (count: Int, summary: String) {
        let totalMembers = group.members.count
        
        guard let currentUser = authManager.currentUser,
              group.members.contains(where: { $0.user.phone == currentUser.phone }) else {
            // Fallback when user not in group
            let memberNames = group.members.map { $0.user.firstName }
            let summary = memberNames.count > 3
                ? "\(Array(memberNames.prefix(3)).joined(separator: ", ")), and more"
                : memberNames.joined(separator: ", ")
            return (totalMembers, summary)
        }
        
        let otherMembers = group.members.filter { $0.user.phone != currentUser.phone }
        let otherNames = otherMembers.map { $0.user.firstName }
        
        // Special case for two-member groups
        if totalMembers == 2, let otherName = otherNames.first {
            return (totalMembers, "You and \(otherName)")
        }
        
        // Build summary with "You" first
        var parts = ["You"]
        parts.append(contentsOf: Array(otherNames.prefix(2)))
        
        var summary = parts.joined(separator: ", ")
        if otherNames.count > 2 {
            summary += ", and more"
        }
        
        return (totalMembers, summary)
    }
    
    // MARK: - Admin Functions
    
    private func renameGroup(newName: String) {
        Task {
            let friendGroupAPI = FriendGroupAPI(httpClient: authManager.httpClient)
            do {
                try await friendGroupAPI.renameGroup(
                    groupId: group.id,
                    newName: newName,
                    currentUserPhone: authManager.currentUser?.phone ?? ""
                )
                print("FriendGroupRowView: Group renamed successfully")
                await onRefresh()
            } catch {
                await MainActor.run {
                    self.errorMessage = "Failed to rename group: \(error.localizedDescription)"
                    print("FriendGroupRowView: Rename failed: \(error)")
                }
            }
        }
    }
    
    private func transferAdmin(member: Member) {
        Task {
            let friendGroupAPI = FriendGroupAPI(httpClient: authManager.httpClient)
            do {
                try await friendGroupAPI.transferAdmin(
                    groupId: group.id,
                    newAdminMemberId: member.id,
                    currentUserPhone: authManager.currentUser?.phone ?? ""
                )
                print("FriendGroupRowView: Admin transferred successfully")
                // Note: The parent view will refresh data through refreshID changes
            } catch {
                await MainActor.run {
                    self.errorMessage = "Failed to transfer admin: \(error.localizedDescription)"
                    print("FriendGroupRowView: Transfer admin failed: \(error)")
                }
            }
        }
    }
    
    private func changeCoverImage(newImageUrl: String) {
        Task {
            let friendGroupAPI = FriendGroupAPI(httpClient: authManager.httpClient)
            do {
                try await friendGroupAPI.changeCoverImage(
                    groupId: group.id,
                    newImageUrl: newImageUrl,
                    currentUserPhone: authManager.currentUser?.phone ?? ""
                )
                print("FriendGroupRowView: Cover image changed successfully")
                await onRefresh()
            } catch {
                await MainActor.run {
                    self.errorMessage = "Failed to change cover image: \(error.localizedDescription)"
                    print("FriendGroupRowView: Change cover image failed: \(error)")
                }
            }
        }
    }
    
    var body: some View {
        Button {
            selectedCircle = group
            isModalActive = true
            cinematicManager.present("friendGroupDetail")
        } label: {
            let summary = membersSummary
            FriendGroupCard(
                memberCount: summary.count,
                membersSummary: summary.summary,
                title: group.name,
                // eventsData: eventFetcher.eventsData,  // COMMENTED OUT - Will re-enable later
                coverImageURLString: group.coverImage,
                friendGroup: group,
                currentUserPhone: authManager.currentUser?.phone ?? "",
                onLeave: onLeave,
                onRenameGroup: renameGroup,
                onTransferAdmin: transferAdmin,
                onCoverImageChange: changeCoverImage
            )
        }
        .buttonStyle(.plain)
        // .onChange(of: refreshID) {  // COMMENTED OUT - Event refresh logic
        //     eventFetcher.fetchRecentEvents()
        // }
    }
}

// MARK: - Preview Providers

struct SocialView_Previews: PreviewProvider {
    static var previews: some View {
        SocialView(isModalActive: .constant(false))
            .environmentObject(PreviewConstants.sampleAuthManagerUpdated)
            .previewLayout(.sizeThatFits)
    }
}
//
//struct FriendGroupCard_Previews: PreviewProvider {
//    static var previews: some View {
//        ScrollView {
//            VStack(spacing: 30) {
//                VStack(spacing: 16) {
//                    Text("16:9 Aspect Ratio Friend Circle Card")
//                        .font(.headline)
//                        .foregroundColor(.primary)
//                    Text("Cover image background with overlaid member info")
//                        .font(.caption)
//                        .foregroundColor(.secondary)
//                    
//                    FriendGroupCard(
//                        memberCount: 3,
//                        membersSummary: "You, Alice, and Bob",
//                        title: "Morning Runners",
//                        // eventsData: [],  // COMMENTED OUT - Event functionality disabled
//                        coverImageURLString: nil,
//                        friendGroup: PreviewConstants.sampleFriendGroup,
//                        currentUserPhone: PreviewConstants.sampleAuthManagerUpdated.currentUser?.phone ?? "",
//                        onLeave: { print("Leave action triggered.") },
//                        onRenameGroup: nil,
//                        onTransferAdmin: nil,
//                        onCoverImageChange: nil
//                    )
//                    .environment(\.theme, LiquidGlassTheme())
//                }
//                
//                VStack(spacing: 16) {
//                    Text("Larger Circle")
//                        .font(.headline)
//                        .foregroundColor(.primary)
//                    Text("Member info overlaid on full background image")
//                        .font(.caption)
//                        .foregroundColor(.secondary)
//                    
//                    FriendGroupCard(
//                        memberCount: 8,
//                        membersSummary: "You, Sarah, Mike, and 5 more",
//                        title: "Fitness Enthusiasts",
//                        // eventsData: [],  // COMMENTED OUT - Event functionality disabled
//                        coverImageURLString: nil,
//                        friendGroup: PreviewConstants.sampleFriendGroup,
//                        currentUserPhone: PreviewConstants.sampleAuthManagerUpdated.currentUser?.phone ?? "",
//                        onLeave: { print("Leave action triggered.") },
//                        onRenameGroup: nil,
//                        onTransferAdmin: nil,
//                        onCoverImageChange: nil
//                    )
//                    .liquidGlassTheme()
//                }
//                
//                VStack(spacing: 8) {
//                    Text("Full Background Design")
//                        .font(.caption)
//                        .foregroundColor(.secondary)
//                        .multilineTextAlignment(.center)
//                    
//                    Text("Cover image now fills entire card with member info overlaid at bottom")
//                        .font(.caption)
//                        .foregroundColor(.secondary)
//                        .multilineTextAlignment(.center)
//                }
//                .padding(.horizontal)
//            }
//            .padding(.vertical)
//        }
//        .previewLayout(.sizeThatFits)
//    }
//}
