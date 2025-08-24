import Foundation

struct UserCompletedLog: Codable, Identifiable, Hashable {
    let id: UUID // From backend UUIDField
    let user: String // User's phone number (read-only from serializer)
    let activity: Activity? // Nested Activity object, optional
    let activityNameAtCompletion: String
    let descriptionAtCompletion: String? // Backend TextField(blank=True)
    let completedAt: String // From backend DateTimeField (read-only, default timezone.now)
    let pointsAwarded: Int
    let sourceScheduledActivity: UserScheduledActivity? // Nested UserScheduledActivity object, optional
    let isAdhoc: Bool // From backend BooleanField (default False)
    let userNotesOnCompletion: String?

    enum CodingKeys: String, CodingKey {
        case id, user, activity // direct match or already camelCase
        case activityNameAtCompletion = "activity_name_at_completion"
        case descriptionAtCompletion = "description_at_completion"
        case completedAt = "completed_at"
        case pointsAwarded = "points_awarded"
        case sourceScheduledActivity = "source_scheduled_activity"
        case isAdhoc = "is_adhoc"
        case userNotesOnCompletion = "user_notes_on_completion"
    }
} 