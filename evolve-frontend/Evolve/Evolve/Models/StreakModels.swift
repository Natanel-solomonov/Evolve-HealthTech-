import Foundation

// MARK: - Streak Data Model
struct StreakData: Codable {
    let currentStreak: Int
    let longestStreak: Int
    let streakPoints: Int
    let daysUntilMilestone: Int
    let progressPercentage: Double
    let nextMilestone: Int
    
    enum CodingKeys: String, CodingKey {
        case currentStreak = "current_streak"
        case longestStreak = "longest_streak"
        case streakPoints = "streak_points"
        case daysUntilMilestone = "days_until_milestone"
        case progressPercentage = "progress_percentage"
        case nextMilestone = "next_milestone"
    }
}

// MARK: - Share Streak Response Model
struct ShareStreakResponse: Codable {
    let message: String
    let streakCount: Int
    let success: Bool
    
    enum CodingKeys: String, CodingKey {
        case message
        case streakCount = "streak_count"
        case success
    }
} 