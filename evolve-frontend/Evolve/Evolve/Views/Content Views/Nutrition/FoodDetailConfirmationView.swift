import SwiftUI

struct FoodDetailConfirmationView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var authManager: AuthenticationManager

    let food: FoodProduct
    @State private var selectedMealType: String
    @State private var selectedServingUnit: String = "serving" // Default to 1 full serving
    let date: Date
    var onLogSuccess: (Double, Double, Double, Double, Double, Double, Double, Double, Double, Double, Double, Double) -> Void
    var onNavigateToMain: (() -> Void)? = nil // Optional callback to navigate to main view

    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showSuccess = false
    @State private var servingsInput: String = "1" // Default to 1 serving

    init(
        food: FoodProduct,
        date: Date,
        onLogSuccess: @escaping (Double, Double, Double, Double, Double, Double, Double, Double, Double, Double, Double, Double) -> Void,
        onNavigateToMain: (() -> Void)? = nil
    ) {
        self.food = food
        self.date = date
        self.onLogSuccess = onLogSuccess
        self.onNavigateToMain = onNavigateToMain
        self._selectedMealType = State(initialValue: "Breakfast")
    }

    private var numberOfServings: Double { Double(servingsInput) ?? 1.0 }
    
    // Available serving units
    private let servingUnits = ["g", "oz", "serving", "cup", "tbsp", "tsp"]
    
    // Conversion factors for different units
    private var conversionFactor: Double {
        switch selectedServingUnit {
        case "g":
            return 1.0
        case "oz":
            return 28.35 // 1 oz = 28.35g
        case "serving":
            return food.nutriments["serving_size_g"]?.doubleValue ?? 100.0
        case "cup":
            return 236.59 // 1 cup = 236.59g (approximate for most foods)
        case "tbsp":
            return 14.79 // 1 tbsp = 14.79g
        case "tsp":
            return 4.93 // 1 tsp = 4.93g
        default:
            return 1.0
        }
    }
    
    // Convert user input to grams
    private var servingSizeInGrams: Double {
        return numberOfServings * conversionFactor
    }
    
    // Calculate nutrition based on the nutrition basis (per serving vs per 100g)
    private var nutritionMultiplier: Double {
        if food.nutritionBasis == "per_serving" {
            // If data is per serving, we need to calculate how many servings the user input represents
            let baseServingSize = food.nutriments["serving_size_g"]?.doubleValue ?? 100.0
            return servingSizeInGrams / baseServingSize
        } else {
            // If data is per 100g, convert to the user's serving size
            return servingSizeInGrams / 100.0
        }
    }
    
    // --- Calculated Properties with proper conversions ---
    private var calories: Double { food.calories * nutritionMultiplier }
    private var protein: Double { food.protein * nutritionMultiplier }
    private var carbs: Double { food.carbs * nutritionMultiplier }
    private var fat: Double { food.fat * nutritionMultiplier }
    
    // Micronutrients
    private var calcium: Double { food.calcium * nutritionMultiplier }
    private var iron: Double { food.iron * nutritionMultiplier }
    private var potassium: Double { food.potassium * nutritionMultiplier }
    private var vitaminA: Double { food.vitamin_a * nutritionMultiplier }
    private var vitaminC: Double { food.vitamin_c * nutritionMultiplier }
    private var vitaminB12: Double { food.vitamin_b12 * nutritionMultiplier }
    private var fiber: Double { food.fiber * nutritionMultiplier }
    private var folate: Double { food.folate * nutritionMultiplier }
    
    // Colors to match NutritionView
    private var gradientStartColor: Color { Color("Nutrition").opacity(0.6) }
    private var gradientEndColor: Color { Color("Nutrition") }
    private var accentColor: Color { Color.blue }

    var body: some View {
        NavigationView {
            ZStack {
                LinearGradient(
                    gradient: Gradient(colors: [gradientStartColor, gradientEndColor]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .edgesIgnoringSafeArea(.all)

                ScrollView {
                    VStack(spacing: 25) {
                        // 1. Food Name and Brand Label Box
                        VStack(alignment: .leading, spacing: 12) {
                            Text(food.productName ?? "Unnamed Product")
                                .font(.system(size: 22))
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                            if let brands = food.brands {
                                Text("Brand: \(brands)")
                                    .font(.system(size: 15))
                                    .foregroundColor(.white.opacity(0.8))
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(15)
                        .padding(.horizontal)

                        // 2. Nutrition Information Box
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Nutrition Information")
                                .font(.title3)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                            
                            // Safe nutrition badges with proper NaN/infinity handling
                            HStack(spacing: 12) {
                                NutritionBadge(
                                    value: safeNutritionValue(food.calories), 
                                    unit: "kcal", 
                                    color: .vibrantPurple, 
                                    label: "Calories"
                                )
                                NutritionBadge(
                                    value: safeNutritionValue(food.protein), 
                                    unit: "g", 
                                    color: .vibrantTeal, 
                                    label: "Protein"
                                )
                                NutritionBadge(
                                    value: safeNutritionValue(food.carbs), 
                                    unit: "g", 
                                    color: .vibrantBlue, 
                                    label: "Carbs"
                                )
                                NutritionBadge(
                                    value: safeNutritionValue(food.fat), 
                                    unit: "g", 
                                    color: .vibrantPink, 
                                    label: "Fat"
                                )
                                Spacer()
                            }
                            
                            // Show nutrition basis label
                            Text(food.nutritionBasis == "per_serving" ? "per serving" : "per 100g")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.8))
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(15)
                        .padding(.horizontal)

                        // 3. Total Nutrition Display (moved from bottom)
                        VStack(spacing: 16) {
                            Text("Total Nutrition for \(String(format: "%.1f", numberOfServings)) \(selectedServingUnit)")
                                .font(.headline)
                                .foregroundColor(.white)
                                .padding(.horizontal)
                            
                            VStack(spacing: 8) {
                                HStack {
                                    Text("Calories:")
                                        .foregroundColor(.white)
                                    Spacer()
                                    Text("\(String(format: "%.0f", calories)) kcal")
                                        .foregroundColor(.white)
                                        .fontWeight(.medium)
                                }
                                
                                HStack {
                                    Text("Protein:")
                                        .foregroundColor(.white)
                                    Spacer()
                                    Text("\(String(format: "%.1f", protein)) g")
                                        .foregroundColor(.white)
                                        .fontWeight(.medium)
                                }
                                
                                HStack {
                                    Text("Carbs:")
                                        .foregroundColor(.white)
                                    Spacer()
                                    Text("\(String(format: "%.1f", carbs)) g")
                                        .foregroundColor(.white)
                                        .fontWeight(.medium)
                                }
                                
                                HStack {
                                    Text("Fat:")
                                        .foregroundColor(.white)
                                    Spacer()
                                    Text("\(String(format: "%.1f", fat)) g")
                                        .foregroundColor(.white)
                                        .fontWeight(.medium)
                                }
                            }
                            .padding()
                            .background(Color.white.opacity(0.1))
                            .cornerRadius(15)
                            .padding(.horizontal)
                        }

                        // 3. Micros Box
                        VStack(alignment: .leading, spacing: 15) {
                            Text("Micronutrients")
                                .font(.title3)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                            
                            HStack(spacing: 20) {
                                VStack(alignment: .leading, spacing: 10) {
                                    NutrientDetailBar(name: "Iron", value: iron, goal: 10, unit: "mg")
                                    NutrientDetailBar(name: "Calcium", value: calcium, goal: 1000, unit: "mg")
                                    NutrientDetailBar(name: "Vitamin A", value: vitaminA, goal: 800, unit: "mcg")
                                    NutrientDetailBar(name: "Fiber", value: fiber, goal: 30, unit: "g")
                                }
                                VStack(alignment: .leading, spacing: 10) {
                                    NutrientDetailBar(name: "Vitamin C", value: vitaminC, goal: 85, unit: "mg")
                                    NutrientDetailBar(name: "B12", value: vitaminB12, goal: 2.4, unit: "mcg")
                                    NutrientDetailBar(name: "Potassium", value: potassium, goal: 3000, unit: "mg")
                                    NutrientDetailBar(name: "Folate", value: folate, goal: 400, unit: "mcg")
                                }
                            }
                        }
                        .padding()
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(15)
                        .padding(.horizontal)

                        // 5. Meal Category Selection (1x4 grid)
                        VStack(alignment: .leading, spacing: 15) {
                            Text("Meal Category")
                                .font(.title3)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                            
                            HStack(spacing: 12) {
                                MealCategoryButton(
                                    title: "Breakfast",
                                    iconName: "sun.max.fill",
                                    isSelected: selectedMealType == "Breakfast"
                                ) {
                                    selectedMealType = "Breakfast"
                                }
                                
                                MealCategoryButton(
                                    title: "Lunch",
                                    iconName: "cloud.sun.fill",
                                    isSelected: selectedMealType == "Lunch"
                                ) {
                                    selectedMealType = "Lunch"
                                }
                                
                                MealCategoryButton(
                                    title: "Dinner",
                                    iconName: "moon.stars.fill",
                                    isSelected: selectedMealType == "Dinner"
                                ) {
                                    selectedMealType = "Dinner"
                                }
                                
                                MealCategoryButton(
                                    title: "Snack",
                                    iconName: "fork.knife",
                                    isSelected: selectedMealType == "Snack"
                                ) {
                                    selectedMealType = "Snack"
                                }
                            }
                        }
                        .padding()
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(15)
                        .padding(.horizontal)

                        // 6. Serving Size Input and Unit Dropdown
                        VStack(alignment: .leading, spacing: 15) {
                            Text("Serving Size")
                                .font(.title3)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                            
                            HStack(spacing: 12) {
                                TextField("Amount", text: $servingsInput)
                                    .keyboardType(.decimalPad)
                                    .multilineTextAlignment(.center)
                                    .foregroundColor(.black)
                                    .frame(width: 80)
                                    .padding(8)
                                    .background(Color.white)
                                    .cornerRadius(8)
                                
                                Menu {
                                    ForEach(servingUnits, id: \.self) { unit in
                                        Button(unit) {
                                            selectedServingUnit = unit
                                        }
                                    }
                                } label: {
                                    HStack {
                                        Text(selectedServingUnit)
                                            .foregroundColor(.black)
                                        Image(systemName: "chevron.down")
                                            .foregroundColor(.black)
                                    }
                                    .padding(8)
                                    .background(Color.white)
                                    .cornerRadius(8)
                                }
                                
                                Spacer()
                            }
                        }
                        .padding()
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(15)
                        .padding(.horizontal)



                        if let errorMessage = errorMessage {
                            Text(errorMessage)
                                .foregroundColor(.red)
                                .font(.caption)
                                .padding()
                        }

                        // Log Button
                        Button(action: logFood) {
                            HStack {
                                if isLoading {
                                    ProgressView()
                                        .tint(.white)
                                } else {
                                    Text("Add to \(selectedMealType)")
                                        .fontWeight(.semibold)
                                }
                            }
                            .font(.system(size: 17))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.black)
                            .cornerRadius(10)
                        }
                        .disabled(isLoading || numberOfServings <= 0)
                        .padding(.horizontal)
                        .padding(.top, 20)
                    }
                    .padding(.vertical)
                }

                // Success Animation Overlay
                if showSuccess {
                    Color.black.opacity(0.4)
                        .ignoresSafeArea()
                        .blur(radius: 20)
                        .transition(.opacity)

                    VStack(spacing: 20) {
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.white)
                                .font(.system(size: 36))
                                .transition(.scale)

                            Text("Tracked")
                                .foregroundColor(.white)
                                .font(.system(size: 28))
                                .bold()
                                .transition(.opacity)
                        }
                    }
                    .scaleEffect(showSuccess ? 1 : 0.5)
                    .opacity(showSuccess ? 1 : 0)
                    .animation(.spring(response: 0.4, dampingFraction: 0.6), value: showSuccess)
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                            dismiss()
                            // Navigate back to main view after tracking
                            onNavigateToMain?()
                        }
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(.white)
                        .font(.system(size: 17))
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private func logFood() {
        guard let userPhone = authManager.currentUser?.phone else {
            self.errorMessage = "User not logged in. Please log in to save your food."
            return
        }
        guard numberOfServings > 0 else {
            errorMessage = "Please enter a valid number of servings."
            return
        }
        Task { await performLogApiCall(userPhone: userPhone) }
    }

    private func performLogApiCall(userPhone: String) async {
        isLoading = true
        errorMessage = nil

        // Use the calculated serving size in grams
        let totalGramsToLog = servingSizeInGrams

        // Create comprehensive entry data with nutritional information
        let entryData = CreateFoodEntryRequest(
            userPhone: userPhone,
            foodProductId: food.id,
            foodName: food.productName ?? "Unknown Food",
            servingSize: totalGramsToLog, // Log total grams
            servingUnit: "g",
            calories: Int(calories.rounded()),
            protein: protein,
            carbs: carbs,
            fat: fat,
            fiberGrams: fiber,
            ironMilligrams: iron,
            calciumMilligrams: calcium,
            vitaminAMicrograms: vitaminA,
            vitaminCMilligrams: vitaminC,
            vitaminB12Micrograms: vitaminB12,
            folateMicrograms: folate,
            potassiumMilligrams: potassium,
            mealType: selectedMealType.lowercased(), // Use selected meal type
            timeConsumed: ISO8601DateFormatter().string(from: Date())
        )

        let foodSearchAPI = FoodSearchAPI(httpClient: authManager.httpClient)

        foodSearchAPI.createFoodEntry(
            entryData: entryData,
            completion: { result in
                Task { @MainActor in
                    isLoading = false
                    
                    switch result {
                    case .success(_):
                        withAnimation(.easeInOut(duration: 0.4)) {
                            showSuccess = true
                        }
                        
                        // Call the success callback with final calculated nutrients
                        onLogSuccess(
                            calories, protein, carbs, fat,
                            iron, calcium, vitaminA, vitaminC, vitaminB12, potassium,
                            fiber, folate
                        )
                        
                    case .failure(let error):
                        print("--- logFood() API Failure: \(error) ---")
                        switch error {
                        case .unauthorized, .sessionExpired:
                            errorMessage = "Authentication failed or session expired. Please log in again."
                        case .serverError(let statusCode, _):
                            errorMessage = "Failed to log food (Server Error: \(statusCode)). Please try again."
                        default:
                            errorMessage = "Failed to log food (\(error.localizedDescription)). Please try again."
                        }
                        print("--- logFood() Set errorMessage: \(errorMessage ?? "nil") ---")
                    }
                }
            }
        )
    }

    /// Safely converts nutrition values to prevent NaN/infinity from reaching CoreGraphics
    private func safeNutritionValue(_ value: Double) -> Int {
        // Handle NaN, infinity, and negative values
        guard value.isFinite && !value.isNaN && value >= 0 else {
            return 0
        }
        // Cap extremely large values to prevent UI issues
        let cappedValue = min(value, 99999)
        return Int(cappedValue.rounded())
    }
}

// MARK: - Meal Category Button
struct MealCategoryButton: View {
    let title: String
    let iconName: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: iconName)
                    .font(.system(size: 14, weight: .medium))
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .foregroundColor(isSelected ? .white : .black)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(isSelected ? Color.black : Color.white)
            .cornerRadius(10)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct NutrientDetailBar: View {
    let name: String
    let value: Double
    let goal: Double
    let unit: String

    private var progress: Double {
        guard goal > 0 else { return 0 }
        return min(value / goal, 1.0)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(name)
                    .font(.caption)
                    .foregroundColor(.white)
                Spacer()
                Text(String(format: "%.1f \(unit)", value))
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.8))
            }
            ProgressView(value: progress)
                .progressViewStyle(LinearProgressViewStyle(tint: .white))
                .scaleEffect(x: 1, y: 0.5, anchor: .center)
        }
    }
} 
