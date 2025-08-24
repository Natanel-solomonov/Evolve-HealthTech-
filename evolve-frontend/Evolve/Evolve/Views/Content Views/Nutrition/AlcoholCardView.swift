// AlcoholCardView.swift
import SwiftUI

struct AlcoholCardView: View {
    @Binding var summary: DailyNutritionSummary
    let dailyTracker: DailyCalorieTracker?
    let onTap: () -> Void
    let onCategorySelected: (AlcoholCategory) -> Void
    
    private let alcoholColor = Color(red: 0.2, green: 0.3, blue: 0.5) // Deep blue for alcohol
    
    // Computed property to check if alcohol has been tracked
    private var hasAlcoholTracked: Bool {
        return summary.alcoholGrams > 0 || summary.standardDrinks > 0
    }
    
    var body: some View {
        VStack(spacing: 20) {
            // Main Alcohol Card
            CardContainer {
                VStack(alignment: .leading, spacing: 15) {
                                    HStack {
                    Text("Alcohol Tracking")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.black)
                    
                    Spacer()
                }
                    .padding(.bottom, 5)
                    
                    if hasAlcoholTracked {
                        // Show tracked alcohol icons
                        if let tracker = dailyTracker {
                            TrackedAlcoholIconsView(tracker: tracker)
                        }
                        
                        // Show alcohol stats when beverages are tracked
                        AlcoholStatsView(summary: $summary, color: alcoholColor)
                    } else {
                        // Descriptive text for empty state
                        Text("A drink every now and then can be a nice reward. Track your alcohol consumption here.")
                            .font(.caption)
                            .foregroundColor(.black.opacity(0.7))
                            .multilineTextAlignment(.leading)
                            .lineLimit(2)
                            .padding(.bottom, 5)
                        
                        // Show empty state when no alcohol tracked
                        Spacer()
                    }
                }
            }
            .frame(height: 160)
            
            // Category Icons Below Card
            VStack(spacing: 12) {
                // Category Icons Row - Full Width
                HStack {
                    ForEach(alcoholCategories, id: \.key) { category in
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
                        .buttonStyle(AlcoholCategoryButtonStyle())
                        
                        // Add spacer between icons (except for the last one)
                        if category.key != alcoholCategories.last?.key {
                            Spacer()
                        }
                    }
                }
                
                // User Guidance Text
                Text("Click any icon above to browse and track alcoholic beverages")
                    .font(.caption)
                    .foregroundColor(.black.opacity(0.6))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
        }

    }
    
    // Alcohol categories data
    private var alcoholCategories: [AlcoholCategory] {
        [
            AlcoholCategory(key: "beer", name: "Beer/Seltzer", icon: "🍺", count: 142),
            AlcoholCategory(key: "wine", name: "Wine/Champagne", icon: "🍷", count: 82),
            AlcoholCategory(key: "sparkling", name: "Sparkling", icon: "🥂", count: 47),
            AlcoholCategory(key: "liquor", name: "Liquor", icon: "🥃", count: 98),
            AlcoholCategory(key: "fortified", name: "Fortified", icon: "🍷", count: 54)
        ]
    }
}

// MARK: - Tracked Alcohol Icons View
struct TrackedAlcoholIconsView: View {
    let tracker: DailyCalorieTracker
    
    private var alcoholEntries: [FoodEntry] {
        tracker.foodEntries.filter { $0.isAlcoholicBeverage }
    }
    
    private var orderedCategories: [(category: String, count: Int)] {
        var categoryOrder: [String] = []
        var counts: [String: Int] = [:]
        
        // Maintain order of first appearance and count occurrences
        for entry in alcoholEntries.sorted(by: { $0.timeConsumed < $1.timeConsumed }) {
            if let category = entry.alcoholCategory {
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
        case "beer": return "🍺"
        case "wine": return "🍷"
        case "champagne": return "🥂"
        case "fortified_wine": return "🍷"
        case "liquor": return "🥃"
        case "cocktail": return "🍸"
        default: return "🍹"
        }
    }
}

// MARK: - Alcohol Stats View
struct AlcoholStatsView: View {
    @Binding var summary: DailyNutritionSummary
    let color: Color
    
    var body: some View {
        HStack(spacing: 12) {
            // Standard Drinks
            VStack(alignment: .leading, spacing: 4) {
                Text("Standard Drinks")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.black.opacity(0.7))
                    .multilineTextAlignment(.leading)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                Text(String(format: "%.1f", summary.standardDrinks))
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(color)
            }
            .frame(maxWidth: .infinity)
            
            // Alcohol Calories
            VStack(alignment: .center, spacing: 4) {
                Text("Alcohol Calories")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.black.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .center)
                
                Text("\(Int(summary.alcoholGrams * 7))")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(color)
            }
            .frame(maxWidth: .infinity)
            
            // Alcohol Grams
            VStack(alignment: .trailing, spacing: 4) {
                Text("Alcohol (g)")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.black.opacity(0.7))
                    .multilineTextAlignment(.trailing)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                
                Text(String(format: "%.1f", summary.alcoholGrams))
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(color)
            }
            .frame(maxWidth: .infinity)
        }
    }
}

// MARK: - Custom Button Style for Category Icons
struct AlcoholCategoryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .opacity(configuration.isPressed ? 0.8 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - Preview
struct AlcoholCardView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            // Preview with alcohol entries
            AlcoholCardView(
                summary: .constant(DailyNutritionSummary()),
                dailyTracker: sampleTrackerWithAlcohol,
                onTap: {},
                onCategorySelected: { _ in }
            )
            .previewDisplayName("With Alcohol")
            
            // Preview without alcohol entries
            AlcoholCardView(
                summary: .constant(DailyNutritionSummary()),
                dailyTracker: sampleTrackerEmpty,
                onTap: {},
                onCategorySelected: { _ in }
            )
            .previewDisplayName("Empty State")
        }
        .previewLayout(.fixed(width: 350, height: 280))
    }
    
    static var sampleTrackerWithAlcohol: DailyCalorieTracker {
        DailyCalorieTracker(
            id: 1,
            userDetails: "user123",
            date: "2024-01-20",
            totalCalories: 1800,
            calorieGoal: 2000,
            proteinGrams: 120.0,
            carbsGrams: 200.0,
            fatGrams: 80.0,
            fiberGrams: 25.0,
            ironMilligrams: 12.0,
            calciumMilligrams: 800.0,
            vitaminAMicrograms: 700.0,
            vitaminCMilligrams: 60.0,
            vitaminB12Micrograms: 2.0,
            folateMicrograms: 300.0,
            potassiumMilligrams: 2500.0,
            alcoholGrams: 28.0,
            standardDrinks: 2.0,
            caffeineMg: 0.0,
            createdAt: "2024-01-20T10:00:00Z",
            updatedAt: "2024-01-20T15:00:00Z",
            foodEntries: [
                FoodEntry(
                    id: 1,
                    dailyLog: 1,
                    foodName: "Bud Light",
                    servingSize: 1.0,
                    servingUnit: "standard drink",
                    calories: 110,
                    protein: 0.0,
                    carbs: 6.6,
                    fat: 0.0,
                    fiberGrams: nil,
                    ironMilligrams: nil,
                    calciumMilligrams: nil,
                    vitaminAMicrograms: nil,
                    vitaminCMilligrams: nil,
                    vitaminB12Micrograms: nil,
                    folateMicrograms: nil,
                    potassiumMilligrams: nil,
                    alcoholicBeverage: "beer_001",
                    alcoholGrams: 14.0,
                    standardDrinks: 1.0,
                    alcoholCategory: "beer",
                    caffeineProduct: nil,
                    caffeineMg: nil,
                    caffeineCategory: nil,
                    mealType: "dinner",
                    timeConsumed: "2024-01-20T18:00:00Z",
                    createdAt: "2024-01-20T18:00:00Z",
                    updatedAt: "2024-01-20T18:00:00Z",
                    foodProductId: nil,
                    customFoodId: nil
                ),
                FoodEntry(
                    id: 2,
                    dailyLog: 1,
                    foodName: "Cabernet Sauvignon",
                    servingSize: 1.0,
                    servingUnit: "standard drink",
                    calories: 130,
                    protein: 0.0,
                    carbs: 4.0,
                    fat: 0.0,
                    fiberGrams: nil,
                    ironMilligrams: nil,
                    calciumMilligrams: nil,
                    vitaminAMicrograms: nil,
                    vitaminCMilligrams: nil,
                    vitaminB12Micrograms: nil,
                    folateMicrograms: nil,
                    potassiumMilligrams: nil,
                    alcoholicBeverage: "wine_001",
                    alcoholGrams: 14.0,
                    standardDrinks: 1.0,
                    alcoholCategory: "wine",
                    caffeineProduct: nil,
                    caffeineMg: nil,
                    caffeineCategory: nil,
                    mealType: "dinner",
                    timeConsumed: "2024-01-20T19:00:00Z",
                    createdAt: "2024-01-20T19:00:00Z",
                    updatedAt: "2024-01-20T19:00:00Z",
                    foodProductId: nil,
                    customFoodId: nil
                )
            ]
        )
    }
    
    static var sampleTrackerEmpty: DailyCalorieTracker {
        DailyCalorieTracker(
            id: 1,
            userDetails: "user123",
            date: "2024-01-20",
            totalCalories: 1500,
            calorieGoal: 2000,
            proteinGrams: 100.0,
            carbsGrams: 180.0,
            fatGrams: 60.0,
            fiberGrams: 20.0,
            ironMilligrams: 10.0,
            calciumMilligrams: 600.0,
            vitaminAMicrograms: 500.0,
            vitaminCMilligrams: 40.0,
            vitaminB12Micrograms: 1.5,
            folateMicrograms: 200.0,
            potassiumMilligrams: 2000.0,
            alcoholGrams: 0.0,
            standardDrinks: 0.0,
            caffeineMg: 0.0,
            createdAt: "2024-01-20T10:00:00Z",
            updatedAt: "2024-01-20T15:00:00Z",
            foodEntries: []
        )
    }
} 