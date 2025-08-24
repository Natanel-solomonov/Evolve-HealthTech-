import SwiftUI

// Shared component for macro circles
struct MacroCircleView: View {
    let name: String
    let value: Double
    let unit: String
    let color: Color
    @Environment(\.theme) private var theme: any Theme

    var body: some View {
        VStack(spacing: 8) {
            Text(name)
                .font(.system(size: 12))
                .foregroundColor(theme.primaryText)
            
            ZStack {
                Circle()
                    .stroke(theme.primaryText.opacity(0.2), lineWidth: 6)
                Circle()
                    .trim(from: 0, to: 1)
                    .stroke(color, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                
                VStack(spacing: 2) {
                    Text(String(format: "%.0f", value))
                        .font(.system(size: 16))
                        .foregroundColor(theme.primaryText)
                    Text(unit)
                        .font(.system(size: 10))
                        .foregroundColor(theme.primaryText.opacity(0.8))
                }
            }
            .frame(width: 60, height: 60)
        }
        .frame(maxWidth: .infinity)
    }
}

// Shared component for nutrition badges with vibrant colors
struct NutritionBadge: View {
    let value: Int
    let unit: String
    let color: Color
    let label: String? // Optional label for macro categories
    @Environment(\.theme) private var theme: any Theme
    
    init(value: Int, unit: String, color: Color, label: String? = nil) {
        self.value = value
        self.unit = unit
        self.color = color
        self.label = label
    }
    
    var body: some View {
        VStack(spacing: 2) {
            if let label = label {
                Text(label)
                    .font(.system(size: 8))
                    .foregroundColor(color == .black ? .white.opacity(0.8) : theme.primaryText.opacity(0.8))
            }
            Text("\(value)")
                .font(.system(size: 14))
                .foregroundColor(color == .black ? .white : color)
            Text(unit)
                .font(.system(size: 10))
                .foregroundColor(color == .black ? .white.opacity(0.7) : theme.primaryText.opacity(0.7))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(color == .black ? Color.black : color.opacity(0.2))
        .cornerRadius(8)
    }
}

// Shared vibrant color palette for consistency - Updated to dark green color scheme
extension Color {
    static let vibrantPurple = Color.black     // Calories - Black background with white text
    static let vibrantBlue = Color(red: 0.1, green: 0.4, blue: 0.1)       // Carbs - Dark Green 
    static let vibrantTeal = Color(red: 0.2, green: 0.5, blue: 0.2)       // Protein - Medium Dark Green
    static let vibrantPink = Color(red: 0.15, green: 0.35, blue: 0.15)    // Fat - Darker Green
} 