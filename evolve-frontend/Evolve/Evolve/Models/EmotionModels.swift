import Foundation

enum EmotionLogType {
    case current
    case daily
}

// Request struct for logging an emotion
// Backend serializers map to model TextFields: 
// causes = serializers.CharField(source="cause")
// impacts = serializers.CharField(source="biggest_impact")
// This implies the backend expects single strings for these fields.
struct EmotionLogRequest: Codable {
    let feeling: String  // This will be sent as "emotion"
    let cause: String    // This will be sent as "cause"
    let biggestImpact: String // This will be sent as "biggest_impact"
    let intensity: Int // Backend model has intensity, serializer also shows it. Add to request.

    private enum CodingKeys: String, CodingKey {
        case feeling = "emotion"
        case cause
        case biggestImpact = "biggest_impact"
        case intensity // Assuming JSON key is "intensity"
    }
}

// Response struct after logging an emotion
struct EmotionLogResponse: Codable, Identifiable {
    let id: Int
    let feeling: String       // From backend serializer source: "emotion"
    let intensity: Int        // From backend model, default 5
    let causes: String        // From backend serializer source: "cause" (single TextField on model)
    let impacts: String       // From backend serializer source: "biggest_impact" (single TextField on model)
    let trackedAt: String     // From backend "tracked_at"
    let date: String?         // Only for daily emotions, from backend "date"

    private enum CodingKeys: String, CodingKey {
        case id
        case feeling = "emotion"
        case intensity
        case causes = "cause"
        case impacts = "biggest_impact"
        case trackedAt = "tracked_at"
        case date
    }
}