import SwiftUI

/// Centralized helper for activity types, categories, colors, and emojis
struct ActivityTypeHelper {
    
    // MARK: - Activity Type to Emoji Mapping
    static func emoji(for activityType: String) -> String {
        switch activityType.lowercased() {
        // Fitness types
        case "workout": return "🏋"
        case "weight tracking": return "⚖️"
        case "personal record": return "🏆"
        
        // Nutrition types
        case "food log": return "🍽️"
        case "water intake": return "💧"
        case "caffeine log": return "☕"
        case "alcohol log": return "🍷"
        case "recipe": return "👨‍🍳"
        case "supplement log": return "💊"
        
        // Mind types
        case "journal": return "📓"
        case "meditation": return "🧘"
        case "breathing": return "🌬️"
        case "mood check": return "😊"
        case "emotions check": return "💭"
        case "energy level log": return "⚡"
        
        // Sleep types
        case "sleep tracking": return "😴"
        case "sleep debt calculation": return "🛏️"
        
        // Other types
        case "prescription log": return "💊"
        case "sex log": return "❤️"
        case "symptoms log": return "🩺"
        case "cycle log": return "🌙"
        
        default: return "⭐"
        }
    }
    
    // MARK: - Category to Emoji Mapping (fallback)
    static func categoryEmoji(for category: String) -> String {
        switch category.capitalized {
        case "Fitness": return "💪"
        case "Nutrition": return "🍽️"
        case "Mind": return "🧠"
        case "Sleep": return "😴"
        case "Routine": return "🔄"
        case "Other": return "📌"
        default: return "⭐"
        }
    }
    
    // MARK: - Category to Color Mapping
    static func color(for category: String) -> Color {
        switch category.capitalized {
        case "Fitness": return Color("Fitness")
        case "Nutrition": return Color("Nutrition")
        case "Mind": return Color("Mind")
        case "Sleep": return Color("Sleep")
        case "Routine": return Color.gray
        case "Other": return Color.black
        default: return Color.blue
        }
    }
    
    // MARK: - Get emoji with fallback logic
    static func getEmoji(activityType: String?, categories: [String]) -> String {
        // First try activity type
        if let activityType = activityType, !activityType.isEmpty {
            let typeEmoji = emoji(for: activityType)
            if typeEmoji != "⭐" { // If we found a specific emoji
                return typeEmoji
            }
        }
        
        // Fall back to category
        if let firstCategory = categories.first {
            return categoryEmoji(for: firstCategory)
        }
        
        return "⭐"
    }
    
    // MARK: - Format activity type for display
    static func formatActivityType(_ activityType: String) -> String {
        return activityType.split(separator: " ")
            .map { $0.capitalized }
            .joined(separator: " ")
    }
} 
