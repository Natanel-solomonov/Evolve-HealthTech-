import SwiftUI
import Combine

/**
 * FriendGroupDetailView: Detailed view for a specific friend group
 * 
 * Features:
 * - Fullscreen grid background with overlaid content
 * - Prominent cover image header with circle name
 * - Activity and Members tabs with filtered content
 * - Event cards styled to match DashboardView activity cards overlaying grid
 * - Member cards with consistent styling overlaying grid
 * - Live timestamp updates for events
 * - Smart event filtering (past 24 hours)
 * - Leave circle functionality
 * - Enhanced visual depth with shadows and proper card hierarchy
 */

// MARK: - Header View
struct FriendGroupHeaderView: View {
    let friendCircle: FriendGroup
    let currentUserPhone: String
    let onDismiss: () -> Void
    let onLeave: () -> Void
    let onTransferAdmin: (Member) -> Void
    let onCoverImageChange: (String) -> Void
    let onRenameGroup: (String) -> Void
    @State private var isShowingLeaveConfirm = false
    @State private var isShowingTransferAdmin = false
    @State private var isShowingCoverImagePicker = false
    @State private var isShowingRenameSheet = false
    @Environment(\.theme) private var theme: any Theme
    
    // Check if current user is an admin of this friend circle
    private var currentUserMembership: Member? {
        friendCircle.members.first { member in
            member.user.phone == currentUserPhone
        }
    }
    
    private var isCurrentUserAdmin: Bool {
        currentUserMembership?.isAdmin ?? false
    }
    
    // Get non-admin members for admin transfer
    private var nonAdminMembers: [Member] {
        friendCircle.members.filter { !$0.isAdmin }
    }

    var body: some View {
        GeometryReader { geometry in
            let screenWidth = geometry.size.width
            let imageHeight = screenWidth * 9 / 16 // 16:9 aspect ratio
            
            ZStack(alignment: .top) {
                // Cover Image
                Group {
                    // Check if coverImage is a local asset first
                    if let coverImage = friendCircle.coverImage, 
                       UIImage(named: coverImage) != nil {
                        // Use local asset image
                        Image(coverImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } else if let coverImageUrl = friendCircle.coverImage,
                              URL(string: coverImageUrl) != nil {
                        // Use remote URL image
                        AsyncImage(url: URL(string: coverImageUrl)) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } placeholder: {
                            LinearGradient(
                                gradient: Gradient(colors: [.blue, .purple]), 
                                startPoint: .topLeading, 
                                endPoint: .bottomTrailing
                            )
                        }
                    } else {
                        // Default gradient when no image is available
                        LinearGradient(
                            gradient: Gradient(colors: [.blue, .purple]), 
                            startPoint: .topLeading, 
                            endPoint: .bottomTrailing
                        )
                    }
                }
                .frame(height: imageHeight)
                .clipped()

                // Gradient Overlay for better text visibility
                LinearGradient(
                    gradient: Gradient(colors: [.black.opacity(0.6), .clear]), 
                    startPoint: .top, 
                    endPoint: .bottom
                )
                .frame(height: imageHeight * 0.5)

                // Circle Name
                Text(friendCircle.name)
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                    .shadow(color: .black.opacity(0.7), radius: 3, x: 0, y: 2)

                // Header Buttons
                HStack {
                    // X Close Button
                    Button {
                        onDismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .foregroundColor(.white)
                            .padding(12)
                            .background(Color.black.opacity(0.6))
                            .clipShape(Circle())
                            .font(.system(size: 18, weight: .medium))
                    }

                    Spacer()

                    // Menu Button
                    Menu {
                        if isCurrentUserAdmin {
                            // Admin-specific options
                            Button("Rename Group") {
                                isShowingRenameSheet = true
                            }
                            
                            if !nonAdminMembers.isEmpty {
                                Button("Transfer Admin") {
                                    isShowingTransferAdmin = true
                                }
                            }
                            
                            Button("Change Cover Image") {
                                isShowingCoverImagePicker = true
                            }
                        } else {
                            // Non-admin options
                            Button("Leave Circle", role: .destructive) {
                                isShowingLeaveConfirm = true
                            }
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .foregroundColor(.white)
                            .padding(12)
                            .background(Color.black.opacity(0.6))
                            .clipShape(Circle())
                            .font(.system(size: 24, weight: .medium))
                    }
                    .alert("Leave Circle?", isPresented: $isShowingLeaveConfirm) {
                        Button("Leave", role: .destructive) { onLeave() }
                        Button("Cancel", role: .cancel) {}
                    } message: {
                        Text("Are you sure you want to leave the group \"\(friendCircle.name)\"? This action cannot be undone.")
                            .font(.system(size: 15))
                    }
                    .sheet(isPresented: $isShowingRenameSheet) {
                        RenameGroupSheet(
                            friendCircle: friendCircle,
                            onRename: onRenameGroup,
                            onDismiss: { isShowingRenameSheet = false }
                        )
                    }
                    .sheet(isPresented: $isShowingTransferAdmin) {
                        TransferAdminSheet(
                            friendCircle: friendCircle,
                            nonAdminMembers: nonAdminMembers,
                            onTransfer: onTransferAdmin,
                            onDismiss: { isShowingTransferAdmin = false }
                        )
                    }
                    .sheet(isPresented: $isShowingCoverImagePicker) {
                        CoverImagePickerSheet(
                            friendCircle: friendCircle,
                            onImageSelected: onCoverImageChange,
                            onDismiss: { isShowingCoverImagePicker = false }
                        )
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 60)
            }
            .frame(height: imageHeight)
        }
        .aspectRatio(16/9, contentMode: .fit)
    }
}

// MARK: - Transfer Admin Sheet
struct TransferAdminSheet: View {
    let friendCircle: FriendGroup
    let nonAdminMembers: [Member]
    let onTransfer: (Member) -> Void
    let onDismiss: () -> Void
    @Environment(\.theme) private var theme: any Theme
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header
                VStack(spacing: 8) {
                    Text("Transfer Admin")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(theme.primaryText)
                    
                    Text("Select a member to transfer admin privileges to. You will lose admin access.")
                        .font(.system(size: 15))
                        .foregroundColor(theme.secondaryText)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                }
                .padding(.top, 20)
                .padding(.bottom, 30)
                
                // Member List
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(nonAdminMembers) { member in
                            Button(action: {
                                onTransfer(member)
                                onDismiss()
                            }) {
                                HStack(spacing: 12) {
                                    // Member avatar
                                    Circle()
                                        .fill(theme.accent.opacity(0.2))
                                        .frame(width: 44, height: 44)
                                        .overlay(
                                            Text("\(String(member.user.firstName.first ?? "?"))\(String(member.user.lastName.first ?? "?"))")
                                                .font(.system(size: 16, weight: .semibold))
                                                .foregroundColor(theme.accent)
                                        )
                                    
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("\(member.user.firstName) \(member.user.lastName)")
                                            .font(.system(size: 17, weight: .semibold))
                                            .foregroundColor(theme.primaryText)
                                        
                                        Text("Joined: \(member.dateJoined, style: .date)")
                                            .font(.system(size: 14))
                                            .foregroundColor(theme.secondaryText)
                                    }
                                    
                                    Spacer()
                                    
                                    Image(systemName: "crown")
                                        .font(.system(size: 16))
                                        .foregroundColor(theme.accent)
                                }
                                .padding()
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(theme.background)
                                        .shadow(
                                            color: theme.defaultShadow.color.opacity(0.6),
                                            radius: theme.defaultShadow.radius,
                                            x: theme.defaultShadow.x,
                                            y: theme.defaultShadow.y
                                        )
                                )
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding(.horizontal, 20)
                }
                
                Spacer()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        onDismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Cover Image Picker Sheet
struct CoverImagePickerSheet: View {
    let friendCircle: FriendGroup
    let onImageSelected: (String) -> Void
    let onDismiss: () -> Void
    @Environment(\.theme) private var theme: any Theme
    
    // Available cover images in the asset catalog
    private let availableImages = [
        "friendgroupimage0",
        "friendgroupimage1", 
        "friendgroupimage2",
        "friendgroupimage3",
        "friendgroupimage4",
        "friendgroupimage5"
    ]
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header
                VStack(spacing: 8) {
                    Text("Change Cover Image")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(theme.primaryText)
                    
                    Text("Select a new cover image for \"\(friendCircle.name)\"")
                        .font(.system(size: 15))
                        .foregroundColor(theme.secondaryText)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                }
                .padding(.top, 20)
                .padding(.bottom, 30)
                
                // Image Grid
                ScrollView {
                    LazyVGrid(columns: [
                        GridItem(.flexible(), spacing: 16),
                        GridItem(.flexible(), spacing: 16)
                    ], spacing: 16) {
                        ForEach(availableImages, id: \.self) { imageName in
                            Button(action: {
                                onImageSelected(imageName)
                                onDismiss()
                            }) {
                                VStack(spacing: 8) {
                                    // Image preview with 16:9 aspect ratio
                                    Image(imageName)
                                        .resizable()
                                        .aspectRatio(16/9, contentMode: .fill)
                                        .frame(height: 100)
                                        .clipShape(RoundedRectangle(cornerRadius: 12))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12)
                                                .stroke(
                                                    friendCircle.coverImage == imageName ? theme.accent : Color.clear,
                                                    lineWidth: friendCircle.coverImage == imageName ? 3 : 0
                                                )
                                        )
                                    
                                    // Image name label
                                    Text(imageName.capitalized)
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(theme.secondaryText)
                                        .lineLimit(1)
                                    
                                    // Current selection indicator
                                    if friendCircle.coverImage == imageName {
                                        HStack(spacing: 4) {
                                            Image(systemName: "checkmark.circle.fill")
                                                .font(.system(size: 12))
                                                .foregroundColor(theme.accent)
                                            
                                            Text("Current")
                                                .font(.system(size: 12, weight: .bold))
                                                .foregroundColor(theme.accent)
                                        }
                                    } else {
                                        Text("Tap to select")
                                            .font(.system(size: 12))
                                            .foregroundColor(theme.secondaryText.opacity(0.7))
                                    }
                                }
                                .padding()
                                .background(
                                    RoundedRectangle(cornerRadius: 15)
                                        .fill(theme.background)
                                        .shadow(
                                            color: theme.defaultShadow.color.opacity(0.6),
                                            radius: theme.defaultShadow.radius,
                                            x: theme.defaultShadow.x,
                                            y: theme.defaultShadow.y
                                        )
                                )
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding(.horizontal, 20)
                }
                
                Spacer()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        onDismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Rename Group Sheet
struct RenameGroupSheet: View {
    let friendCircle: FriendGroup
    let onRename: (String) -> Void
    let onDismiss: () -> Void
    @Environment(\.theme) private var theme: any Theme
    @State private var groupName: String = ""
    @State private var isLoading = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header
                VStack(spacing: 8) {
                    Text("Rename Group")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(theme.primaryText)
                    
                    Text("Enter a new name for \"\(friendCircle.name)\"")
                        .font(.system(size: 15))
                        .foregroundColor(theme.secondaryText)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                }
                .padding(.top, 20)
                .padding(.bottom, 30)
                
                // Text Field
                VStack(alignment: .leading, spacing: 8) {
                    Text("Group Name")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(theme.primaryText)
                    
                    TextField("Enter group name", text: $groupName)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .font(.system(size: 16))
                        .disabled(isLoading)
                }
                .padding(.horizontal, 20)
                
                Spacer()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        onDismiss()
                    }
                    .disabled(isLoading)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        if !groupName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            isLoading = true
                            onRename(groupName.trimmingCharacters(in: .whitespacesAndNewlines))
                            onDismiss()
                        }
                    }
                    .disabled(groupName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isLoading)
                    .fontWeight(.semibold)
                }
            }
        }
        .onAppear {
            groupName = friendCircle.name
        }
    }
}

// MARK: - Event Card View
struct FriendGroupEventCard: View {
    let event: FriendGroupEvent
    @State private var timeUpdateTrigger = false
    @Environment(\.theme) private var theme: any Theme

    /// Formats event timestamps with "Just now" for events less than 1 minute old
    private func formatEventTime(_ date: Date) -> String {
        let timeInterval = Date().timeIntervalSince(date)
        
        if timeInterval < 60 {
            return "Just now"
        } else if timeInterval < 3600 {
            let minutes = Int(timeInterval / 60)
            return "\(minutes)m ago"
        } else if timeInterval < 86400 {
            let hours = Int(timeInterval / 3600)
            return "\(hours)h ago"
        } else if timeInterval < 604800 {
            let days = Int(timeInterval / 86400)
            return "\(days)d ago"
        } else {
            let formatter = DateFormatter()
            formatter.dateStyle = .short
            formatter.timeStyle = .none
            return formatter.string(from: date)
        }
    }

    /// Returns the appropriate emoji for the activity type using the same logic as DashboardView
    private var activityEmoji: String {
        if let activity = event.userCompletedLog?.activity {
            return ActivityTypeHelper.getEmoji(
                activityType: activity.activityType,
                categories: activity.category
            )
        }
        return "⭐"
    }

    /// Formats event description based on type
    private func formattedEventText() -> String {
        let userName = event.user?.firstName ?? "Someone"
        
        switch event.eventType {
        case "MEMBER_JOINED":
            return "\(userName) joined the circle."
        case "MEMBER_LEFT":
            return "\(userName) left the circle."
        case "ACTIVITY_COMPLETED":
            if let activityName = event.userCompletedLog?.activity?.name {
                return "\(userName) completed \(activityName)."
            } else {
                return "\(userName) completed an activity."
            }
        default:
            return "An event occurred: \(event.eventType)"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                // Left emoji - aligned with content, using same emoji logic as DashboardView
                Text(activityEmoji)
                    .font(.system(size: 24))
                    .frame(width: 32, height: 32, alignment: .center)
                
                // Content - vertical stack
                VStack(alignment: .leading, spacing: 6) {
                    // Header with user name and timestamp
                    HStack {
                        Text(event.user?.firstName ?? "System Event")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(theme.primaryText)
                        
                        Spacer()
                        
                        Text(formatEventTime(event.timestamp))
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(theme.secondaryText)
                    }

                    // Event description
                    Text(formattedEventText())
                        .font(.system(size: 15))
                        .foregroundColor(theme.secondaryText)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }
            }
            .frame(minHeight: 88) // Ensure consistent minimum height like DashboardView ActivityCard
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .fill(theme.background)
                .shadow(
                    color: theme.defaultShadow.color.opacity(0.8), 
                    radius: theme.defaultShadow.radius * 1.5, 
                    x: theme.defaultShadow.x, 
                    y: theme.defaultShadow.y * 1.5
                )
        )
        .onReceive(Timer.publish(every: 30, on: .main, in: .common).autoconnect()) { _ in
            timeUpdateTrigger.toggle()
        }
    }
}

// MARK: - Member Card View
struct FriendGroupMemberCard: View {
    let member: Member
    let isCurrentUserAdmin: Bool
    let currentUserPhone: String
    let onRemoveMember: ((Member) -> Void)?
    
    @Environment(\.theme) private var theme: any Theme
    @State private var showingRemoveConfirmation = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with member name and admin status
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(member.user.firstName) \(member.user.lastName)")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(theme.primaryText)
                    
                    Text("Joined: \(member.dateJoined, style: .date)")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(theme.secondaryText)
                }
                
                Spacer()
                
                HStack(spacing: 8) {
                    if member.isAdmin {
                        HStack(spacing: 4) {
                            Image(systemName: "crown.fill")
                                .font(.system(size: 12))
                                .foregroundColor(theme.accent)
                            
                            Text("Admin")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(theme.accent)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(theme.accent.opacity(0.1))
                        )
                    }
                    
                    // Show ellipsis menu for admins (but not for the current user)
                    if isCurrentUserAdmin && member.user.phone != currentUserPhone {
                        Button(action: { showingRemoveConfirmation = true }) {
                            Image(systemName: "ellipsis")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(theme.secondaryText)
                                .frame(width: 24, height: 24)
                        }
                    }
                }
            }
            
            // Member info section
            HStack(spacing: 16) {
                // Member initials avatar
                Circle()
                    .fill(theme.accent.opacity(0.2))
                    .frame(width: 36, height: 36)
                    .overlay(
                        Text("\(String(member.user.firstName.first ?? "?"))\(String(member.user.lastName.first ?? "?"))")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(theme.accent)
                    )
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Member since")
                        .font(.system(size: 12))
                        .foregroundColor(theme.secondaryText)
                    
                    Text(RelativeDateTimeFormatter().localizedString(for: member.dateJoined, relativeTo: Date()))
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(theme.primaryText)
                }
                
                Spacer()
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .fill(theme.background)
                .shadow(
                    color: theme.defaultShadow.color.opacity(0.8), 
                    radius: theme.defaultShadow.radius * 1.5, 
                    x: theme.defaultShadow.x, 
                    y: theme.defaultShadow.y * 1.5
                )
        )
        .alert("Remove Member", isPresented: $showingRemoveConfirmation) {
            Button("Remove", role: .destructive) {
                onRemoveMember?(member)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to remove \(member.user.firstName) \(member.user.lastName) from this friend circle?")
        }
    }
}

// MARK: - Main Detail View
struct FriendGroupDetailView: View {
    @State var friendCircle: FriendGroup
    @State private var events: [FriendGroupEvent] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showingInviteMembers = false
    let onDismiss: () -> Void
    @EnvironmentObject var authManager: AuthenticationManager
    @Environment(\.theme) private var theme: any Theme

    /// Filters events to only show those within the past 3 days, limited to 10 events
    private var recentEvents: [FriendGroupEvent] {
        let threeDaysAgo = Calendar.current.date(byAdding: .day, value: -3, to: Date()) ?? Date.distantPast
        return events.filter { event in
            event.timestamp > threeDaysAgo
        }.sorted { $0.timestamp > $1.timestamp }
        .prefix(10)
        .map { $0 }
    }
    
    /// Check if current user is an admin of this friend circle
    private var isCurrentUserAdmin: Bool {
        guard let currentUserPhone = authManager.currentUser?.phone else { return false }
        return friendCircle.members.contains { member in
            member.user.phone == currentUserPhone && member.isAdmin
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Cover Image Header
            FriendGroupHeaderView(
                friendCircle: friendCircle, 
                currentUserPhone: authManager.currentUser?.phone ?? "",
                onDismiss: onDismiss,
                onLeave: {
                    Task {
                        await leaveCircle()
                    }
                },
                onTransferAdmin: { member in
                    Task {
                        await transferAdmin(member: member)
                    }
                },
                onCoverImageChange: { newImageUrl in
                    Task {
                        await changeCoverImage(newImageUrl: newImageUrl)
                    }
                },
                onRenameGroup: { newName in
                    Task {
                        await renameGroup(newName: newName)
                    }
                }
            )
                
            // Tab Navigation with transparent background
            TabView {
                // Home Tab
                homeTabView
                    .tabItem {
                        Label("Home", systemImage: "house")
                    }

                // Members Tab
                membersTabView
                    .tabItem {
                        Label("Members", systemImage: "person.3.fill")
                    }
            }
            .background(Color.clear)
            .onAppear {
                // Make TabView background transparent to show grid background
                let appearance = UITabBarAppearance()
                appearance.configureWithTransparentBackground()
                appearance.backgroundColor = UIColor.clear
                UITabBar.appearance().standardAppearance = appearance
                UITabBar.appearance().scrollEdgeAppearance = appearance
            }
        }
        .task {
            await refreshData()
        }
        .ignoresSafeArea(.container, edges: .top)
        .sheet(isPresented: $showingInviteMembers) {
            InviteMembersView(
                friendCircle: friendCircle,
                onDismiss: { showingInviteMembers = false },
                onMembersInvited: {
                    Task {
                        await refreshData()
                    }
                }
            )
            .environmentObject(authManager)
        }
    }

    // MARK: - Tab Views

    private var homeTabView: some View {
        ZStack {
            // Grid background for this tab
            GridBackground()
                .ignoresSafeArea()
            
            // White to clear gradient overlay at the top 20%
            GeometryReader { geometry in
                LinearGradient(
                    gradient: Gradient(colors: [Color("OffWhite"), Color.clear]),
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: geometry.size.height * 0.3)
                .frame(maxHeight: .infinity, alignment: .top)
            }
            .ignoresSafeArea()
            
            ScrollView {
                LazyVStack(spacing: 20) {
                    // Add top spacing to separate from header
                    Spacer()
                        .frame(height: 8)
                    
                    if isLoading {
                        // Competitions section
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("Competitions")
                                    .font(.system(size: 21, weight: .semibold))
                                    .foregroundColor(theme.primaryText)
                                
                                Spacer()
                                
                                Button(action: {
                                    // TODO: Handle create competition action
                                }) {
                                    Image(systemName: "plus")
                                        .font(.system(size: 18, weight: .medium))
                                        .foregroundColor(theme.primaryText)
                                }
                            }
                            .padding(.horizontal, 20)
                            
                            
                            // No active competitions text
                            Text("There are no active competitions.")
                                .font(.system(size: 15))
                                .foregroundColor(theme.secondaryText)
                                .padding(.horizontal, 20)
                                .padding(.top, 8)
                        }
                        .padding(.bottom, 20)
                        
                        // Recent Activity header
                        HStack {
                            Text("Recent Activity")
                                .font(.system(size: 21, weight: .semibold))
                                .foregroundColor(theme.primaryText)
                            
                            Spacer()
                        }
                        .padding(.horizontal, 20)
                        
                        // Loading state card
                        VStack(spacing: 16) {
                            ProgressView("Loading events...")
                        }
                        .padding(24)
                        .background(
                            RoundedRectangle(cornerRadius: 15, style: .continuous)
                                .fill(theme.background)
                                .shadow(
                                    color: theme.defaultShadow.color.opacity(0.8),
                                    radius: theme.defaultShadow.radius * 1.5,
                                    x: theme.defaultShadow.x,
                                    y: theme.defaultShadow.y * 1.5
                                )
                        )
                        .padding(.horizontal, 20)
                    } else if let errorMsg = errorMessage {
                        // Competitions section
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("Competitions")
                                    .font(.system(size: 21, weight: .semibold))
                                    .foregroundColor(theme.primaryText)
                                
                                Spacer()
                                
                                Button(action: {
                                    // TODO: Handle create competition action
                                }) {
                                    Image(systemName: "plus")
                                        .font(.system(size: 18, weight: .medium))
                                        .foregroundColor(theme.primaryText)
                                }
                            }
                            .padding(.horizontal, 20)
                            
                        
                            // No active competitions text
                            Text("There are no active competitions.")
                                .font(.system(size: 15))
                                .foregroundColor(theme.secondaryText)
                                .padding(.horizontal, 20)
                                .padding(.top, 8)
                        }
                        .padding(.bottom, 20)
                        
                        // Recent Activity header
                        HStack {
                            Text("Recent Activity")
                                .font(.system(size: 21, weight: .semibold))
                                .foregroundColor(theme.primaryText)
                            
                            Spacer()
                        }
                        .padding(.horizontal, 20)
                        
                        // Error state card
                        VStack(spacing: 12) {
                            Image(systemName: "exclamationmark.triangle")
                                .font(.system(size: 48))
                                .foregroundColor(theme.secondaryText)
                            
                            Text("Error loading events")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundColor(theme.primaryText)
                            
                            Text(errorMsg)
                                .font(.system(size: 15))
                                .foregroundColor(theme.secondaryText)
                                .multilineTextAlignment(.center)
                        }
                        .padding(24)
                        .background(
                            RoundedRectangle(cornerRadius: 15, style: .continuous)
                                .fill(theme.background)
                                .shadow(
                                    color: theme.defaultShadow.color.opacity(0.8),
                                    radius: theme.defaultShadow.radius * 1.5,
                                    x: theme.defaultShadow.x,
                                    y: theme.defaultShadow.y * 1.5
                                )
                        )
                        .padding(.horizontal, 20)
                    } else if !recentEvents.isEmpty {
                        // Competitions section
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("Competitions")
                                    .font(.system(size: 21, weight: .semibold))
                                    .foregroundColor(theme.primaryText)
                                
                                Spacer()
                                
                                Button(action: {
                                    // TODO: Handle create competition action
                                }) {
                                    Image(systemName: "plus")
                                        .font(.system(size: 18, weight: .medium))
                                        .foregroundColor(theme.primaryText)
                                }
                            }
                            .padding(.horizontal, 20)
                            
                            
                            
                            // No active competitions text
                            Text("There are no active competitions.")
                                .font(.system(size: 15))
                                .foregroundColor(theme.secondaryText)
                                .padding(.horizontal, 20)
                                .padding(.top, 8)
                        }
                        .padding(.bottom, 20)
                        
                        // Recent events header (plain title without card background)
                        HStack {
                            Text("Recent Activity")
                                .font(.system(size: 21, weight: .semibold))
                                .foregroundColor(theme.primaryText)
                            
                            Spacer()
                        }
                        .padding(.horizontal, 20)
                        
                        // Event cards
                        ForEach(recentEvents) { event in
                            FriendGroupEventCard(event: event)
                                .padding(.horizontal, 20)
                        }
                    } else {
                        // Competitions section
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("Competitions")
                                    .font(.system(size: 21, weight: .semibold))
                                    .foregroundColor(theme.primaryText)
                                
                                Spacer()
                                
                                Button(action: {
                                    // TODO: Handle create competition action
                                }) {
                                    Image(systemName: "plus")
                                        .font(.system(size: 18, weight: .medium))
                                        .foregroundColor(theme.primaryText)
                                }
                            }
                            .padding(.horizontal, 20)
                            
                        
                            // No active competitions text
                            Text("There are no active competitions.")
                                .font(.system(size: 15))
                                .foregroundColor(theme.secondaryText)
                                .padding(.horizontal, 20)
                                .padding(.top, 8)
                        }
                        .padding(.bottom, 20)
                        
                        // Recent Activity header (even when empty)
                        HStack {
                            Text("Recent Activity")
                                .font(.system(size: 21, weight: .semibold))
                                .foregroundColor(theme.primaryText)
                            
                            Spacer()
                        }
                        .padding(.horizontal, 20)
                        
                        // Empty state card
                        VStack(spacing: 16) {
                            Image(systemName: "clock")
                                .font(.system(size: 48))
                                .foregroundColor(theme.secondaryText)
                            
                            Text("No recent activity")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundColor(theme.primaryText)
                            
                            Text("Activity from the past 3 days will appear here")
                                .font(.system(size: 15))
                                .foregroundColor(theme.secondaryText)
                                .multilineTextAlignment(.center)
                        }
                        .padding(24)
                        .background(
                            RoundedRectangle(cornerRadius: 15, style: .continuous)
                                .fill(theme.background)
                                .shadow(
                                    color: theme.defaultShadow.color.opacity(0.8),
                                    radius: theme.defaultShadow.radius * 1.5,
                                    x: theme.defaultShadow.x,
                                    y: theme.defaultShadow.y * 1.5
                                )
                        )
                        .padding(.horizontal, 20)
                    }
                    
                    // Bottom spacing for tab bar
                    Spacer()
                        .frame(height: 100)
                }
            }
            .refreshable {
                await refreshData()
            }
        }
    }
    
    private var membersTabView: some View {
        ZStack {
            // Grid background for this tab
            GridBackground()
                .ignoresSafeArea()
            
            // White to clear gradient overlay at the top 20%
            GeometryReader { geometry in
                LinearGradient(
                    gradient: Gradient(colors: [Color("OffWhite"), Color.clear]),
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: geometry.size.height * 0.3)
                .frame(maxHeight: .infinity, alignment: .top)
            }
            .ignoresSafeArea()
            
            ScrollView {
                LazyVStack(spacing: 20) {
                    // Add top spacing to separate from header
                    Spacer()
                        .frame(height: 8)
                    
                    // Members header (plain title without card background)
                    HStack {
                        Text("Members")
                            .font(.system(size: 21, weight: .semibold))
                            .foregroundColor(theme.primaryText)
                        
                        Spacer()
                        
                        Text("\(friendCircle.members.count) total")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(theme.secondaryText)
                        
                        if isCurrentUserAdmin {
                            Button(action: { showingInviteMembers = true }) {
                                HStack(spacing: 4) {
                                    Image(systemName: "plus")
                                        .font(.system(size: 14, weight: .medium))
                                    Text("Invite")
                                        .font(.system(size: 14, weight: .medium))
                                }
                                .foregroundColor(theme.accent)
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    
                    // Member cards
                    ForEach(friendCircle.members) { member in
                        FriendGroupMemberCard(
                            member: member,
                            isCurrentUserAdmin: isCurrentUserAdmin,
                            currentUserPhone: authManager.currentUser?.phone ?? "",
                            onRemoveMember: { memberToRemove in
                                Task {
                                    await removeMember(memberToRemove)
                                }
                            }
                        )
                        .padding(.horizontal, 20)
                    }
                    
                    // Bottom spacing for tab bar
                    Spacer()
                        .frame(height: 100)
                }
            }
        }
    }

    // MARK: - Data Management
    
    private func leaveCircle() async {
        let friendCircleAPI = FriendGroupAPI(httpClient: authManager.httpClient)
        do {
            try await friendCircleAPI.leaveGroup(groupId: friendCircle.id, currentUserPhone: authManager.currentUser?.phone ?? "")
            await MainActor.run {
                onDismiss()
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to leave circle: \(error.localizedDescription)"
            }
        }
    }
    
    private func refreshData() async {
        isLoading = true
        errorMessage = nil
        
        let friendCircleAPI = FriendGroupAPI(httpClient: authManager.httpClient)
        
        do {
            // Fetch both circle details and events in parallel
            async let fetchedCircle = friendCircleAPI.fetchFriendGroupDetail(id: friendCircle.id)
            async let fetchedEvents = friendCircleAPI.fetchFriendGroupEvents(groupId: friendCircle.id)
            
            let (circleResult, eventsResult) = try await (fetchedCircle, fetchedEvents)

            await MainActor.run {
                self.friendCircle = circleResult
                self.events = eventsResult
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to load events: \(error.localizedDescription)"
                self.isLoading = false
                print("Error fetching data in FriendGroupDetailView: \(error)")
            }
        }
    }

    private func transferAdmin(member: Member) async {
        print("FriendGroupDetailView: Starting admin transfer to \(member.user.firstName) \(member.user.lastName) (ID: \(member.id))")
        print("FriendGroupDetailView: Current user phone: \(authManager.currentUser?.phone ?? "nil")")
        print("FriendGroupDetailView: Circle ID: \(friendCircle.id)")
        
        let friendCircleAPI = FriendGroupAPI(httpClient: authManager.httpClient)
        do {
                        try await friendCircleAPI.transferAdmin(
                groupId: friendCircle.id,
                newAdminMemberId: member.id,
                currentUserPhone: authManager.currentUser?.phone ?? ""
            )
            print("FriendGroupDetailView: Admin transfer API call completed successfully")
            
            await MainActor.run {
                print("FriendGroupDetailView: Refreshing friend circle data after admin transfer")
                // Refresh the friend circle to update admin status
                Task {
                    await refreshData()
                }
            }
        } catch {
            print("FriendGroupDetailView: Admin transfer failed with error: \(error)")
            await MainActor.run {
                self.errorMessage = "Failed to transfer admin: \(error.localizedDescription)"
                print("FriendGroupDetailView: Error message set: \(self.errorMessage ?? "nil")")
            }
        }
    }

    private func changeCoverImage(newImageUrl: String) async {
        print("FriendGroupDetailView: Starting cover image change to \(newImageUrl)")
        print("FriendGroupDetailView: Current user phone: \(authManager.currentUser?.phone ?? "nil")")
        print("FriendGroupDetailView: Circle ID: \(friendCircle.id)")
        
        let friendCircleAPI = FriendGroupAPI(httpClient: authManager.httpClient)
        do {
            try await friendCircleAPI.changeCoverImage(
                groupId: friendCircle.id,
                newImageUrl: newImageUrl,
                currentUserPhone: authManager.currentUser?.phone ?? ""
            )
            print("FriendGroupDetailView: Cover image change API call completed successfully")
            
            await MainActor.run {
                print("FriendGroupDetailView: Refreshing friend circle data after cover image change")
                // Refresh the friend circle to update cover image
                Task {
                    await refreshData()
                }
            }
        } catch {
            print("FriendGroupDetailView: Cover image change failed with error: \(error)")
            await MainActor.run {
                self.errorMessage = "Failed to change cover image: \(error.localizedDescription)"
                print("FriendGroupDetailView: Error message set: \(self.errorMessage ?? "nil")")
            }
        }
    }
    
    private func renameGroup(newName: String) async {
        print("FriendGroupDetailView: Starting group rename to \(newName)")
        print("FriendGroupDetailView: Current user phone: \(authManager.currentUser?.phone ?? "nil")")
        print("FriendGroupDetailView: Circle ID: \(friendCircle.id)")
        
        let friendCircleAPI = FriendGroupAPI(httpClient: authManager.httpClient)
        do {
            try await friendCircleAPI.renameGroup(
                groupId: friendCircle.id,
                newName: newName,
                currentUserPhone: authManager.currentUser?.phone ?? ""
            )
            print("FriendGroupDetailView: Group rename API call completed successfully")
            
            await MainActor.run {
                print("FriendGroupDetailView: Refreshing friend circle data after group rename")
                // Refresh the friend circle to update name
                Task {
                    await refreshData()
                }
            }
        } catch {
            print("FriendGroupDetailView: Group rename failed with error: \(error)")
            await MainActor.run {
                self.errorMessage = "Failed to rename group: \(error.localizedDescription)"
                print("FriendGroupDetailView: Error message set: \(self.errorMessage ?? "nil")")
            }
        }
    }
    
    private func removeMember(_ member: Member) async {
        do {
            guard let token = authManager.authToken else {
                throw NSError(domain: "Auth", code: 401, userInfo: [NSLocalizedDescriptionKey: "Not authenticated"])
            }
            
            guard let url = URL(string: "\(AppConfig.apiBaseURL)/friend-groups/\(friendCircle.id)/members/\(member.id)/remove/") else {
                throw NSError(domain: "URL", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])
            }
            
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw NSError(domain: "Network", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid response"])
            }
            
            if httpResponse.statusCode == 200 {
                // Parse success message
                if let responseData = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let message = responseData["message"] as? String {
                    print("Member removed successfully: \(message)")
                }
                
                // Refresh the friend circle data
                await refreshData()
            } else {
                // Parse error message
                if let errorData = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let error = errorData["error"] as? String {
                    await MainActor.run {
                        self.errorMessage = error
                    }
                } else {
                    await MainActor.run {
                        self.errorMessage = "Failed to remove member"
                    }
                }
            }
            
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to remove member: \(error.localizedDescription)"
            }
        }
    }
}

// MARK: - Preview
struct FriendGroupDetailView_Previews: PreviewProvider {
    static var previews: some View {
        let sampleCircle = FriendGroup(
            id: 1,
            name: "Fitness Enthusiasts",
            members: [],
            coverImage: "friendgroupimage0" // Use asset catalog image for preview
        )
        
        FriendGroupDetailView(
            friendCircle: sampleCircle,
            onDismiss: { print("Preview dismiss") }
        )
        .environmentObject(PreviewConstants.sampleAuthManagerUpdated)
        .environment(\.theme, LiquidGlassTheme())
    }
}
