// AlcoholBeverageDetailView.swift
import SwiftUI

struct AlcoholBeverageDetailView: View {
    @EnvironmentObject var authManager: AuthenticationManager
    @State private var selectedQuantity = 1
    @State private var isLogging = false
    @State private var hasLogged = false // Prevent multiple API calls
    private let viewId = UUID() // Track view instance
    
    let beverage: AlcoholicBeverage
    let onLog: (AlcoholicBeverage, Int) -> Void
    let onDismiss: () -> Void
    private let quantities = Array(1...5)
    
    // Colors to match nutrition theme
    private var gradientStartColor: Color { Color("Nutrition").opacity(0.6) }
    private var gradientEndColor: Color { Color("Nutrition") }
    private var accentColor: Color { Color(red: 0.2, green: 0.3, blue: 0.5) }
    
    var totalCalories: Int {
        Int(beverage.calories) * selectedQuantity
    }
    
    var totalCarbs: Double {
        beverage.carbsGrams * Double(selectedQuantity)
    }
    
    var totalAlcohol: Double {
        beverage.alcoholGrams * Double(selectedQuantity)
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background gradient
                LinearGradient(
                    gradient: Gradient(colors: [gradientStartColor, gradientEndColor]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .edgesIgnoringSafeArea(.all)
                
                ScrollView {
                    VStack(spacing: 25) {
                        // Header with icon and basic info
                        VStack(spacing: 16) {
                            // Category Icon
                            Text(beverage.categoryIcon)
                                .font(.system(size: 60))
                                .frame(width: 100, height: 100)
                                .background(Color.white.opacity(0.15))
                                .cornerRadius(25)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 25)
                                        .stroke(Color.white.opacity(0.3), lineWidth: 2)
                                )
                            
                            // Beverage Name and Brand
                            VStack(spacing: 8) {
                                Text(beverage.name)
                                    .font(.title2)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                                    .multilineTextAlignment(.center)
                                
                                if let brand = beverage.brand, !brand.isEmpty && brand != "Generic" {
                                    Text(brand)
                                        .font(.headline)
                                        .foregroundColor(.white.opacity(0.8))
                                        .multilineTextAlignment(.center)
                                }
                                
                                Text(beverage.categoryDisplay)
                                    .font(.subheadline)
                                    .foregroundColor(.white.opacity(0.7))
                                    .multilineTextAlignment(.center)
                            }
                        }
                        .padding(.top, 20)
                        
                        // Nutrition Information Card
                        NutritionInfoCard(
                            calories: totalCalories,
                            carbs: totalCarbs,
                            alcoholPercent: beverage.alcoholContentPercent,
                            alcoholGrams: totalAlcohol,
                            servingDescription: beverage.servingDescription,
                            quantity: selectedQuantity
                        )
                        
                        // Quantity Selection
                        QuantitySelectionCard(
                            selectedQuantity: $selectedQuantity,
                            quantities: quantities
                        )
                        
                        // Removed meal type selection - not needed for alcohol tracking
                        
                        // Log Button
                        Button(action: {
                            print("AlcoholBeverageDetailView: Log button tapped")
                            logBeverage()
                        }) {
                            HStack {
                                if isLogging {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        .scaleEffect(0.8)
                                } else if hasLogged {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.title2)
                                        .foregroundColor(.green)
                                } else {
                                    Image(systemName: "plus.circle.fill")
                                        .font(.title2)
                                }
                                
                                Text(isLogging ? "Logging..." : (hasLogged ? "Logged!" : "Log \(selectedQuantity) Standard Drink\(selectedQuantity > 1 ? "s" : "")"))
                                    .font(.headline)
                                    .fontWeight(.semibold)
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(accentColor)
                            .cornerRadius(12)
                        }
                        .disabled(isLogging || hasLogged)
                        .padding(.horizontal, 20)
                        
                        Spacer(minLength: 50)
                    }
                    .padding(.horizontal, 20)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        onDismiss()
                    }
                    .foregroundColor(.white)
                }
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            print("AlcoholBeverageDetailView [\(viewId)]: View appeared for beverage: \(beverage.name)")
        }
        .onDisappear {
            print("AlcoholBeverageDetailView [\(viewId)]: View disappeared for beverage: \(beverage.name)")
            // Reset logging state if view is dismissed without logging
            if !hasLogged {
                isLogging = false
                hasLogged = false
            }
        }
    }
    
    private func logBeverage() {
        print("AlcoholBeverageDetailView [\(viewId)]: logBeverage() called, isLogging: \(isLogging), hasLogged: \(hasLogged)")
        
        // Prevent multiple calls
        guard !isLogging && !hasLogged else {
            print("AlcoholBeverageDetailView [\(viewId)]: Already logging or has logged, ignoring call")
            return
        }
        
        guard let userPhone = authManager.currentUser?.phone else {
            print("AlcoholBeverageDetailView [\(viewId)]: User not logged in")
            return
        }
        
        isLogging = true
        hasLogged = true
        print("AlcoholBeverageDetailView [\(viewId)]: Set isLogging to true and hasLogged to true")
        
        let taskId = UUID()
        print("AlcoholBeverageDetailView [\(viewId)]: Creating Task with ID: \(taskId)")
        
        Task {
            print("AlcoholBeverageDetailView [\(viewId)]: Task [\(taskId)] started execution")
            do {
                print("AlcoholBeverageDetailView [\(viewId)]: Task [\(taskId)] - Creating AlcoholAPI instance")
                let alcoholAPI = AlcoholAPI(httpClient: authManager.httpClient)
                print("AlcoholBeverageDetailView [\(viewId)]: Task [\(taskId)] - About to call logAlcoholicBeverage for \(beverage.name)")
                let response = try await alcoholAPI.logAlcoholicBeverage(
                    beverage: beverage,
                    quantity: selectedQuantity,
                    mealType: "alcohol", // Default meal type for alcohol
                    userPhone: userPhone
                )
                print("AlcoholBeverageDetailView [\(viewId)]: Task [\(taskId)] - API call completed successfully: \(response)")
                
                await MainActor.run {
                    print("AlcoholBeverageDetailView [\(viewId)]: Task [\(taskId)] - About to call onLog callback")
                    // Call the callback to update local UI
                    onLog(beverage, selectedQuantity)
                    print("AlcoholBeverageDetailView [\(viewId)]: Task [\(taskId)] - onLog callback completed")
                    isLogging = false
                    
                    // Add a small delay to show success state before dismissing
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        print("AlcoholBeverageDetailView [\(viewId)]: Task [\(taskId)] - About to call onDismiss")
                        onDismiss()
                    }
                }
            } catch {
                await MainActor.run {
                    print("AlcoholBeverageDetailView [\(viewId)]: Task [\(taskId)] - Error logging beverage: \(error)")
                    // Don't call onLog callback on error - let user retry
                    isLogging = false
                }
            }
            print("AlcoholBeverageDetailView [\(viewId)]: Task [\(taskId)] completed execution")
        }
    }
}

// MARK: - Nutrition Info Card
struct NutritionInfoCard: View {
    let calories: Int
    let carbs: Double
    let alcoholPercent: Double
    let alcoholGrams: Double
    let servingDescription: String
    let quantity: Int
    
    var body: some View {
        VStack(spacing: 20) {
            // Title
            Text("Nutrition Information")
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(.white)
            
            // Serving info
            Text("\(quantity) × \(servingDescription)")
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.8))
            
            // Nutrition Grid
            HStack(spacing: 0) {
                // Calories
                NutritionStatView(
                    value: "\(calories)",
                    unit: "cal",
                    label: "Calories",
                    color: .orange
                )
                
                Divider()
                    .background(Color.white.opacity(0.3))
                    .frame(height: 60)
                
                // Carbs
                NutritionStatView(
                    value: String(format: "%.1f", carbs),
                    unit: "g",
                    label: "Carbs",
                    color: .green
                )
                
                Divider()
                    .background(Color.white.opacity(0.3))
                    .frame(height: 60)
                
                // Alcohol
                NutritionStatView(
                    value: String(format: "%.1f", alcoholGrams),
                    unit: "g",
                    label: "Alcohol",
                    color: .blue
                )
            }
            
            // Alcohol percentage
            Text("\(String(format: "%.1f", alcoholPercent))% Alcohol by Volume")
                .font(.caption)
                .foregroundColor(.white.opacity(0.7))
        }
        .padding(20)
        .background(Color.white.opacity(0.1))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.2), lineWidth: 1)
        )
    }
}

// MARK: - Nutrition Stat View
struct NutritionStatView: View {
    let value: String
    let unit: String
    let label: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            HStack(alignment: .bottom, spacing: 2) {
                Text(value)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                Text(unit)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.white.opacity(0.8))
                    .offset(y: -2)
            }
            
            Text(label)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(color.opacity(0.9))
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Quantity Selection Card
struct QuantitySelectionCard: View {
    @Binding var selectedQuantity: Int
    let quantities: [Int]
    
    var body: some View {
        VStack(spacing: 16) {
            Text("How many standard drinks?")
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(.white)
            
            HStack(spacing: 12) {
                ForEach(quantities, id: \.self) { quantity in
                    Button(action: {
                        selectedQuantity = quantity
                    }) {
                        Text("\(quantity)")
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(selectedQuantity == quantity ? .black : .white)
                            .frame(width: 44, height: 44)
                            .background(selectedQuantity == quantity ? Color.white : Color.white.opacity(0.2))
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.white.opacity(0.3), lineWidth: 1)
                            )
                    }
                    .scaleEffect(selectedQuantity == quantity ? 1.1 : 1.0)
                    .animation(.easeInOut(duration: 0.2), value: selectedQuantity)
                }
            }
        }
        .padding(20)
        .background(Color.white.opacity(0.1))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.2), lineWidth: 1)
        )
    }
}

// MARK: - Meal Type Selection Card
struct MealTypeSelectionCard: View {
    @Binding var selectedMealType: String
    let mealTypes: [String]
    
    var body: some View {
        VStack(spacing: 16) {
            Text("When are you having this?")
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(.white)
            
            HStack(spacing: 8) {
                ForEach(mealTypes, id: \.self) { mealType in
                    Button(action: {
                        selectedMealType = mealType
                    }) {
                        Text(mealType.capitalized)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(selectedMealType == mealType ? .black : .white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(selectedMealType == mealType ? Color.white : Color.white.opacity(0.2))
                            .cornerRadius(20)
                            .overlay(
                                RoundedRectangle(cornerRadius: 20)
                                    .stroke(Color.white.opacity(0.3), lineWidth: 1)
                            )
                    }
                    .scaleEffect(selectedMealType == mealType ? 1.05 : 1.0)
                    .animation(.easeInOut(duration: 0.2), value: selectedMealType)
                }
            }
        }
        .padding(20)
        .background(Color.white.opacity(0.1))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.2), lineWidth: 1)
        )
    }
}

// MARK: - Preview
struct AlcoholBeverageDetailView_Previews: PreviewProvider {
    static var previews: some View {
        AlcoholBeverageDetailView(
            beverage: sampleBeverage,
            onLog: { beverage, quantity in
                print("Logging \(quantity) × \(beverage.name)")
            },
            onDismiss: {
                print("Dismissed")
            }
        )
        .environmentObject(PreviewConstants.sampleAuthManagerUpdated)
    }
    
    static var sampleBeverage: AlcoholicBeverage {
        AlcoholicBeverage(
            id: "beer_001",
            name: "Bud Light",
            brand: "Anheuser-Busch",
            category: "beer",
            alcoholContentPercent: 4.2,
            alcoholGrams: 14.0,
            calories: 110,
            carbsGrams: 6.6,
            servingSizeML: 355,
            servingDescription: "12 oz bottle/can",
            description: "Light beer",
            popularityScore: 100,
            createdAt: "2024-01-20T10:00:00Z",
            updatedAt: "2024-01-20T10:00:00Z"
        )
    }
} 