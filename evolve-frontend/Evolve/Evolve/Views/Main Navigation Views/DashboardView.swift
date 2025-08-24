import SwiftUI
import UniformTypeIdentifiers
import Combine


extension Date {
    func startOfWeek(using calendar: Calendar = .current) -> Date {
        calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: self))!
    }

    func currentWeekDays(using calendar: Calendar = .current) -> [Date] {
        let startOfWeek = self.startOfWeek(using: calendar)
        return (0..<7).map { calendar.date(byAdding: .day, value: $0, to: startOfWeek)! }
    }
    
//    func formattedDateString() -> String {
//        let formatter = DateFormatter()
//        formatter.dateFormat = "yyyy-MM-dd"
//        return formatter.string(from: self)
//    }
    
    func dayName(style: DateFormatter.Style = .short) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = (style == .short) ? "E" : "EEEE" // E.g., "Mon" or "Monday"
        return formatter.string(from: self)
    }
}

// MARK: - CardModel
/// A simple data model representing a card displayed in `DashboardView`.
/// Extend or replace `mainContent` with concrete content once your real views are available.
// struct CardModel: Identifiable, Equatable {
//     let id = UUID()
//     var mainContent: AnyView

//     static func == (lhs: CardModel, rhs: CardModel) -> Bool {
//         lhs.id == rhs.id
//     }
// }

// // MARK: - CardView
// struct CardView: View {
//     var card: CardModel
//     @Environment(\.theme) private var theme: any Theme

//     var body: some View {
//         VStack(alignment: .leading, spacing: 8) {
//             card.mainContent
//         }
//         .padding()
//         .frame(maxWidth: .infinity, alignment: .leading)
//         .background(
//             RoundedRectangle(cornerRadius: 15, style: .continuous)
//                 .fill(theme.background)
//                 .shadow(color: theme.defaultShadow.color, radius: theme.defaultShadow.radius, x: theme.defaultShadow.x, y: theme.defaultShadow.y)
//         )
//     }
// }

// MARK: - Max Chat Prompt View
/// A reusable button style that adds a subtle press animation (scale & opacity) for visual feedback.
private struct PressableButtonStyle: ButtonStyle {
    var scaleAmount: CGFloat = 0.96
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scaleAmount : 1)
            .opacity(configuration.isPressed ? 0.85 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

/// A view that mimics a search bar to prompt interaction with "Max", the AI assistant.
/// Tapping it presents the main chat view.
//struct MaxChatPromptView: View {
//    /// The action to perform when the view is tapped.
//    var action: () -> Void
//
//    var body: some View {
//        Button(action: action) {
//            HStack(spacing: 12) {
//                Image(systemName: "brain.head.profile")
//                    .font(.clashGrotesk(22))
//                    .foregroundStyle(
//                        AngularGradient(
//                            gradient: Gradient(colors: [Color("Fitness"), Color("Nutrition"), Color("Sleep"), Color("Mind"), Color("Fitness")]),
//                            center: .center
//                        )
//                    )
//
//                Text("Ask anything")
//                    .font(.clashGrotesk(17))
//                    .foregroundColor(.secondary)
//                
//                Spacer()
//            }
//            .padding()
//            .frame(height: 52)
//            .background(
//                Capsule()
//                    .fill(Color.white)
//                    .shadow(color: Color.black.opacity(0.12), radius: 8, x: 0, y: 4)
//                    .shadow(color: Color.black.opacity(0.08), radius: 2, x: 0, y: 1)
//            )
//        }
//        .buttonStyle(PressableButtonStyle())
//    }
//}

// MARK: - Shortcuts Feature

struct ShortcutCardView: View {
    let userShortcut: UserShortcut
    var scale: CGFloat = 1.0
    var isEditing: Bool = false
    var onDelete: (() -> Void)? = nil
    @Environment(\.theme) private var theme: any Theme
    @State private var jiggleAngle: Double = 0

    /// Returns an emoji icon based on the shortcut's action identifier
    private var shortcutEmoji: String {
        switch userShortcut.shortcut.actionIdentifier {
        case "new_workout":
            return "🏋️"
        case "log_food":
            return "🍽️"
        case "new_entry":
            return "📔"
        case "meditate":
            return "🧘"
        case "sleep_tracking", "smart_alarm":
            return "😴"
        case "water_intake", "log_hydration":
            return "💧"
        case "habit_tracking":
            return "✅"
        case "mood_check":
            return "😊"
        case "weight_tracking":
            return "⚖️"
        case "steps_tracking":
            return "🚶"
        case "heart_rate":
            return "❤️"
        case "calorie_tracking":
            return "🔥"
        case "log_caffeine":
            return "☕"
        case "new_pr", "personal_record":
            return "🏆"
        case "breathe":
            return "🌬️"
        case "journal_entry":
            return "📖"
        case "sleep_debt":
            return "😪"
        case "log_alcohol":
            return "🍷"
        case "log_prescription", "medication":
            return "💊"
        case "log_sex":
            return "💕"
        case "recipe_creation":
            return "👨‍🍳"
        case "log_symptoms":
            return "🌡️"
        case "track_cycle":
            return "🌸"
        case "blood_pressure":
            return "🩺"
        case "supplements":
            return "🍃"
        case "mindfulness":
            return "🧠"
        case "gratitude":
            return "🙏"
        case "energy_levels":
            return "⚡"
        default:
            return "⭐"
        }
    }

    var body: some View {
        VStack(spacing: 8 * scale) {
            // Card with emoji icon
            ZStack {
                RoundedRectangle(cornerRadius: 16 * scale)
                    .fill(Color.white)
                    .frame(width: 90 * scale, height: 90 * scale)
                    .shadow(color: theme.defaultShadow.color.opacity(0.8), radius: theme.defaultShadow.radius * 1.5, x: theme.defaultShadow.x, y: theme.defaultShadow.y * 1.5)
                
                // Emoji icon
                Text(shortcutEmoji)
                    .font(.system(size: 42 * scale))
                
                // Delete button
                if isEditing {
                    ZStack {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 22 * scale, height: 22 * scale)
                        
                        Image(systemName: "xmark")
                            .font(.system(size: 10 * scale, weight: .bold))
                            .foregroundColor(.white)
                    }
                    .offset(x: 40 * scale, y: -40 * scale)
                    .onTapGesture {
                        onDelete?()
                    }
                    .zIndex(1) // Ensure button is on top
                }
            }
            
            // Text below the card
            Text(userShortcut.shortcut.name)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(theme.primaryText)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .frame(width: 90 * scale)
        }
        .rotationEffect(.degrees(isEditing ? jiggleAngle : 0))
        .onAppear {
            if isEditing {
                withAnimation(
                    Animation.easeInOut(duration: 0.12)
                        .repeatForever(autoreverses: true)
                ) {
                    jiggleAngle = 2
                }
            }
        }
        .onChange(of: isEditing) { oldValue, newValue in
            if newValue {
                withAnimation(
                    Animation.easeInOut(duration: 0.12)
                        .repeatForever(autoreverses: true)
                ) {
                    jiggleAngle = 2
                }
            } else {
                withAnimation(.default) {
                    jiggleAngle = 0
                }
            }
        }
    }
}

struct PlaceholderShortcutCardView: View {
    var scale: CGFloat = 1.0
    @Environment(\.theme) private var theme: any Theme
    
    var body: some View {
        VStack(spacing: 8 * scale) {
            // Square placeholder card
            ZStack {
                RoundedRectangle(cornerRadius: 16 * scale)
                    .fill(Color.white.opacity(0.3))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16 * scale)
                            .stroke(Color.black.opacity(0.5), lineWidth: 1)
                    )
                
                Image(systemName: "plus")
                    .font(.system(size: 32 * scale, weight: .medium))
                    .foregroundColor(.black.opacity(0.8))
            }
            .frame(width: 90 * scale, height: 90 * scale)
            .shadow(color: theme.defaultShadow.color.opacity(0.3), radius: theme.defaultShadow.radius / 2, x: theme.defaultShadow.x, y: theme.defaultShadow.y / 2)
            
            // Placeholder text below the card
            Text("Add Shortcut")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(theme.primaryText)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .frame(width: 90 * scale)
        }
    }
}

struct ShortcutsView: View {
    @Binding var shortcuts: [UserShortcut]
    @Binding var isEditing: Bool
    var onSelect: (UserShortcut) -> Void
    var onDelete: (UserShortcut) -> Void
    var onReorder: ([UserShortcut]) -> Void
    var onAdd: () -> Void
    var scale: CGFloat = 1.0
    private let maxShortcuts = 4
    @State private var draggedItem: UserShortcut?
    @State private var isDraggable: Set<UUID> = []
    @GestureState private var dragOffset: CGSize = .zero
    
    // Show add button only if we have less than 4 shortcuts
    private var shouldShowAddButton: Bool {
        shortcuts.count < maxShortcuts
    }

    var body: some View {
        HStack(spacing: 12 * scale) {
            Spacer()
            
            // Show shortcuts (up to 4)
            ForEach(Array(shortcuts.enumerated()), id: \.element.id) { index, userShortcut in
                shortcutCardView(for: userShortcut, at: index)
            }
            
            // Show add button if we have less than 4 shortcuts
            if shouldShowAddButton {
                Button(action: onAdd) {
                    PlaceholderShortcutCardView(scale: scale)
                }
            }
            
            Spacer()
        }
        .padding(.vertical, 8 * scale)
        .onChange(of: isEditing) { oldValue, newValue in
            if !newValue {
                // Clear draggable state when exiting edit mode
                isDraggable.removeAll()
                draggedItem = nil
            }
        }
    }
    
    @ViewBuilder
    private func shortcutCardView(for userShortcut: UserShortcut, at index: Int) -> some View {
        if isEditing {
            ShortcutCardView(
                userShortcut: userShortcut,
                scale: scale,
                isEditing: isEditing,
                onDelete: {
                    onDelete(userShortcut)
                }
            )
            .offset(x: draggedItem?.id == userShortcut.id ? dragOffset.width : 0,
                    y: draggedItem?.id == userShortcut.id ? dragOffset.height : 0)
            .opacity(draggedItem?.id == userShortcut.id ? 0.8 : 1.0)
            .scaleEffect(draggedItem?.id == userShortcut.id ? 1.05 : 1.0)
            .zIndex(draggedItem?.id == userShortcut.id ? 1 : 0)
            .gesture(
                LongPressGesture(minimumDuration: 0.3)
                    .onEnded { _ in
                        isDraggable.insert(userShortcut.id)
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    }
                    .sequenced(before:
                        DragGesture()
                            .updating($dragOffset) { value, state, _ in
                                if isDraggable.contains(userShortcut.id) {
                                    state = value.translation
                                }
                            }
                            .onChanged { value in
                                if isDraggable.contains(userShortcut.id) {
                                    if draggedItem == nil {
                                        draggedItem = userShortcut
                                    }
                                    
                                    // Calculate which card we're over based on horizontal movement only
                                    let cardWidth = 90 * scale + 12 * scale
                                    let currentIndex = index
                                    let horizontalMovement = value.translation.width
                                    
                                    // Calculate new position (horizontal only)
                                    let newIndex = currentIndex + Int(round(horizontalMovement / cardWidth))
                                    
                                    if newIndex != currentIndex && newIndex >= 0 && newIndex < shortcuts.count {
                                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                            shortcuts.move(fromOffsets: IndexSet(integer: currentIndex),
                                                         toOffset: newIndex > currentIndex ? newIndex + 1 : newIndex)
                                        }
                                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                    }
                                }
                            }
                            .onEnded { _ in
                                onReorder(shortcuts)
                                withAnimation(.spring()) {
                                    draggedItem = nil
                                    isDraggable.removeAll(keepingCapacity: true)
                                }
                            }
                    )
            )
            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: draggedItem)
        } else {
            ShortcutCardView(
                userShortcut: userShortcut,
                scale: scale,
                isEditing: isEditing
            )
            .onTapGesture {
                onSelect(userShortcut)
            }
            .onLongPressGesture(minimumDuration: 0.5) {
                withAnimation {
                    isEditing = true
                    // Haptic feedback
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                }
            }
        }
    }
}



// MARK: - View + Conditional Modifier Helper
extension View {
    /// Conditionally apply a modifier to any `View`.
    /// - Parameters:
    ///   - condition: Boolean deciding whether to apply the modifier.
    ///   - transform: The modifier to apply when the condition is true.
    /// - Returns: Either the modified view or `self`.
    @ViewBuilder func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition { transform(self) } else { self }
    }
}

// MARK: - Activity Tag View (reused from JourneyView pattern)
private struct ActivityTagView: View {
    let category: String      // Used for color (e.g., "Mind", "Fitness")
    let displayText: String   // Used for display (e.g., "Workout", "Meal")
    @Environment(\.theme) private var theme: any Theme
    
    private var tagColor: Color {
        return ActivityTypeHelper.color(for: category)
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

// MARK: - Activity Section
struct ActivityCard: View {
    let userActivity: UserScheduledActivity
    var onPlay: () -> Void
    var onMarkComplete: (UserScheduledActivity) -> Void // New completion callback
    @Environment(\.theme) private var theme: any Theme
    @EnvironmentObject var progressManager: ActivityProgressManager
    @State private var showingMenu = false
    @State private var isMarkingComplete = false // Loading state for completion
    
    // Determine emoji based on activity type first, then fall back to category
    private var activityEmoji: String {
        return ActivityTypeHelper.getEmoji(
            activityType: userActivity.activity.activityType,
            categories: userActivity.activity.category
        )
    }
    
    // Sample scheduled time - in a real app this would come from the model
    private var scheduledTime: String {
        userActivity.scheduledDisplayTime ?? "Anytime"
    }
    
    private var categoryDisplayText: String {
        // Use activity_type if available, properly capitalized
        if let activityType = userActivity.activity.activityType, !activityType.isEmpty {
            return ActivityTypeHelper.formatActivityType(activityType)
        }
        
        // Fallback to category-based display
        if let firstCategory = userActivity.activity.category.first {
            return firstCategory.capitalized
        }
        return "Activity"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 12) {
                // Left emoji - aligned with time
                Text(activityEmoji)
                    .font(.system(size: 24))
                    .frame(width: 32, height: 32, alignment: .center)
                
                // Content - vertical stack
                VStack(alignment: .leading, spacing: 6) {
                    // Scheduled time
                    Text(scheduledTime)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(theme.secondaryText)
                    
                    // Activity title (up to 2 lines)
                    Text(userActivity.activity.name)
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(theme.primaryText)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    
                    // Category tag
                    HStack {
                        if let firstCategory = userActivity.activity.category.first {
                            ActivityTagView(category: firstCategory, displayText: categoryDisplayText)
                        }
                        Spacer()
                    }
                }
                
                Spacer()
                
                // Right side: Three dots menu and completion status
                VStack(spacing: 4) {
                    // Three dots menu in top right corner
                    Button(action: { showingMenu = true }) {
                        if isMarkingComplete {
                            ProgressView()
                                .scaleEffect(0.8)
                                .frame(width: 30, height: 30)
                        } else {
                            Image(systemName: "ellipsis")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(theme.secondaryText)
                                .frame(width: 30, height: 30)
                                .background(Circle().fill(Color.clear))
                        }
                    }
                    .disabled(isMarkingComplete)
                    
                    // Completion checkmark below the three dots
                    if userActivity.isComplete {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.green)
                    } else if progressManager.isInProgress(userActivity.id) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.yellow)
                    } else {
                        // Invisible spacer to maintain consistent layout
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.clear)
                    }
                }
            }
            .frame(minHeight: 88) // Ensure consistent minimum height (adjusted for content)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .fill(theme.background)
                .shadow(color: theme.defaultShadow.color.opacity(0.8), radius: theme.defaultShadow.radius * 1.5, x: theme.defaultShadow.x, y: theme.defaultShadow.y * 1.5)
        )
        .onTapGesture {
            if !isMarkingComplete && !userActivity.isComplete {
                onPlay()
            }
        }
        .sheet(isPresented: $showingMenu) {
            ActivityMenuView(
                activity: userActivity,
                onMarkComplete: {
                    isMarkingComplete = true
                    onMarkComplete(userActivity)
                    // Reset loading state after a delay to allow parent to handle the completion
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        isMarkingComplete = false
                    }
                }
            )
            .presentationDetents([.height(userActivity.isComplete ? 160 : 200)]) // Adjust height based on completion status
        }
    }
}

// MARK: - Activity Menu View
private struct ActivityMenuView: View {
    let activity: UserScheduledActivity
    let onMarkComplete: () -> Void
    @Environment(\.dismiss) private var dismiss
    @Environment(\.theme) private var theme: any Theme
    
    var body: some View {
        VStack(spacing: 0) {
            // Handle bar
            RoundedRectangle(cornerRadius: 3)
                .fill(Color.secondary.opacity(0.3))
                .frame(width: 40, height: 6)
                .padding(.top, 8)
                .padding(.bottom, 20)
            
            VStack(spacing: 16) {
                // Show "Mark as completed" option only if not already complete
                if !activity.isComplete {
                    MenuButton(icon: "checkmark.circle", title: "Mark as completed") {
                        dismiss()
                        onMarkComplete()
                    }
                }
                
                MenuButton(icon: "rectangle.3.group", title: "Change layout") {
                    dismiss()
                    // Handle change layout action
                }
                
                MenuButton(icon: "pencil", title: "Edit activity") {
                    dismiss()
                    // Handle edit activity action
                }
                
                MenuButton(icon: "trash", title: "Delete activity", isDestructive: true) {
                    dismiss()
                    // Handle delete activity action
                }
            }
            .padding(.horizontal, 20)
            
            Spacer()
        }
        .background(theme.background)
    }
}

// MARK: - Menu Button
private struct MenuButton: View {
    let icon: String
    let title: String
    let isDestructive: Bool
    let action: () -> Void
    @Environment(\.theme) private var theme: any Theme
    
    init(icon: String, title: String, isDestructive: Bool = false, action: @escaping () -> Void) {
        self.icon = icon
        self.title = title
        self.isDestructive = isDestructive
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundColor(isDestructive ? .red : theme.primaryText)
                    .frame(width: 24)
                
                Text(title)
                    .font(.system(size: 17))
                    .foregroundColor(isDestructive ? .red : theme.primaryText)
                
                Spacer()
            }
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
    }
}

struct ActivitySection: View {
    @Binding var selectedDate: Date
    let activities: [UserScheduledActivity]
    var onPlayWorkout: (UserScheduledActivity) -> Void
    var onShowReading: (UserScheduledActivity) -> Void
    var onMarkComplete: (UserScheduledActivity) -> Void // New completion callback
    @Environment(\.theme) private var theme: any Theme

    private var header: some View {
        HStack {
            Text(dayTitle)
                .font(.system(size: 21, weight: .semibold))
                .foregroundColor(theme.primaryText)
            
            Spacer()
            
            Button(action: {
                withAnimation {
                    selectedDate = Calendar.current.date(byAdding: .day, value: -1, to: selectedDate) ?? selectedDate
                }
            }) {
                Image(systemName: "chevron.left")
                    .foregroundColor(theme.primaryText)
            }
            
            Button(action: {
                withAnimation {
                    selectedDate = Date()
                }
            }) {
                Text("Today")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(theme.primaryText)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(theme.primaryText.opacity(0.1))
                    )
            }
            .padding(.horizontal, 12)
            
            Button(action: {
                withAnimation {
                    selectedDate = Calendar.current.date(byAdding: .day, value: 1, to: selectedDate) ?? selectedDate
                }
            }) {
                Image(systemName: "chevron.right")
                    .foregroundColor(theme.primaryText)
            }
        }
    }
    
    private var dayTitle: String {
        if Calendar.current.isDateInToday(selectedDate) {
            return "Today's Plan"
        } else if Calendar.current.isDateInYesterday(selectedDate) {
            return "Yesterday's Plan"
        } else if Calendar.current.isDateInTomorrow(selectedDate) {
            return "Tomorrow's Plan"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "EEEE"
            return "\(formatter.string(from: selectedDate))'s Plan"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            header
            dayContent(for: selectedDate)
                .frame(minHeight: contentHeight)
        }
    }
    
    private var contentHeight: CGFloat {
        if activities.isEmpty {
            return 150
        } else {
            // Height calculation based on estimated card height (similar to GoalCard)
            let estimatedCardHeight: CGFloat = 120 // Estimated height for activity cards
            let spacing: CGFloat = 20
            return CGFloat(activities.count) * estimatedCardHeight + CGFloat(activities.count - 1) * spacing
        }
    }
    
    @ViewBuilder
    private func dayContent(for date: Date) -> some View {
        let dateStr = date.formattedDateString()
        let dayActivities = authManager.currentUser?.scheduledActivities?.filter { $0.scheduledDate == dateStr } ?? []
        
        if dayActivities.isEmpty {
            VStack(spacing: 16) {
                Text("There's nothing scheduled today.")
                    .font(.system(size: 16))
                    .foregroundColor(theme.secondaryText)
            }
            .padding(.horizontal)         
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            VStack(spacing: 20) {
                ForEach(dayActivities) { activity in
                    ActivityCard(
                        userActivity: activity,
                        onPlay: {
                            if activity.activity.associatedWorkout != nil {
                                onPlayWorkout(activity)
                            } else if activity.activity.associatedReading != nil {
                                onShowReading(activity)
                            }
                        },
                        onMarkComplete: { activityToComplete in
                            onMarkComplete(activityToComplete)
                        }
                    )
                }
            }
        }
    }
    
    @EnvironmentObject private var authManager: AuthenticationManager
}



// MARK: - Workout Progress Data
struct WorkoutProgress: Codable {
    let activityId: UUID
    let workoutId: UUID
    let currentExerciseIndex: Int
    let currentSet: Int
    let completedExercises: [UUID] // Track which exercises are completed
    let timestamp: Date
    
    init(activityId: UUID, workoutId: UUID, exerciseIndex: Int, set: Int, completedExercises: [UUID]) {
        self.activityId = activityId
        self.workoutId = workoutId
        self.currentExerciseIndex = exerciseIndex
        self.currentSet = set
        self.completedExercises = completedExercises
        self.timestamp = Date()
    }
}

// MARK: - Activity Progress Manager
class ActivityProgressManager: ObservableObject {
    @Published private var workoutProgress: [UUID: WorkoutProgress] = [:]
    
    private let userDefaults = UserDefaults.standard
    private let progressKey = "WorkoutProgress"
    
    init() {
        loadWorkoutProgress()
    }
    
    func isInProgress(_ activityId: UUID) -> Bool {
        return workoutProgress[activityId] != nil
    }
    
    func saveWorkoutProgress(activityId: UUID, workoutId: UUID, exerciseIndex: Int, currentSet: Int, completedExercises: [UUID]) {
        let progress = WorkoutProgress(
            activityId: activityId,
            workoutId: workoutId,
            exerciseIndex: exerciseIndex,
            set: currentSet,
            completedExercises: completedExercises
        )
        workoutProgress[activityId] = progress
        saveProgressToStorage()
    }
    
    func getWorkoutProgress(_ activityId: UUID) -> WorkoutProgress? {
        return workoutProgress[activityId]
    }
    
    func clearProgress(_ activityId: UUID) {
        workoutProgress.removeValue(forKey: activityId)
        saveProgressToStorage()
    }
    
    func setInProgress(_ activityId: UUID, inProgress: Bool) {
        // Backwards compatibility - if setting to false, clear progress
        if !inProgress {
            clearProgress(activityId)
        }
    }
    
    private func loadWorkoutProgress() {
        if let data = userDefaults.data(forKey: progressKey),
           let decoded = try? JSONDecoder().decode([UUID: WorkoutProgress].self, from: data) {
            workoutProgress = decoded
        }
    }
    
    private func saveProgressToStorage() {
        if let encoded = try? JSONEncoder().encode(workoutProgress) {
            userDefaults.set(encoded, forKey: progressKey)
        }
    }
}

// MARK: - Dashboard Overview Card
private struct DashboardOverviewCard: View {
    @Environment(\.theme) private var theme: any Theme
    @ObservedObject var nutritionViewModel: NutritionViewModel
    @ObservedObject var healthKitManager: HealthKitManager
    
    // Mock data for other categories - same as JourneyView
    private let sleepScore: Int = 85
    private let maxSleepScore: Int = 100
    private let activeMinutes: Int = 25
    private let activeMinutesGoal: Int = 30
    
    // Colors for each category
    private let nutritionColor = Color("Nutrition")
    private let sleepColor = Color("Sleep")
    private let fitnessColor = Color("Fitness")
    private let mindColor = Color("Mind")
    
    var body: some View {
        HStack(spacing: 15) {
            // Nutrition - Calories Left Dial (now using real data)
            DashboardDialView(
                name: "Calories left",
                current: Double(nutritionViewModel.summary.caloriesEaten), // actual calories eaten
                goal: Double(nutritionViewModel.summary.caloriesGoal), // actual goal
                remaining: nutritionViewModel.summary.caloriesLeft, // actual calories left
                color: nutritionColor,
                unit: "",
                showIcon: true,
                iconName: "flame.fill"
            )
            .frame(maxWidth: .infinity)
            
            // Sleep - Sleep Score Dial
            DashboardDialView(
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
            DashboardDialView(
                name: "Steps today",
                current: Double(healthKitManager.stepCount),
                goal: Double(healthKitManager.stepGoal),
                remaining: nil,
                color: fitnessColor,
                unit: "",
                showIcon: true,
                iconName: "figure.walk"
            )
            .frame(maxWidth: .infinity)
            .onTapGesture {
                // Request HealthKit permissions if not already authorized
                if !healthKitManager.isAuthorized {
                    healthKitManager.requestHealthKitPermissions()
                } else {
                    healthKitManager.refreshStepData()
                }
            }
            
            // Mind - Active Minutes Dial
            DashboardDialView(
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
        .onAppear {
            print("DashboardOverviewCard: onAppear - Calories eaten: \(nutritionViewModel.summary.caloriesEaten), Goal: \(nutritionViewModel.summary.caloriesGoal), Left: \(nutritionViewModel.summary.caloriesLeft)")
        }
        .onChange(of: nutritionViewModel.summary.caloriesEaten) { _, newValue in
            print("DashboardOverviewCard: caloriesEaten changed to \(newValue)")
        }
        .onChange(of: nutritionViewModel.summary.caloriesGoal) { _, newValue in
            print("DashboardOverviewCard: caloriesGoal changed to \(newValue)")
        }
    }
}

// MARK: - Dashboard Dial View
private struct DashboardDialView: View {
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

// MARK: - DashboardView
/// Displays a scrollable, reorderable list of `CardView`s on top of a horizontal gradient background.
struct DashboardView: View {
    @Binding var selectedDate: Date
    @Binding var isModalActive: Bool
    @EnvironmentObject var authManager: AuthenticationManager
    @StateObject private var progressManager = ActivityProgressManager()
    @StateObject private var nutritionViewModel: NutritionViewModel
    @StateObject private var healthKitManager = HealthKitManager()
    

    /// The user activity that has an associated workout to be played. When this is set, the workout view is presented.
    @State private var activityForWorkout: UserScheduledActivity?
    /// Controls the presentation of the chat view for interacting with Max.
    @State private var showMaxChatView = false

    // States for modal presentation, similar to MyShortcutsView
    @State private var showWorkoutList = false
    @State private var showEmotionsView = false
    @State private var showJourneyView = false
    @State private var showMeditationsView = false
    @State private var showHabitsView = false
    @Environment(\.theme) private var theme: any Theme

    // New state for adding shortcuts
    @State private var showAddShortcutSheet = false
    
    // States for shortcut editing
    @State private var isEditingShortcuts = false
    
    // Custom initializer to inject AuthenticationManager into NutritionViewModel
    init(selectedDate: Binding<Date>, isModalActive: Binding<Bool>, authManager: AuthenticationManager) {
        self._selectedDate = selectedDate
        self._isModalActive = isModalActive
        self._nutritionViewModel = StateObject(wrappedValue: NutritionViewModel(authManager: authManager))
    }

    /// The user's shortcuts, derived from the authenticated user and sorted by order.
    private var userShortcuts: [UserShortcut] {
        authManager.currentUser?.shortcutSelections?.sorted(by: { $0.order < $1.order }) ?? []
    }

    /// The color for the left side of the background gradient.
    private let leftGradientColor: Color = Color("Fitness")
    private let rightGradientColor: Color = Color("Sleep")
    
    @State private var useGradientBackground = false
    
    // Get the dynamic theme color from environment
    @Environment(\.dynamicThemeColor) private var dynamicThemeColor

    // Note: Removed unused cards array and drag functionality

    /// A computed property that filters and returns `UserScheduledActivity`s for the `selectedDate`.
    private var activitiesForSelectedDate: [UserScheduledActivity] {
        let dateStr = selectedDate.formattedDateString()
        return authManager.currentUser?.scheduledActivities?.filter { $0.scheduledDate == dateStr } ?? []
    }

    private func performShortcutAction(for identifier: String) {
        // These identifiers must match the `action_identifier` in the backend `Shortcut` model.
        switch identifier {
        case "new_workout":
            cinematicManager.present("workout_wizard")
        case "log_food":
            cinematicManager.present("nutrition")
        case "new_entry", "journal_entry":
            cinematicManager.present("journal")
        default:
            print("Unhandled shortcut action identifier: \(identifier)")
        }
    }
    
    private func deleteShortcut(_ userShortcut: UserShortcut) {
        // 1. Optimistically update UI
        if var user = authManager.currentUser {
            user.shortcutSelections?.removeAll { $0.id == userShortcut.id }
            authManager.currentUser = user
        }
        
        // 2. Call API
        Task {
            let client = authManager.httpClient
            do {
                try await ShortcutAPIService(httpClient: client).delete(userShortcutId: userShortcut.id)
                // On success, refetch to ensure data is perfectly in sync
                authManager.fetchCurrentUserDetails()
            } catch {
                // On failure, revert the UI by refetching user details
                print("Failed to delete shortcut: \(error)")
                authManager.fetchCurrentUserDetails()
            }
        }
    }
    
    private func reorderShortcuts(newUserShortcuts: [UserShortcut]) {
        // 1. Optimistically update UI
        if var user = authManager.currentUser {
            user.shortcutSelections = newUserShortcuts
            authManager.currentUser = user
        }
        
        // 2. Call API
        let orderedIds = newUserShortcuts.map { $0.id }
        Task {
            let client = authManager.httpClient
            do {
                _ = try await ShortcutAPIService(httpClient: client).reorder(orderedIds: orderedIds)
                // Refetch to confirm order and get fresh data
                authManager.fetchCurrentUserDetails()
            } catch {
                // Revert on failure by refetching the source of truth
                print("Failed to reorder shortcuts: \(error)")
                authManager.fetchCurrentUserDetails()
            }
        }
    }
    
    private func handleAddShortcut() {
        self.showAddShortcutSheet = true
    }
    
    /// Marks a scheduled activity as complete using the UserActivityAPI
    /// Updates the UI optimistically and handles backend synchronization
    private func markActivityAsComplete(_ activity: UserScheduledActivity) {
        // Optimistically update the UI immediately
        updateActivityCompletionStatus(activity.id, isComplete: true)
        
        // Make the API call
        Task {
            do {
                let userActivityAPI = UserActivityAPI(httpClient: authManager.httpClient)
                let updatedActivity = try await userActivityAPI.markActivityComplete(
                    activityId: activity.id,
                    notes: "Completed from dashboard"
                )
                
                // On success, update with the server response to ensure accuracy
                await MainActor.run {
                    updateActivityWithServerResponse(updatedActivity)
                    // Show brief success feedback
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                }
                
                // Refresh user details to get any additional updates (points, completion logs, etc.)
                authManager.fetchCurrentUserDetails()
                
            } catch {
                // On failure, revert the optimistic update
                await MainActor.run {
                    updateActivityCompletionStatus(activity.id, isComplete: false)
                    // Show error feedback
                    UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                    print("Failed to mark activity as complete: \(error)")
                    // TODO: Show user-facing error message
                }
            }
        }
    }
    
    /// Helper function to optimistically update activity completion status in the local state
    private func updateActivityCompletionStatus(_ activityId: UUID, isComplete: Bool) {
        guard var user = authManager.currentUser else { return }
        
        if let index = user.scheduledActivities?.firstIndex(where: { $0.id == activityId }) {
            user.scheduledActivities?[index].isComplete = isComplete
            if isComplete {
                user.scheduledActivities?[index].completedAt = ISO8601DateFormatter().string(from: Date())
            } else {
                user.scheduledActivities?[index].completedAt = nil
            }
            authManager.currentUser = user
        }
    }
    
    /// Helper function to update activity with server response
    private func updateActivityWithServerResponse(_ updatedActivity: UserScheduledActivity) {
        guard var user = authManager.currentUser else { return }
        
        if let index = user.scheduledActivities?.firstIndex(where: { $0.id == updatedActivity.id }) {
            user.scheduledActivities?[index] = updatedActivity
            authManager.currentUser = user
        }
    }

    // New states for confirmation . 
    @State private var showConfirmationModal = false
    @State private var selectedActivityForConfirmation: UserScheduledActivity? = nil
    
    // State for cinematic transition
    @StateObject private var cinematicManager = CinematicStateManager()
    @State private var activeWorkout: Workout? = nil

    var body: some View {
        GeometryReader { geometry in
            let designWidth: CGFloat = 430
            let scale = geometry.size.width / designWidth
            ZStack {
                // Background – mimics the one used in SharedPageView.
                GridBackground()
                
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

                // Dashboard content
                VStack(spacing: 0) {
                    // Content
                    ScrollView {
                        LazyVStack(spacing: 20) {
                            // Header with date and settings
                            DashboardHeaderView(onSettingsTap: {
                                cinematicManager.present("settings")
                            })
                                .padding(.horizontal)
                                .padding(.bottom, 0) // Add spacing between header and content
                                                
                            
                            // My Shortcuts Section
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text("My Shortcuts")
                                        .font(.system(size: 21, weight: .semibold))
                                        .foregroundColor(theme.primaryText)
                                    
                                    Spacer()
                                    
                                    if isEditingShortcuts {
                                        Button("Done") {
                                            withAnimation {
                                                isEditingShortcuts = false
                                            }
                                        }
                                        .font(.system(size: 17, weight: .medium))
                                        .foregroundColor(theme.primaryText)
                                    } else {
                                        Button("Edit") {
                                            withAnimation {
                                                isEditingShortcuts = true
                                            }
                                        }
                                        .font(.system(size: 17, weight: .medium))
                                        .foregroundColor(theme.primaryText)
                                    }
                                }
                                .padding(.horizontal)
                                
                                ShortcutsView(
                                    shortcuts: Binding(
                                        get: { userShortcuts },
                                        set: { newShortcuts in
                                            // This setter is called by the drag/drop logic to update the local state during the gesture.
                                            // The final reorder API call is made in the onReorder callback.
                                            var updatedUser = authManager.currentUser
                                            updatedUser?.shortcutSelections = newShortcuts
                                            authManager.currentUser = updatedUser
                                        }
                                    ),
                                    isEditing: $isEditingShortcuts,
                                    onSelect: { userShortcut in
                                        performShortcutAction(for: userShortcut.shortcut.actionIdentifier)
                                    },
                                    onDelete: deleteShortcut,
                                    onReorder: reorderShortcuts,
                                    onAdd: handleAddShortcut,
                                    scale: scale
                                )
                            }
                            .padding(.bottom, 10)
                            
                            // Overview Section
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text("Overview")
                                        .font(.system(size: 21, weight: .semibold))
                                        .foregroundColor(theme.primaryText)
                                    
                                    Spacer()
                                }
                                .padding(.horizontal)
                                
                                DashboardOverviewCard(nutritionViewModel: nutritionViewModel, healthKitManager: healthKitManager)
                                    .onTapGesture {
                                        cinematicManager.present("overview")
                                    }
                            }
                            .padding(.bottom, 10)
                            
                            // Activity Section
                            ActivitySection(
                                selectedDate: $selectedDate,
                                activities: activitiesForSelectedDate,
                                onPlayWorkout: { activity in
                                    selectedActivityForConfirmation = activity
                                    showConfirmationModal = true
                                },
                                onShowReading: { activity in
                                    selectedActivityForConfirmation = activity
                                    showConfirmationModal = true
                                },
                                onMarkComplete: { activity in
                                    markActivityAsComplete(activity)
                                }
                            )
                            .environmentObject(progressManager)
                            .padding(.horizontal)
                            
                            // Draggable cards
                            // ForEach(cards) { card in
                            //     CardView(card: card)
                            //         .padding(.horizontal)
                            //         .onDrag {
                            //             self.draggedCard = card
                            //             return NSItemProvider(object: String(card.id.uuidString) as NSString)
                            //         }
                            //         .onDrop(of: [UTType.text], delegate: CardDropDelegate(item: card,
                            //                                                                    cards: $cards,
                            //                                                                    draggedCard: $draggedCard))
                            // }
                        }
                        .padding(.bottom) // Padding for the ScrollView content
                    }
                    .scrollIndicators(.hidden)
                    .refreshable {
                        authManager.fetchCurrentUserDetails()
                        // Also refresh nutrition data when pulling to refresh
                        await nutritionViewModel.reloadCurrentLog()
                    }
                }
                .cinematicBackground(isActive: cinematicManager.isAnyActive || activeWorkout != nil)
                .onAppear {
                    // Load nutrition data when dashboard appears
                    Task {
                        await nutritionViewModel.reloadCurrentLog()
                    }
                    // Refresh HealthKit data
                    healthKitManager.refreshStepData()
                }
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
                    // Refresh nutrition data when app becomes active
                    Task {
                        await nutritionViewModel.reloadCurrentLog()
                    }
                    // Refresh HealthKit data when app becomes active
                    healthKitManager.refreshStepData()
                }

                // Cinematic workout overlay
                if let workout = activeWorkout {
                    WorkoutContainerView(
                        workout: workout,
                        activityId: selectedActivityForConfirmation?.id,
                        savedProgress: selectedActivityForConfirmation?.id != nil ? progressManager.getWorkoutProgress(selectedActivityForConfirmation!.id) : nil,
                        onEndWorkout: { markComplete in
                            // Handle ending workout before completion
                            if let activityId = selectedActivityForConfirmation?.id {
                                if markComplete {
                                    // Mark as completed
                                    progressManager.clearProgress(activityId)
                                    if var user = authManager.currentUser,
                                       let index = user.scheduledActivities?.firstIndex(where: { $0.id == activityId }) {
                                        user.scheduledActivities?[index].isComplete = true
                                        authManager.currentUser = user
                                    }
                                }
                                // Progress is already saved via onSaveProgress callback
                            }
                            
                            // Dismiss the workout view with animation
                            withAnimation(.easeInOut(duration: 0.3)) {
                                activeWorkout = nil
                            }
                        },
                        onFinish: {
                            // This closure is called when the user finishes the workout completely.
                            if let activityId = selectedActivityForConfirmation?.id {
                                // Mark as completed and remove from in-progress
                                progressManager.clearProgress(activityId)
                                if var user = authManager.currentUser,
                                   let index = user.scheduledActivities?.firstIndex(where: { $0.id == activityId }) {
                                    user.scheduledActivities?[index].isComplete = true
                                    authManager.currentUser = user
                                }
                            }
                            
                            // Dismiss the workout view with animation
                            withAnimation(.easeInOut(duration: 0.3)) {
                                activeWorkout = nil
                            }
                        },
                        onSaveProgress: { exerciseIndex, currentSet, completedExercises in
                            // Save the current workout progress
                            if let activityId = selectedActivityForConfirmation?.id {
                                progressManager.saveWorkoutProgress(
                                    activityId: activityId,
                                    workoutId: workout.id,
                                    exerciseIndex: exerciseIndex,
                                    currentSet: currentSet,
                                    completedExercises: completedExercises
                                )
                            }
                        }
                    )
                    .environmentObject(authManager)
                    .cinematicOverlay()
                }

                // Cinematic journal entry overlay
                if cinematicManager.isActive("journal") {
                    CinematicJournalEntryView(
                        onDismiss: {
                            cinematicManager.dismiss("journal")
                        }
                    )
                    .environmentObject(authManager)
                    .cinematicOverlay()
                }

                // Cinematic overview overlay
                if cinematicManager.isActive("overview") {
                    CinematicOverviewView(
                        nutritionViewModel: nutritionViewModel,
                        onDismiss: {
                            cinematicManager.dismiss("overview")
                        }
                    )
                    .environmentObject(authManager)
                    .cinematicOverlay()
                }

                // Cinematic workout wizard overlay
                if cinematicManager.isActive("workout_wizard") {
                    NewWorkoutWizardViewWrapper(
                        isPresented: Binding(
                            get: { cinematicManager.isActive("workout_wizard") },
                            set: { _ in cinematicManager.dismiss("workout_wizard") }
                        )
                    )
                    .environmentObject(authManager)
                    .cinematicOverlay()
                }

                // Cinematic nutrition overlay
                if cinematicManager.isActive("nutrition") {
                    NutritionViewWrapper(
                        isPresented: Binding(
                            get: { cinematicManager.isActive("nutrition") },
                            set: { _ in cinematicManager.dismiss("nutrition") }
                        ),
                        viewModel: nutritionViewModel
                    )
                    .environmentObject(authManager)
                    .cinematicOverlay()
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

                // Confirmation modal overlay
                if showConfirmationModal, let activity = selectedActivityForConfirmation {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                        .onTapGesture {
                            showConfirmationModal = false
                        }

                    ConfirmationModal(
                        activityName: activity.activity.name,
                        isInProgress: progressManager.isInProgress(activity.id),
                        onCancel: {
                            showConfirmationModal = false
                        },
                        onContinue: {
                            showConfirmationModal = false
                            // Handle continue action based on activity type
                            if let workout = activity.activity.associatedWorkout {
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    activeWorkout = workout
                                }
                            } else if activity.activity.associatedReading != nil {
                                // TODO: Handle reading content
                            }
                        }
                    )
                    .transition(.scale.combined(with: .opacity))
                }
            }
            .dismissKeyboardOnTap()
            .animation(.easeOut(duration: 0.2), value: showConfirmationModal)

            .if(theme is LiquidGlassTheme) { view in
                view.toolbar(isModalActive ? .hidden : .visible, for: .tabBar)
}

            .onAppear {
                isModalActive = showConfirmationModal || activeWorkout != nil || cinematicManager.isAnyActive
            }
            .onChange(of: showConfirmationModal) { _, _ in
                isModalActive = showConfirmationModal || activeWorkout != nil || cinematicManager.isAnyActive
            }
            .onChange(of: activeWorkout) { _, _ in
                isModalActive = showConfirmationModal || activeWorkout != nil || cinematicManager.isAnyActive
            }
            .onChange(of: cinematicManager.isAnyActive) { _, _ in
                isModalActive = showConfirmationModal || activeWorkout != nil || cinematicManager.isAnyActive
            }
        }
        // Add fullScreenCovers for the shortcuts
        .fullScreenCover(isPresented: $showWorkoutList) {
            WorkoutListViewWrapper(isPresented: $showWorkoutList)
                .environmentObject(authManager)
        }

        .fullScreenCover(isPresented: $showEmotionsView) {
            EmotionContentViewWrapper(isPresented: $showEmotionsView)
        }
        .fullScreenCover(isPresented: $showJourneyView) {
            JourneyViewWrapper(isPresented: $showJourneyView)
                .environmentObject(authManager)
        }
        .fullScreenCover(isPresented: $showMeditationsView) {
            ComingSoonViewWrapper(isPresented: $showMeditationsView)
        }
        .fullScreenCover(isPresented: $showHabitsView) {
            ComingSoonViewWrapper(isPresented: $showHabitsView)
        }

        .fullScreenCover(isPresented: $showMaxChatView) {
            ChatView(initialMessage: nil)
                .environmentObject(authManager)
        }
        .sheet(isPresented: $showAddShortcutSheet, onDismiss: {
            // When the sheet is dismissed, refresh the user details
            // to get the latest list of shortcuts.
            authManager.fetchCurrentUserDetails()
        }) {
            AddShortcutView(
                viewModel: AddShortcutViewModel(
                    httpClient: authManager.httpClient,
                    currentUserShortcuts: userShortcuts
                )
            )
        }
    }
}

// MARK: - Confirmation Modal
struct ConfirmationModal: View {
    let activityName: String
    let isInProgress: Bool
    let onCancel: () -> Void
    let onContinue: () -> Void
    @Environment(\.theme) private var theme: any Theme
    
    private var actionText: String {
        isInProgress ? "resume" : "begin"
    }
    
    private var buttonText: String {
        isInProgress ? "Resume" : "Begin"
    }

    var body: some View {
        VStack(spacing: 20) {
            Text("Would you like to \(actionText) \(activityName)?")
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(theme.primaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)

            HStack(spacing: 20) {
                Button("Back") {
                    onCancel()
                }
                .font(.system(size: 16, weight: .medium))
                .padding(.horizontal, 32)
                .padding(.vertical, 12)
                .background(Color.white)
                .foregroundColor(.black)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.black, lineWidth: 1)
                )
                .cornerRadius(10)

                Button(buttonText) {
                    onContinue()
                }
                .font(.system(size: 16, weight: .medium))
                .padding(.horizontal, 28)
                .padding(.vertical, 12)
                .background(Color.black)
                .foregroundColor(.white)
                .cornerRadius(10)
            }
        }
        .padding(20)
        .background(Color.white)
        .cornerRadius(15)
        .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)
        .frame(maxWidth: 300)
    }
}

private struct DashboardHeaderView: View {
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

// MARK: - CardDropDelegate
/// Handles drag-and-drop reordering of cards within the scroll view.
// private struct CardDropDelegate: DropDelegate {
//     let item: CardModel
//     @Binding var cards: [CardModel]
//     @Binding var draggedCard: CardModel?

//     func dropEntered(info: DropInfo) {
//         guard let dragged = draggedCard, dragged != item,
//               let fromIndex = cards.firstIndex(of: dragged),
//               let toIndex = cards.firstIndex(of: item) else { return }

//         // Update the array order as the drag enters a new item.
//         withAnimation {
//             cards.move(fromOffsets: IndexSet(integer: fromIndex), toOffset: toIndex > fromIndex ? toIndex + 1 : toIndex)
//         }
//     }

//     func performDrop(info: DropInfo) -> Bool {
//         // Reset state when the drop completes.
//         self.draggedCard = nil
//         return true
//     }
// }

// MARK: - Preview
struct DashboardView_Previews: PreviewProvider {
    static var previews: some View {
        // Create a dedicated preview AuthenticationManager
        let previewManager = AuthenticationManager()
        
        struct PreviewWrapper: View {
            @State private var selectedDate = Date()
            @State private var isModalActive = false
            @StateObject private var progressManager = ActivityProgressManager()
            let previewManager: AuthenticationManager
            
            var body: some View {
                DashboardView(selectedDate: $selectedDate, isModalActive: $isModalActive, authManager: previewManager)
                    .environmentObject(previewManager)
                    .environmentObject(progressManager)
                    .environment(\.theme, LiquidGlassTheme())
            }
        }

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


        
        // Create preview user
        let sampleUser = AppUser(
            id: "1", phone: "+10000000000", backupEmail: nil, firstName: "Jane", lastName: "Doe", isPhoneVerified: true,
            dateJoined: isoStringToday, lifetimePoints: 120, availablePoints: 60, lifetimeSavings: 15,
            isOnboarded: true, currentStreak: 5, longestStreak: 10, streakPoints: 50, info: nil, equipment: nil, exerciseMaxes: nil, muscleFatigue: nil,
            goals: nil, scheduledActivities: allScheduled,
            completionLogs: nil, calorieLogs: nil, feedback: nil, assignedPromotions: nil,
            promotionRedemptions: []
        )

        previewManager.currentUser = sampleUser

        return PreviewWrapper(previewManager: previewManager)
    }
}

struct ShortcutCardView_Previews: PreviewProvider {
    static var previews: some View {
        let sampleApiShortcut = Shortcut(id: UUID(), name: "Search by image", category: "Fitness", actionIdentifier: "search_image", description: nil)
        let sampleUserShortcut = UserShortcut(id: UUID(), shortcut: sampleApiShortcut, order: 0)
        
        VStack(spacing: 20) {
            Text("Default Theme")
            ShortcutCardView(userShortcut: sampleUserShortcut)
                .environment(\.theme, LegacyTheme())
            
            Text("Liquid Glass Theme")
            ShortcutCardView(userShortcut: sampleUserShortcut)
                .environment(\.theme, LiquidGlassTheme())
        }
        .padding()
        .background(Color.gray.opacity(0.2))
        .previewLayout(.sizeThatFits)
    }
}

// MARK: - Wrapper Views for Fullscreen Covers
struct WorkoutListViewWrapper: View {
    @Binding var isPresented: Bool
    @EnvironmentObject var authManager: AuthenticationManager
    @Environment(\.theme) private var theme: any Theme
    
    var body: some View {
        VStack(spacing: 0) {
            // Custom Header with X button
            HStack {
                Button(action: { isPresented = false }) {
                    ZStack {
                        // Liquid glass style background
                        Circle()
                            .fill(
                                LinearGradient(
                                    gradient: Gradient(colors: [Color.white.opacity(0.2), Color.white.opacity(0.1)]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .background(
                                Circle()
                                    .fill(Color.black.opacity(0.05))
                            )
                            .frame(width: 36, height: 36)
                        
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(theme.primaryText)
                    }
                }
                .padding(.leading)
                
                Spacer()
                
                Text("Workouts")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(theme.primaryText)
                
                Spacer()
                
                // Invisible button for symmetry
                Button(action: {}) {
                    Image(systemName: "xmark")
                        .font(.system(size: 16))
                        .foregroundColor(.clear)
                }
                .disabled(true)
                .padding(.trailing)
            }
            .padding(.vertical)
            .background(theme.background)
            
            // The actual WorkoutListView without NavigationView wrapper
            WorkoutListViewContent()
                .environmentObject(authManager)
        }
        .background(theme.background.ignoresSafeArea())
    }
}

// WorkoutListView without NavigationView wrapper
struct WorkoutListViewContent: View {
    @State private var workouts: [Workout] = []
    @State private var selectedWorkout: Workout?
    @State private var searchText = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @EnvironmentObject var authManager: AuthenticationManager
    
    var filteredWorkouts: [Workout] {
        if searchText.isEmpty {
            return workouts
        } else {
            return workouts.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }
    }
    
    var body: some View {
        ZStack {
            if isLoading {
                ProgressView()
                    .scaleEffect(1.5)
            } else if let errorMessage = errorMessage {
                VStack {
                    Text("Error")
                        .font(.system(size: 28))
                        .foregroundColor(.red)
                    Text(errorMessage)
                        .multilineTextAlignment(.center)
                        .padding()
                        .font(.system(size: 17))
                    Button("Try Again") {
                        fetchWorkouts()
                    }
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
                .padding()
            } else if filteredWorkouts.isEmpty && !searchText.isEmpty {
                Text("No workouts found")
                    .font(.system(size: 22))
                    .foregroundColor(.secondary)
            } else {
                List {
                    ForEach(filteredWorkouts) { workout in
                        WorkoutRow(workout: workout)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                selectedWorkout = workout
                            }
                    }
                }
                .listStyle(InsetGroupedListStyle())
                .searchable(text: $searchText, prompt: "Search workouts")
            }
        }
        .onAppear {
            if workouts.isEmpty {
                fetchWorkouts()
            }
        }
        .fullScreenCover(item: $selectedWorkout) { workout in
            WorkoutContainerView(workout: workout, onFinish: {
                selectedWorkout = nil
            })
            .environmentObject(authManager)
        }
    }
    
    private func fetchWorkouts() {
        isLoading = true
        errorMessage = nil
        
        let workoutAPI = WorkoutAPI(httpClient: authManager.httpClient)
        workoutAPI.fetchWorkouts { result in
            DispatchQueue.main.async {
                isLoading = false
                
                switch result {
                case .success(let fetchedWorkouts):
                    self.workouts = fetchedWorkouts
                case .failure(let error):
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }
}

// WorkoutRow definition (needed for WorkoutListViewContent)
//struct WorkoutRow: View {
//    let workout: Workout
//    
//    var body: some View {
//        VStack(alignment: .leading, spacing: 4) {
//            Text(workout.name)
//                .font(.system(size: 17))
//            
//            Text(workout.description ?? "")
//                .font(.system(size: 15))
//                .foregroundColor(.secondary)
//                .lineLimit(2)
//            
//            HStack {
//                Label("\(workout.duration)", systemImage: "clock")
//                    .font(.system(size: 12))
//                
//                Spacer()
//                
//                Text("\(workout.workoutexercises.count) exercises")
//                    .font(.system(size: 12))
//                    .foregroundColor(.secondary)
//            }
//            .padding(.top, 4)
//        }
//        .padding(.vertical, 8)
//    }
//}

struct NutritionViewWrapper: View {
    @Binding var isPresented: Bool
    @EnvironmentObject var authManager: AuthenticationManager
    @Environment(\.theme) private var theme: any Theme
    let viewModel: NutritionViewModel
    
    var body: some View {
        VStack(spacing: 0) {
            // Custom Header with X button
            HStack {
                Button(action: { isPresented = false }) {
                    ZStack {
                        // Liquid glass style background
                        Circle()
                            .fill(
                                LinearGradient(
                                    gradient: Gradient(colors: [Color.white.opacity(0.2), Color.white.opacity(0.1)]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .background(
                                Circle()
                                    .fill(Color.black.opacity(0.05))
                            )
                            .frame(width: 36, height: 36)
                        
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(theme.primaryText)
                    }
                }
                .padding(.leading)
                
                Spacer()
                
                Text("Nutrition")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(theme.primaryText)
                
                Spacer()
                
                // Invisible button for symmetry
                Button(action: {}) {
                    Image(systemName: "xmark")
                        .font(.system(size: 16))
                        .foregroundColor(.clear)
                }
                .disabled(true)
                .padding(.trailing)
            }
            .padding(.vertical)
            .background(theme.background)
            
            // Custom nutrition view without internal navigation
            NutritionViewContent(viewModel: viewModel, showHeader: false)
        }
        .background(theme.background.ignoresSafeArea())
    }
}

// Custom NutritionView that can hide its built-in header
struct NutritionViewContent: View {
    @ObservedObject var viewModel: NutritionViewModel
    let showHeader: Bool
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        // Use the full NutritionView - it will have its own header but that's acceptable
        NutritionView(viewModel: viewModel)
    }
}

struct EmotionContentViewWrapper: View {
    @Binding var isPresented: Bool
    @Environment(\.theme) private var theme: any Theme
    
    var body: some View {
        VStack(spacing: 0) {
            // Custom Header with X button
            HStack {
                Button(action: { isPresented = false }) {
                    ZStack {
                        // Liquid glass style background
                        Circle()
                            .fill(
                                LinearGradient(
                                    gradient: Gradient(colors: [Color.white.opacity(0.2), Color.white.opacity(0.1)]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .background(
                                Circle()
                                    .fill(Color.black.opacity(0.05))
                            )
                            .frame(width: 36, height: 36)
                        
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(theme.primaryText)
                    }
                }
                .padding(.leading)
                
                Spacer()
                
                Text("Emotions")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(theme.primaryText)
                
                Spacer()
                
                // Invisible button for symmetry
                Button(action: {}) {
                    Image(systemName: "xmark")
                        .font(.system(size: 16))
                        .foregroundColor(.clear)
                }
                .disabled(true)
                .padding(.trailing)
            }
            .padding(.vertical)
            .background(theme.background)
            
//            EmotionContentView()
        }
        .background(theme.background.ignoresSafeArea())
    }
}

struct NewWorkoutWizardViewWrapper: View {
    @Binding var isPresented: Bool
    @EnvironmentObject var authManager: AuthenticationManager
    @Environment(\.theme) private var theme: any Theme
    
    var body: some View {
        VStack(spacing: 0) {
            // Custom Header with X button
            HStack {
                Button(action: { isPresented = false }) {
                    ZStack {
                        // Liquid glass style background
                        Circle()
                            .fill(
                                LinearGradient(
                                    gradient: Gradient(colors: [Color.white.opacity(0.2), Color.white.opacity(0.1)]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .background(
                                Circle()
                                    .fill(Color.black.opacity(0.05))
                            )
                            .frame(width: 36, height: 36)
                        
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(theme.primaryText)
                    }
                }
                .padding(.leading)
                
                Spacer()
                
                Text("Custom Workout")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(theme.primaryText)
                
                Spacer()
                
                // Invisible button for symmetry
                Button(action: {}) {
                    Image(systemName: "xmark")
                        .font(.system(size: 16))
                        .foregroundColor(.clear)
                }
                .disabled(true)
                .padding(.trailing)
            }
            .padding(.vertical)
            .background(theme.background)
            
            // The actual NewWorkoutWizardView without NavigationView wrapper
            NewWorkoutWizardContent(dismissParent: { isPresented = false })
                .environmentObject(authManager)
        }
        .background(theme.background.ignoresSafeArea())
    }
}

// NewWorkoutWizardView without NavigationView wrapper
struct NewWorkoutWizardContent: View {
    @EnvironmentObject var authManager: AuthenticationManager
    var dismissParent: () -> Void

    @State private var selectedMuscles: Set<String> = []
    @State private var duration: Int = 40
    @State private var intensity: String = "medium"
    @State private var includeCardio = false
    @State private var isLoading = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var generatedWorkout: Workout?
    @Environment(\.theme) private var theme: any Theme

    private let allMuscles = ["chest", "back", "quadriceps", "hamstrings", "glutes", "shoulders", "biceps", "triceps", "core"]

    var body: some View {
        VStack {
            Form {
                Section(header: Text("Target Muscles")) {
                    ForEach(allMuscles, id: \.self) { muscle in
                        MultipleSelectionRow(title: muscle.capitalized, isSelected: selectedMuscles.contains(muscle)) {
                            if selectedMuscles.contains(muscle) {
                                selectedMuscles.remove(muscle)
                            } else {
                                selectedMuscles.insert(muscle)
                            }
                        }
                    }
                }

                Section(header: Text("Duration")) {
                    Picker("Duration", selection: $duration) {
                        Text("20 min").tag(20)
                        Text("40 min").tag(40)
                        Text("60 min").tag(60)
                    }.pickerStyle(SegmentedPickerStyle())
                }

                Section(header: Text("Intensity")) {
                    Picker("Intensity", selection: $intensity) {
                        Text("Low").tag("low")
                        Text("Medium").tag("medium")
                        Text("High").tag("high")
                    }.pickerStyle(SegmentedPickerStyle())
                }

                Toggle("Include cardio warm-up", isOn: $includeCardio)
            }

            Button(action: generateWorkout) {
                if isLoading {
                    ProgressView()
                } else {
                    Text("Continue")
                        .bold()
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(selectedMuscles.isEmpty ? theme.secondaryText.opacity(0.5) : theme.accent)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
            }
            .disabled(selectedMuscles.isEmpty || isLoading)
            .padding()
        }
        .alert("Error", isPresented: $showError, actions: { Button("OK", role: .cancel) {} }, message: { Text(errorMessage) })
        .fullScreenCover(item: $generatedWorkout) { wk in
            WorkoutContainerView(workout: wk, onFinish: {
                dismissParent() // when workout finished
            })
            .environmentObject(authManager)
        }
    }

    private func generateWorkout() {
        guard let httpClient = authManager.httpClient as AuthenticatedHTTPClient? else { return }
        isLoading = true
        Task {
            do {
                let api = CustomWorkoutAPI(httpClient: httpClient)
                let req = GenerateCustomWorkoutRequest(muscleGroups: Array(selectedMuscles), duration: duration, intensity: intensity, includeCardio: includeCardio, scheduleForToday: true)
                let resp = try await api.generateCustomWorkout(request: req)
                // Fetch workout detail
                let workoutAPI = WorkoutAPI(httpClient: httpClient)
                let workout = try await workoutAPI.fetchWorkoutById(id: resp.workoutId)
                await MainActor.run {
                    self.generatedWorkout = workout
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.isLoading = false
                    self.errorMessage = error.localizedDescription
                    self.showError = true
                }
            }
        }
    }
}

// MultipleSelectionRow definition (needed for NewWorkoutWizardContent)
//struct MultipleSelectionRow: View {
//    var title: String
//    var isSelected: Bool
//    var action: () -> Void
//    var body: some View {
//        Button(action: action) {
//            HStack {
//                Text(title)
//                Spacer()
//                if isSelected {
//                    Image(systemName: "checkmark")
//                }
//            }
//        }
//    }
//}

struct JourneyViewWrapper: View {
    @Binding var isPresented: Bool
    @EnvironmentObject var authManager: AuthenticationManager
    @Environment(\.theme) private var theme: any Theme
    
    var body: some View {
        VStack(spacing: 0) {
            // Custom Header with X button
            HStack {
                Button(action: { isPresented = false }) {
                    ZStack {
                        // Liquid glass style background
                        Circle()
                            .fill(
                                LinearGradient(
                                    gradient: Gradient(colors: [Color.white.opacity(0.2), Color.white.opacity(0.1)]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .background(
                                Circle()
                                    .fill(Color.black.opacity(0.05))
                            )
                            .frame(width: 36, height: 36)
                        
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(theme.primaryText)
                    }
                }
                .padding(.leading)
                
                Spacer()
                
                Text("Journey")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(theme.primaryText)
                
                Spacer()
                
                // Invisible button for symmetry
                Button(action: {}) {
                    Image(systemName: "xmark")
                        .font(.system(size: 16))
                        .foregroundColor(.clear)
                }
                .disabled(true)
                .padding(.trailing)
            }
            .padding(.vertical)
            .background(theme.background)
            
            JourneyView()
                .environmentObject(authManager)
        }
        .background(theme.background.ignoresSafeArea())
    }
}

struct ComingSoonViewWrapper: View {
    @Binding var isPresented: Bool
    @Environment(\.theme) private var theme: any Theme
    
    var body: some View {
        VStack(spacing: 0) {
            // Custom Header with X button
            HStack {
                Button(action: { isPresented = false }) {
                    ZStack {
                        // Liquid glass style background
                        Circle()
                            .fill(
                                LinearGradient(
                                    gradient: Gradient(colors: [Color.white.opacity(0.2), Color.white.opacity(0.1)]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .background(
                                Circle()
                                    .fill(Color.black.opacity(0.05))
                            )
                            .frame(width: 36, height: 36)
                        
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(theme.primaryText)
                    }
                }
                .padding(.leading)
                
                Spacer()
                
                // Invisible button for symmetry
                Button(action: {}) {
                    Image(systemName: "xmark")
                        .font(.system(size: 16))
                        .foregroundColor(.clear)
                }
                .disabled(true)
                .padding(.trailing)
            }
            .padding(.vertical)
            .background(theme.background)
            
            ComingSoonView()
        }
        .background(theme.background.ignoresSafeArea())
    }
}


// MARK: - Cinematic Journal Entry View
struct CinematicJournalEntryView: View {
    let onDismiss: () -> Void
    @EnvironmentObject var authManager: AuthenticationManager
    @Environment(\.theme) private var theme: any Theme
    
    @State private var title: String = ""
    @State private var content: String = ""
    @State private var isSubmitting: Bool = false
    @State private var showErrorAlert: Bool = false
    @State private var errorMessage: String = ""
    @State private var showSuccessAlert: Bool = false
    @State private var showBackConfirmation: Bool = false
    
    // Focus states for better UX
    @FocusState private var isTitleFocused: Bool
    @FocusState private var isContentFocused: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            // Navigation Bar
            HStack {
                // Back button
                Button(action: handleBackTap) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.primary)
                }
                
                Spacer()
                
                // Save button
                Button(action: submitJournalEntry) {
                    ZStack {
                        Circle()
                            .fill(canSubmit ? Color.blue : Color.gray.opacity(0.3))
                            .frame(width: 36, height: 36)
                        
                        if isSubmitting {
                            ProgressView()
                                .scaleEffect(0.7)
                                .tint(.white)
                        } else {
                            Image(systemName: "checkmark")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)
                        }
                    }
                }
                .disabled(!canSubmit || isSubmitting)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(Color(.systemBackground))
            
            // Content Area
            VStack(alignment: .leading, spacing: 0) {
                // Title Section
                VStack(alignment: .leading, spacing: 0) {
                    TextField("Title", text: $title)
                        .font(.system(size: 17))
                        .foregroundColor(.primary)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 16)
                        .focused($isTitleFocused)
                        .submitLabel(.next)
                        .onSubmit {
                            isContentFocused = true
                        }
                }
                
                // Divider
                Rectangle()
                    .fill(Color(.separator))
                    .frame(height: 0.5)
                    .padding(.horizontal, 20)
                
                // Content Area
                ZStack(alignment: .topLeading) {
                    if content.isEmpty && !isContentFocused {
                        Text("Start writing...")
                            .font(.system(size: 17))
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 20)
                            .padding(.top, 16)
                    }
                    
                    TextEditor(text: $content)
                        .font(.system(size: 17))
                        .foregroundColor(.primary)
                        .scrollContentBackground(.hidden)
                        .background(Color.clear)
                        .focused($isContentFocused)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                }
                
                Spacer()
            }
            .background(Color(.systemBackground))
        }
        .background(Color(.systemBackground))
        .onAppear {
            // Auto-focus title field when view appears
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                isTitleFocused = true
            }
        }
        .alert("Error", isPresented: $showErrorAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
        .alert("Success", isPresented: $showSuccessAlert) {
            Button("OK", role: .cancel) {
                onDismiss()
            }
        } message: {
            Text("Your journal entry has been saved successfully!")
        }
        .alert("Discard Entry?", isPresented: $showBackConfirmation) {
            Button("Discard", role: .destructive) {
                onDismiss()
            }
            Button("Keep Writing", role: .cancel) {}
        } message: {
            Text("You have unsaved changes. Are you sure you want to discard this entry?")
        }
    }
    
    // MARK: - Computed Properties
    
    private var canSubmit: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !isSubmitting
    }
    
    private var hasContent: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
        !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    // MARK: - Methods
    
    private func handleBackTap() {
        if hasContent {
            showBackConfirmation = true
        } else {
            onDismiss()
        }
    }
    
    private func submitJournalEntry() {
        guard canSubmit else { return }
        
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedContent = content.trimmingCharacters(in: .whitespacesAndNewlines)
        
        isSubmitting = true
        
        Task {
            do {
                let journalAPI = JournalEntryAPI(httpClient: authManager.httpClient)
                let _ = try await journalAPI.createJournalEntry(
                    title: trimmedTitle,
                    content: trimmedContent
                )
                
                await MainActor.run {
                    isSubmitting = false
                    showSuccessAlert = true
                    
                    // Clear the form
                    title = ""
                    content = ""
                    
                    // Provide haptic feedback
                    let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                    impactFeedback.impactOccurred()
                }
            } catch {
                await MainActor.run {
                    isSubmitting = false
                    errorMessage = error.localizedDescription
                    showErrorAlert = true
                }
            }
        }
    }
}

// MARK: - Cinematic Overview View
struct CinematicOverviewView: View {
    @ObservedObject var nutritionViewModel: NutritionViewModel
    let onDismiss: () -> Void
    @EnvironmentObject var authManager: AuthenticationManager
    @Environment(\.theme) private var theme: any Theme
    
    // Mock data for other categories - same as DashboardOverviewCard
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
        VStack(spacing: 0) {
            // Navigation Bar
            HStack {
                // Back button
                Button(action: onDismiss) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.primary)
                }
                
                Spacer()
                
                Text("Today's Overview")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.primary)
                
                Spacer()
                
                // Invisible button for symmetry
                Button(action: {}) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18))
                        .foregroundColor(.clear)
                }
                .disabled(true)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(Color(.systemBackground))
            
            // Content Area
            ScrollView {
                LazyVStack(spacing: 24) {
                    // Header with current date
                    VStack(spacing: 8) {
                        Text(getCurrentDateString())
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(.primary)
                        
                        Text("Here's how your day is looking")
                            .font(.system(size: 16))
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 20)
                    
                    // Detailed stats for each category
                    VStack(spacing: 20) {
                        // Nutrition Card
                        OverviewCategoryCard(
                            title: "Nutrition",
                            color: nutritionColor,
                            icon: "flame.fill",
                            primaryStat: "\(nutritionViewModel.summary.caloriesLeft)",
                            primaryLabel: "calories remaining",
                            stats: [
                                ("Calories eaten", "\(nutritionViewModel.summary.caloriesEaten)"),
                                ("Daily goal", "\(nutritionViewModel.summary.caloriesGoal)"),
                                ("Progress", "\(Int((Double(nutritionViewModel.summary.caloriesEaten) / Double(max(nutritionViewModel.summary.caloriesGoal, 1)) * 100)))%")
                            ]
                        )
                        
                        // Sleep Card
                        OverviewCategoryCard(
                            title: "Sleep",
                            color: sleepColor,
                            icon: "moon.fill",
                            primaryStat: "\(sleepScore)",
                            primaryLabel: "sleep score",
                            stats: [
                                ("Last night", "8h 15m"),
                                ("Average", "7h 45m"),
                                ("Sleep debt", "0h 30m")
                            ]
                        )
                        
                        // Fitness Card
                        OverviewCategoryCard(
                            title: "Fitness",
                            color: fitnessColor,
                            icon: "figure.walk",
                            primaryStat: "\(stepCount)",
                            primaryLabel: "steps today",
                            stats: [
                                ("Goal progress", "\(Int((Double(stepCount) / Double(stepGoal)) * 100))%"),
                                ("Distance", "4.2 km"),
                                ("Calories burned", "320 cal")
                            ]
                        )
                        
                        // Mind Card
                        OverviewCategoryCard(
                            title: "Mindfulness",
                            color: mindColor,
                            icon: "brain.head.profile",
                            primaryStat: "\(activeMinutes)",
                            primaryLabel: "active minutes",
                            stats: [
                                ("Goal progress", "\(Int((Double(activeMinutes) / Double(activeMinutesGoal)) * 100))%"),
                                ("Sessions today", "2"),
                                ("Streak", "5 days")
                            ]
                        )
                    }
                    .padding(.horizontal, 20)
                    
                    Spacer(minLength: 40)
                }
            }
            .background(Color(.systemGroupedBackground))
        }
        .background(Color(.systemGroupedBackground))
    }
    
    private func getCurrentDateString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMMM d"
        return formatter.string(from: Date())
    }
}

// MARK: - Overview Category Card
private struct OverviewCategoryCard: View {
    let title: String
    let color: Color
    let icon: String
    let primaryStat: String
    let primaryLabel: String
    let stats: [(String, String)]
    @Environment(\.theme) private var theme: any Theme
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header with icon and title
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(color.opacity(0.15))
                        .frame(width: 40, height: 40)
                    
                    Image(systemName: icon)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(color)
                }
                
                Text(title)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.primary)
                
                Spacer()
            }
            
            // Primary stat
            VStack(alignment: .leading, spacing: 4) {
                Text(primaryStat)
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(color)
                
                Text(primaryLabel)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.secondary)
            }
            
            // Additional stats
            VStack(spacing: 12) {
                ForEach(Array(stats.enumerated()), id: \.offset) { _, stat in
                    HStack {
                        Text(stat.0)
                            .font(.system(size: 15))
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Text(stat.1)
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(.primary)
                    }
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
        )
    }
}

// MARK: - Add Shortcut View (Placeholder)
struct AddShortcutView: View {
    @Environment(\.presentationMode) var presentationMode
    @StateObject var viewModel: AddShortcutViewModel
    @EnvironmentObject var authManager: AuthenticationManager // Get user for lookups
    @Environment(\.theme) private var theme: any Theme
    
    /// Returns an emoji icon based on the shortcut's action identifier
    private func shortcutEmoji(for actionIdentifier: String) -> String {
        switch actionIdentifier {
        case "new_workout":
            return "🏋️"
        case "log_food":
            return "🍽️"
        case "new_entry":
            return "📔"
        case "meditate":
            return "🧘"
        case "sleep_tracking":
            return "😴"
        case "water_intake", "log_hydration":
            return "💧"
        case "habit_tracking":
            return "✅"
        case "mood_check":
            return "😊"
        case "weight_tracking":
            return "⚖️"
        case "steps_tracking":
            return "🚶"
        case "heart_rate":
            return "❤️"
        case "calorie_tracking":
            return "🔥"
        case "log_caffeine":
            return "☕"
        case "new_pr", "personal_record":
            return "🏆"
        case "breathing_exercise":
            return "🌬️"
        case "journal_entry":
            return "📖"
        case "sleep_debt":
            return "😪"
        case "log_alcohol":
            return "🍷"
        case "log_prescription", "medication":
            return "💊"
        case "intimate_wellness":
            return "💕"
        case "recipe_creation":
            return "👨‍🍳"
        case "log_symptoms":
            return "🌡️"
        case "track_cycle":
            return "🌸"
        case "blood_pressure":
            return "🩺"
        case "supplements":
            return "🍃"
        case "mindfulness":
            return "🧠"
        case "gratitude":
            return "🙏"
        case "energy_levels":
            return "⚡"
        default:
            return "⭐"
        }
    }

    var body: some View {
        NavigationView {
            VStack {
                if viewModel.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let errorMessage = viewModel.errorMessage {
                    VStack {
                        Text("Error")
                            .font(.headline)
                        Text(errorMessage)
                            .foregroundColor(.secondary)
                        Button("Retry") {
                            viewModel.fetchAvailableShortcuts()
                        }
                        .padding(.top)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List(viewModel.availableShortcuts) { shortcut in
                        HStack {
                            // Emoji icon
                            Text(shortcutEmoji(for: shortcut.actionIdentifier))
                                .font(.system(size: 24))
                                .frame(width: 30)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(shortcut.name)
                                    .font(.headline)
                                if let description = shortcut.description, !description.isEmpty {
                                    Text(description)
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                            }
                            
                            Spacer()
                            
                            Button(action: {
                                if viewModel.selectedShortcutIds.contains(shortcut.id) {
                                    // Find the UserShortcut that corresponds to this shortcut.id
                                    if let userShortcutToRemove = authManager.currentUser?.shortcutSelections?.first(where: { $0.shortcut.id == shortcut.id }) {
                                        viewModel.removeShortcut(userShortcut: userShortcutToRemove)
                                    }
                                } else {
                                    viewModel.addShortcut(shortcut: shortcut)
                                }
                            }) {
                                Image(systemName: viewModel.selectedShortcutIds.contains(shortcut.id) ? "checkmark.circle.fill" : "plus.circle")
                                    .font(.system(size: 24))
                                    .foregroundColor(viewModel.selectedShortcutIds.contains(shortcut.id) ? .green : .blue)
                            }
                            .buttonStyle(BorderlessButtonStyle())
                        }
                        .padding(.vertical, 8)
                    }
                    .listStyle(InsetGroupedListStyle())
                }
            }
            .navigationTitle("Add Shortcuts")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
        .onAppear {
            viewModel.fetchAvailableShortcuts()
        }
    }
}
