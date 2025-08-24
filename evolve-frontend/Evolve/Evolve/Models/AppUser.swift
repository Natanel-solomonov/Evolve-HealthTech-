import Foundation // Needed for Decimal, UUID

// Ensure other referenced models (UserScheduledActivity, UserCompletedLog, DailyCalorieTracker)
// are defined in the Models directory and are Codable.

struct AppUser: Codable, Identifiable {
    let id: String
    let phone: String
    var backupEmail: String?
    var firstName: String
    var lastName: String
    let isPhoneVerified: Bool
    let dateJoined: String
    let lifetimePoints: Int
    let availablePoints: Int
    let lifetimeSavings: Double
    var isOnboarded: Bool?
    let currentStreak: Int?
    let longestStreak: Int?
    let streakPoints: Int?
    var info: Info?
    var equipment: AppUserEquipment?
    let exerciseMaxes: [UserExerciseMax]?
    let muscleFatigue: [AppUserFatigueModel]?
    let goals: GoalsData?
    var shortcutSelections: [UserShortcut]?
    var scheduledActivities: [UserScheduledActivity]?
    let completionLogs: [UserCompletedLog]?
    let calorieLogs: [DailyCalorieTracker]?
    let feedback: [UserFeedback]?
    let assignedPromotions: [UUID]?
    let promotionRedemptions: [UUID]
    
    var displayName: String {
        return firstName
    }
    
    enum CodingKeys: String, CodingKey {
        case id, phone, info, goals, feedback, equipment
        case backupEmail = "backup_email"
        case firstName = "first_name"
        case lastName = "last_name"
        case isPhoneVerified = "is_phone_verified"
        case dateJoined = "date_joined"
        case lifetimePoints = "lifetime_points"
        case availablePoints = "available_points"
        case lifetimeSavings = "lifetime_savings"
        case isOnboarded = "is_onboarded"
        case currentStreak = "current_streak"
        case longestStreak = "longest_streak"
        case streakPoints = "streak_points"
        case exerciseMaxes = "exercise_maxes"
        case muscleFatigue = "muscle_fatigue"
        case scheduledActivities = "scheduled_activities"
        case shortcutSelections = "shortcut_selections"
        case completionLogs = "completion_logs"
        case calorieLogs = "calorie_logs"
        case assignedPromotions = "assigned_promotions"
        case promotionRedemptions = "promotion_redemptions"
    }
    
    // Nested struct for user's physical info
    struct Info: Codable {
        var height: Double?
        var birthday: String?
        var weight: Double?
        var sex: String?
    }

    // Nested struct for user's goals
    struct GoalsData: Codable {
        let goalsRaw: [String]?
        let goalsProcessed: [String]?
        
        enum CodingKeys: String, CodingKey {
            case goalsRaw = "goals_general"
            case goalsProcessed = "goals_processed"
        }
    }
}

// Add Equatable conformance
extension AppUser: Equatable {
    static func == (lhs: AppUser, rhs: AppUser) -> Bool {
        return lhs.id == rhs.id
    }
}
