import Foundation

struct UserScheduledActivity: Codable, Identifiable, Hashable {
    let id: UUID // From backend UUIDField
    let user: String // User's phone number (read-only from serializer)
    let activity: Activity // Nested Activity object
    let scheduledDate: String // Format YYYY-MM-DD (from backend DateField)
    let scheduledDisplayTime: String? // From backend CharField (nullable)
    let isGenerated: Bool   // From backend BooleanField (read-only, default False)
    let orderInDay: Int     // From backend PositiveIntegerField (default 0)
    var isComplete: Bool    // From backend BooleanField (default False)
    var completedAt: String? // From backend DateTimeField (nullable, read-only)
    let generatedDescription: String? // AI-generated summary from backend
    let customNotes: String?

    enum CodingKeys: String, CodingKey {
        case id, user, activity // direct match or already camelCase
        case scheduledDate = "scheduled_date"
        case scheduledDisplayTime = "scheduled_display_time"
        case isGenerated = "is_generated"
        case orderInDay = "order_in_day"
        case isComplete = "is_complete"
        case completedAt = "completed_at"
        case generatedDescription = "generated_description"
        case customNotes = "custom_notes"
    }
}

// MARK: - UserScheduledActivity Extensions
extension UserScheduledActivity {
    /// Returns true if the activity has been completed
    var hasBeenCompleted: Bool {
        return isComplete && completedAt != nil
    }
    
    /// Returns the completion date as a Date object if available
    var completionDate: Date? {
        guard let completedAt = completedAt else { return nil }
        let formatter = ISO8601DateFormatter()
        return formatter.date(from: completedAt)
    }
    
    /// Returns the scheduled date as a Date object
    var scheduledDateAsDate: Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: scheduledDate)
    }
    
    /// Creates a mutable copy with updated completion status
    func withCompletionStatus(_ isComplete: Bool) -> UserScheduledActivity {
        var updated = self
        updated.isComplete = isComplete
        // Note: completedAt will be updated by the backend when the request is made
        return updated
    }
    
    /// Creates a mutable copy with updated notes
    func withNotes(_ notes: String?) -> UserScheduledActivity {
        return UserScheduledActivity(
            id: self.id,
            user: self.user,
            activity: self.activity,
            scheduledDate: self.scheduledDate,
            scheduledDisplayTime: self.scheduledDisplayTime,
            isGenerated: self.isGenerated,
            orderInDay: self.orderInDay,
            isComplete: self.isComplete,
            completedAt: self.completedAt,
            generatedDescription: self.generatedDescription,
            customNotes: notes
        )
    }
} 