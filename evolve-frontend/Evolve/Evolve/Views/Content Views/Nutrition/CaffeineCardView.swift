// CaffeineCardView.swift
import SwiftUI

struct CaffeineCardView: View {
    @Binding var summary: DailyNutritionSummary
    let dailyTracker: DailyCalorieTracker?
    let onTap: () -> Void
    let onCategorySelected: (CaffeineCategory) -> Void
    
    private let caffeineColor = Color(red: 0.8, green: 0.4, blue: 0.1) // Orange/brown for caffeine
    
    // Computed property to check if caffeine has been tracked
    private var hasCaffeineTracked: Bool {
        return summary.caffeineMg > 0
    }
    
    var body: some View {
        VStack(spacing: 20) {
            // Main Caffeine Card
            CardContainer {
                VStack(alignment: .leading, spacing: 15) {
                    HStack {
                        Text("Caffeine Tracking")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundColor(.black)
                        
                        Spacer()
                    }
                    .padding(.bottom, 5)
                    
                    if hasCaffeineTracked {
                        // Show tracked caffeine icons
                        if let tracker = dailyTracker {
                            TrackedCaffeineIconsView(tracker: tracker)
                        }
                        
                        // Show caffeine stats when products are tracked
                        CaffeineStatsView(summary: $summary, color: caffeineColor)
                    } else {
                        // Descriptive text for empty state
                        Text("Stay energized and track your daily caffeine intake from coffee, tea, energy drinks, and more.")
                            .font(.caption)
                            .foregroundColor(.black.opacity(0.7))
                            .multilineTextAlignment(.leading)
                            .lineLimit(2)
                            .padding(.bottom, 5)
                        
                        // Show empty state when no caffeine tracked
                        Spacer()
                    }
                }
            }
            .frame(height: 160)
            
            // Category Icons Below Card
            VStack(spacing: 12) {
                // Category Icons Row - Full Width
                HStack {
                    ForEach(caffeineCategories, id: \.key) { category in
                        Button(action: {
                            // Pass the specific category to the navigation
                            onCategorySelected(category)
                        }) {
                            Text(category.icon)
                                .font(.system(size: 26))
                                .frame(width: 48, height: 48)
                                .background(Color.gray.opacity(0.1))
                                .cornerRadius(16)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                                )
                        }
                        .buttonStyle(CaffeineCategoryButtonStyle())
                        
                        // Add spacer between icons (except for the last one)
                        if category.key != caffeineCategories.last?.key {
                            Spacer()
                        }
                    }
                }
                
                // User Guidance Text
                Text("Click any icon above to browse and track caffeine products")
                    .font(.caption)
                    .foregroundColor(.black.opacity(0.6))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
        }
    }
    
    // Caffeine categories data
    private var caffeineCategories: [CaffeineCategory] {
        [
            CaffeineCategory(key: "coffee", name: "Coffee", icon: "☕", count: 1700),
            CaffeineCategory(key: "energy_drink", name: "Energy Drink", icon: "⚡", count: 1480),
            CaffeineCategory(key: "tea", name: "Tea", icon: "🫖", count: 800),
            CaffeineCategory(key: "soda", name: "Soda", icon: "🥤", count: 400),
            CaffeineCategory(key: "supplement", name: "Supplement", icon: "💊", count: 1200)
        ]
    }
}

// MARK: - Tracked Caffeine Icons View
struct TrackedCaffeineIconsView: View {
    let tracker: DailyCalorieTracker
    
    private var caffeineEntries: [FoodEntry] {
        tracker.foodEntries.filter { $0.isCaffeineProduct }
    }
    
    private var orderedCategories: [(category: String, count: Int)] {
        var categoryOrder: [String] = []
        var counts: [String: Int] = [:]
        
        // Maintain order of first appearance and count occurrences
        for entry in caffeineEntries.sorted(by: { $0.timeConsumed < $1.timeConsumed }) {
            if let category = entry.caffeineCategory {
                if !categoryOrder.contains(category) {
                    categoryOrder.append(category)
                }
                counts[category, default: 0] += 1
            }
        }
        
        return categoryOrder.map { (category: $0, count: counts[$0] ?? 0) }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            LazyVGrid(columns: [
                GridItem(.adaptive(minimum: 30, maximum: 60), spacing: 8)
            ], spacing: 8) {
                ForEach(orderedCategories, id: \.category) { item in
                    HStack(spacing: 4) {
                        // Show multiple icons based on count (max 3 per category)
                        ForEach(0..<min(item.count, 3), id: \.self) { _ in
                            Text(iconForCategory(item.category))
                                .font(.system(size: 18))
                        }
                        
                        // Show count if more than 3
                        if item.count > 3 {
                            Text("×\(item.count)")
                                .font(.caption2)
                                .fontWeight(.medium)
                                .foregroundColor(.black.opacity(0.7))
                        }
                    }
                }
            }
        }
        .padding(.bottom, 5)
    }
    
    private func iconForCategory(_ category: String) -> String {
        switch category {
        case "coffee": return "☕"
        case "energy_drink": return "⚡"
        case "tea": return "🫖"
        case "soda": return "🥤"
        case "supplement": return "💊"
        default: return "🥤"
        }
    }
}

// MARK: - Caffeine Stats View
struct CaffeineStatsView: View {
    @Binding var summary: DailyNutritionSummary
    let color: Color
    
    var body: some View {
        HStack(spacing: 12) {
            // Total Caffeine (prominently displayed)
            VStack(alignment: .leading, spacing: 4) {
                Text("Total Caffeine")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.black.opacity(0.7))
                    .multilineTextAlignment(.leading)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                Text("\(Int(summary.caffeineMg))mg")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(color)
            }
            .frame(maxWidth: .infinity)
            
            // Caffeine Status
            VStack(alignment: .center, spacing: 4) {
                Text("Status")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.black.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .center)
                
                Text(caffeineStatusText)
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(caffeineStatusColor)
            }
            .frame(maxWidth: .infinity)
            
            // Daily Recommendation
            VStack(alignment: .trailing, spacing: 4) {
                Text("Daily Limit")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.black.opacity(0.7))
                    .multilineTextAlignment(.trailing)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                
                Text("400mg")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.black.opacity(0.6))
            }
            .frame(maxWidth: .infinity)
        }
    }
    
    // Computed properties for caffeine status
    private var caffeineStatusText: String {
        let caffeine = summary.caffeineMg
        if caffeine == 0 {
            return "None"
        } else if caffeine <= 100 {
            return "Low"
        } else if caffeine <= 200 {
            return "Moderate"
        } else if caffeine <= 300 {
            return "High"
        } else if caffeine <= 400 {
            return "Very High"
        } else {
            return "Excessive"
        }
    }
    
    private var caffeineStatusColor: Color {
        let caffeine = summary.caffeineMg
        if caffeine == 0 {
            return .gray
        } else if caffeine <= 100 {
            return .green
        } else if caffeine <= 200 {
            return .blue
        } else if caffeine <= 300 {
            return .orange
        } else if caffeine <= 400 {
            return .red
        } else {
            return .red
        }
    }
}

// MARK: - Caffeine Category Button Style
struct CaffeineCategoryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .opacity(configuration.isPressed ? 0.8 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - Preview
struct CaffeineCardView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            // Preview with caffeine entries
            CaffeineCardView(
                summary: .constant(DailyNutritionSummary(caffeineMg: 250)),
                dailyTracker: sampleTrackerWithCaffeine,
                onTap: {},
                onCategorySelected: { _ in }
            )
            .previewDisplayName("With Caffeine")
            
            // Preview without caffeine entries
            CaffeineCardView(
                summary: .constant(DailyNutritionSummary()),
                dailyTracker: sampleTrackerEmpty,
                onTap: {},
                onCategorySelected: { _ in }
            )
            .previewDisplayName("Empty State")
        }
        .previewLayout(.fixed(width: 350, height: 280))
    }
    
    // Sample data for previews
    static let sampleTrackerWithCaffeine = DailyCalorieTracker(
        id: 1,
        userDetails: "+1234567890",
        date: "2025-07-24",
        totalCalories: 250,
        calorieGoal: 2000,
        proteinGrams: 0,
        carbsGrams: 0,
        fatGrams: 0,
        fiberGrams: 0,
        ironMilligrams: 0,
        calciumMilligrams: 0,
        vitaminAMicrograms: 0,
        vitaminCMilligrams: 0,
        vitaminB12Micrograms: 0,
        folateMicrograms: 0,
        potassiumMilligrams: 0,
        alcoholGrams: 0,
        standardDrinks: 0,
        caffeineMg: 250,
        createdAt: "2025-07-24T12:00:00Z",
        updatedAt: "2025-07-24T12:00:00Z",
        foodEntries: [
            FoodEntry(
                id: 1,
                dailyLog: 1,
                foodName: "Coffee",
                servingSize: 1,
                servingUnit: "serving",
                calories: 5,
                protein: 0,
                carbs: 0,
                fat: 0,
                fiberGrams: 0,
                ironMilligrams: 0,
                calciumMilligrams: 0,
                vitaminAMicrograms: 0,
                vitaminCMilligrams: 0,
                vitaminB12Micrograms: 0,
                folateMicrograms: 0,
                potassiumMilligrams: 0,
                alcoholicBeverage: nil,
                alcoholGrams: nil,
                standardDrinks: nil,
                alcoholCategory: nil,
                caffeineProduct: "some-id",
                caffeineMg: 250,
                caffeineCategory: "coffee",
                mealType: "caffeine",
                timeConsumed: "2025-07-24T12:00:00Z",
                createdAt: "2025-07-24T12:00:00Z",
                updatedAt: "2025-07-24T12:00:00Z",
                foodProductId: nil,
                customFoodId: nil
            )
        ]
    )
    
    static let sampleTrackerEmpty = DailyCalorieTracker(
        id: 1,
        userDetails: "+1234567890",
        date: "2025-07-24",
        totalCalories: 0,
        calorieGoal: 2000,
        proteinGrams: 0,
        carbsGrams: 0,
        fatGrams: 0,
        fiberGrams: 0,
        ironMilligrams: 0,
        calciumMilligrams: 0,
        vitaminAMicrograms: 0,
        vitaminCMilligrams: 0,
        vitaminB12Micrograms: 0,
        folateMicrograms: 0,
        potassiumMilligrams: 0,
        alcoholGrams: 0,
        standardDrinks: 0,
        caffeineMg: 0,
        createdAt: "2025-07-24T12:00:00Z",
        updatedAt: "2025-07-24T12:00:00Z",
        foodEntries: []
    )
} 