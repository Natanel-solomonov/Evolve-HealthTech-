import SwiftUI

struct WaterCardView: View {
    @Binding var summary: DailyNutritionSummary
    let onTap: () -> Void
    let onSettings: () -> Void
    let onLogWater: (Double, String) -> Void
    let onRemoveWater: (Double) -> Void // New parameter for removing water
    let preferredUnit: WaterUnit // New parameter for user's preferred unit
    
    private let glassSize: CGFloat = 60
    private let maxCupsToShow: Int = 8 // Maximum cups to display
    
    // Dynamic cup amount based on goal - ensures user can track their full goal
    var cupAmountMl: Double {
        let goal = summary.waterGoalMl
        // Calculate cup amount so that maxCupsToShow cups can represent the full goal
        let calculatedAmount = goal / Double(maxCupsToShow)
        // Ensure minimum 100ml per cup and maximum 500ml per cup for usability
        let clampedAmount = max(100, min(500, calculatedAmount))
        
        // For very low goals (< 800ml), use smaller cups to allow more granular tracking
        if goal < 800 {
            return max(50, min(100, goal / 8))
        }
        
        return clampedAmount
    }
    
    var cupsConsumed: Int {
        Int(summary.waterMl / cupAmountMl)
    }
    
    var cupsGoal: Int {
        Int(summary.waterGoalMl / cupAmountMl)
    }
    
    var totalCupsToShow: Int {
        // Show cups needed to reach goal, but cap at maxCupsToShow
        min(cupsGoal, maxCupsToShow)
    }
    
    // Convert water amounts based on user preference
    private var displayWaterConsumed: String {
        let converted = preferredUnit.convert(from: summary.waterMl)
        return String(format: "%.1f", converted)
    }
    
    private var displayWaterGoal: String {
        let converted = preferredUnit.convert(from: summary.waterGoalMl)
        return String(format: "%.1f", converted)
    }
    
    var body: some View {
        VStack(spacing: 16) { // Reduced spacing from 20 to 16
            // Main water card - same height as caffeine/alcohol cards but 10% smaller
            CardContainer {
                VStack(spacing: 12) { // Reduced spacing from 15 to 12
                    // Header with checkmark if goal achieved
                    HStack {
                        Text("Water")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundColor(.black)
                        
                        Spacer()
                        
                        if summary.waterMl >= summary.waterGoalMl {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                                .font(.title3)
                        }
                    }
                    .padding(.bottom, 4) // Reduced from 5 to 4
                    
                    // Water amount display using user's preferred unit
                    HStack {
                        VStack(alignment: .leading, spacing: 3) { // Reduced spacing from 4 to 3
                            Text("Consumed")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.black.opacity(0.7))
                            
                            Text("\(displayWaterConsumed) \(preferredUnit.displayName)")
                                .font(.title3)
                                .fontWeight(.bold)
                                .foregroundColor(.blue)
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing, spacing: 3) { // Reduced spacing from 4 to 3
                            Text("Goal")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.black.opacity(0.7))
                            
                            Text("\(displayWaterGoal) \(preferredUnit.displayName)")
                                .font(.title3)
                                .fontWeight(.bold)
                                .foregroundColor(.black.opacity(0.6))
                        }
                    }
                    
                    // Water glasses grid - dynamic based on goal
                    WaterGlassesView(
                        cupsConsumed: cupsConsumed,
                        totalCupsToShow: totalCupsToShow,
                        onAddWater: {
                            onLogWater(cupAmountMl, "glass")
                        },
                        onRemoveWater: {
                            onRemoveWater(cupAmountMl)
                        }
                    )
                    
                    // Show cup amount info
                    HStack {
                        let cupAmountInPreferredUnit = preferredUnit.convert(from: cupAmountMl)
                        Text("Each cup = \(String(format: "%.1f", cupAmountInPreferredUnit)) \(preferredUnit.displayName)")
                            .font(.caption2)
                            .foregroundColor(.black.opacity(0.6))
                        
                        Spacer()
                        
                        Text("\(cupsConsumed)/\(totalCupsToShow) cups")
                            .font(.caption2)
                            .foregroundColor(.black.opacity(0.6))
                    }
                }
                .padding(.horizontal, 16) // Add horizontal padding
                .padding(.vertical, 12) // Add vertical padding
            }
            .frame(height: 180) // Made taller to accommodate better styling
            .background(
                RoundedRectangle(cornerRadius: 20) // More rounded corners
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color.white.opacity(0.98),
                                Color.white.opacity(0.95)
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .shadow(color: Color.black.opacity(0.12), radius: 12, x: 0, y: 4)
            )
            .clipShape(RoundedRectangle(cornerRadius: 20)) // Ensure content respects rounded corners
            
            // Progress bar with liquid glass style - thinner and better positioned
            LiquidGlassProgressBar(
                current: summary.waterMl,
                goal: summary.waterGoalMl,
                preferredUnit: preferredUnit
            )
            .padding(.top, -4) // Move closer to card
            
            // Settings button - moved up slightly for better visibility
            Button(action: onSettings) {
                HStack(spacing: 6) { // Reduced spacing
                    Image(systemName: "gearshape")
                        .font(.subheadline)
                    Text("Water Settings")
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
                .foregroundColor(.blue)
                .padding(.horizontal, 14) // Slightly reduced padding
                .padding(.vertical, 7) // Slightly reduced padding
                .background(
                    RoundedRectangle(cornerRadius: 18) // More rounded
                        .fill(Color.blue.opacity(0.08))
                        .overlay(
                            RoundedRectangle(cornerRadius: 18)
                                .stroke(Color.blue.opacity(0.2), lineWidth: 0.5)
                        )
                )
            }
            .padding(.top, -8) // Move up for better visibility
        }
        .frame(maxWidth: .infinity) // Ensure consistent width
        .scaleEffect(0.95) // Apply 10% size reduction uniformly
    }
}

struct WaterGlassesView: View {
    let cupsConsumed: Int
    let totalCupsToShow: Int
    let onAddWater: () -> Void
    let onRemoveWater: () -> Void
    
    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<totalCupsToShow, id: \.self) { index in
                if index < cupsConsumed {
                    // Filled glass with minus button
                    WaterGlass(isFilled: true, isAddButton: false, onTap: onRemoveWater)
                } else if index == cupsConsumed && cupsConsumed < totalCupsToShow {
                    // Add button (next empty glass)
                    WaterGlass(isFilled: false, isAddButton: true, onTap: onAddWater)
                } else {
                    // Empty glass
                    WaterGlass(isFilled: false, isAddButton: false, onTap: {})
                }
            }
        }
    }
}

struct WaterGlass: View {
    let isFilled: Bool
    let isAddButton: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            ZStack {
                // Glass container - slightly smaller and cleaner
                RoundedRectangle(cornerRadius: 6) // Smaller corner radius
                    .stroke(Color.black.opacity(0.8), lineWidth: 1.5) // Slightly thinner stroke
                    .frame(width: 44, height: 52) // Slightly smaller from 50x60
                
                if isFilled {
                    // Water fill with gradient - adjusted for smaller size
                    RoundedRectangle(cornerRadius: 5)
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    Color.cyan.opacity(0.8),
                                    Color.blue.opacity(0.9)
                                ]),
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: 40, height: 48) // Adjusted for smaller container
                    
                    // Black minus button overlay for filled glasses - slightly smaller
                    Image(systemName: "minus")
                        .font(.system(size: 12, weight: .bold)) // Smaller font
                        .foregroundColor(.black)
                        .background(
                            Circle()
                                .fill(Color.white.opacity(0.95))
                                .frame(width: 18, height: 18) // Smaller circle
                        )
                } else if isAddButton {
                    // Plus sign for adding water - adjusted size
                    Image(systemName: "plus")
                        .font(.system(size: 16, weight: .semibold)) // Smaller font
                        .foregroundColor(.black.opacity(0.7))
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(!isAddButton && !isFilled) // Enable for add button and filled glasses
    }
}

struct LiquidGlassProgressBar: View {
    let current: Double
    let goal: Double
    let preferredUnit: WaterUnit
    
    var progress: Double {
        min(current / goal, 1.0)
    }
    
    private var displayCurrent: String {
        let converted = preferredUnit.convert(from: current)
        return String(format: "%.1f", converted)
    }
    
    private var displayGoal: String {
        let converted = preferredUnit.convert(from: goal)
        return String(format: "%.1f", converted)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) { // Reduced spacing from 8 to 6
            // Progress text with preferred unit
            HStack {
                Text("Total Water")
                    .font(.subheadline) // Slightly smaller font
                    .fontWeight(.medium)
                
                Text("\(displayCurrent) / \(displayGoal) \(preferredUnit.displayName)")
                    .font(.subheadline) // Slightly smaller font
                    .fontWeight(.medium)
                
                Spacer()
                
                let percentage = Int((current / goal) * 100)
                Text("\(percentage)%")
                    .font(.headline) // Slightly smaller font
                    .fontWeight(.bold)
            }
            
            // Liquid glass progress bar - thinner and cleaner
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background track - thinner
                    RoundedRectangle(cornerRadius: 8) // Smaller corner radius
                        .fill(Color.gray.opacity(0.15)) // Lighter background
                        .frame(height: 16) // Thinner from 24 to 16
                    
                    // Liquid fill with glass effect - thinner
                    RoundedRectangle(cornerRadius: 8) // Smaller corner radius
                        .fill(
                            LinearGradient(
                                gradient: Gradient(stops: [
                                    .init(color: Color.blue.opacity(0.4), location: 0),
                                    .init(color: Color.blue.opacity(0.7), location: 0.5),
                                    .init(color: Color.blue.opacity(0.9), location: 1)
                                ]),
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .overlay(
                            // Glass highlight effect
                            RoundedRectangle(cornerRadius: 8)
                                .fill(
                                    LinearGradient(
                                        gradient: Gradient(colors: [
                                            Color.white.opacity(0.4),
                                            Color.clear
                                        ]),
                                        startPoint: .top,
                                        endPoint: .center
                                    )
                                )
                        )
                        .frame(
                            width: geometry.size.width * progress,
                            height: 16 // Thinner from 24 to 16
                        )
                        .animation(.easeInOut(duration: 0.5), value: progress)
                }
            }
            .frame(height: 16) // Thinner from 24 to 16
            .padding(.horizontal, 16) // Reduced from 20 to 16
        }
    }
}

struct InfoBanner: View {
    let message: String
    let onDismiss: () -> Void
    
    var body: some View {
        HStack {
            Text(message)
                .font(.caption)
                .foregroundColor(.blue)
                .multilineTextAlignment(.leading)
            
            Spacer()
            
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.caption)
                    .foregroundColor(.blue)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.blue.opacity(0.1))
        )
    }
}

// Preview
struct WaterCardView_Previews: PreviewProvider {
    @State static var mockSummary = DailyNutritionSummary(
        waterMl: 750,
        waterGoalMl: 2000
    )
    
    static var previews: some View {
        VStack {
            WaterCardView(
                summary: $mockSummary,
                onTap: { print("View details tapped") },
                onSettings: { print("Settings tapped") },
                onLogWater: { amount, type in
                    print("Logged \(amount)ml of \(type)")
                    mockSummary.waterMl += amount
                },
                onRemoveWater: { amount in
                    print("Removed \(amount)ml of water")
                    mockSummary.waterMl -= amount
                },
                preferredUnit: .milliliters // Assuming milliliters is the default for preview
            )
            
            Spacer()
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .previewLayout(.sizeThatFits)
    }
} 