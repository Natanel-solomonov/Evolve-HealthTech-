import SwiftUI

struct NutritionDetailView: View {
    let appUser: AppUser
    @State private var showingAddFoodSheet = false
    @State private var selectedCalorieLogId: Int? = nil
    @Environment(\.dismiss) private var dismiss

    // Helper to format dates nicely
    private func formatDate(_ dateString: String) -> String {
        let inputFormatter = ISO8601DateFormatter()
        inputFormatter.formatOptions = [.withFullDate] // Handles yyyy-MM-dd

        if let date = inputFormatter.date(from: dateString) {
            let outputFormatter = DateFormatter()
            outputFormatter.dateStyle = .medium
            outputFormatter.timeStyle = .none
            return outputFormatter.string(from: date)
        }
        return dateString // Fallback
    }

    var body: some View {
        NavigationView {
//            List {
//                if let calorieLogs = appUser.calorie_logs, !calorieLogs.isEmpty {
//                    ForEach(calorieLogs) { log in
//                        Section(header: 
//                            HStack {
//                                Text("Log for \(formatDate(log.date))")
//                                Spacer()
//                                Button(action: {
//                                    selectedCalorieLogId = log.id
//                                    showingAddFoodSheet = true
//                                }) {
//                                    Image(systemName: "plus.circle")
//                                        .foregroundColor(.blue)
//                                }
//                            }
//                        ) {
//                            VStack(alignment: .leading, spacing: 8) {
//                                Text("Calories: \(log.total_calories) / \(log.calorie_goal) kcal")
//                                    .font(.headline)
//                                HStack {
//                                    Text("Protein: \(log.protein_grams, specifier: "%.1f")g")
//                                    Spacer()
//                                    Text("Carbs: \(log.carbs_grams, specifier: "%.1f")g")
//                                    Spacer()
//                                    Text("Fat: \(log.fat_grams, specifier: "%.1f")g")
//                                }
//                                .font(.subheadline)
//                                .foregroundColor(.gray)
//
//                                Divider().padding(.vertical, 4)
//
//                                Text("Food Entries:")
//                                    .font(.headline)
//                                
//                                if !log.food_entries.isEmpty {
//                                    ForEach(log.food_entries) { entry in
//                                        FoodEntryRow(entry: entry)
//                                    }
//                                } else {
//                                    Text("No food entries for this day.")
//                                        .italic()
//                                        .foregroundColor(.gray)
//                                }
//                            }
//                            .padding(.vertical, 5)
//                        }
//                    }
//                } else {
//                    Text("No calorie logs available for \(appUser.name).")
//                        .italic()
//                        .foregroundColor(.gray)
//                }
//            }
//            .navigationTitle("Nutrition Details")
//            .listStyle(GroupedListStyle())
//            .toolbar {
//                ToolbarItem(placement: .navigationBarLeading) {
//                    Button("Close") {
//                        dismiss()
//                    }
//                }
////                ToolbarItem(placement: .navigationBarTrailing) {
////                    Button(action: {
////                        // If there's at least one log, select the first one by default
////                        if let firstLogId = appUser.calorie_logs?.first?.id {
////                            selectedCalorieLogId = firstLogId
////                            showingAddFoodSheet = true
////                        } else {
////                            // Handle the case where there's no logs - maybe show an alert or create a new log
////                            print("No calorie logs available")
////                        }
////                    }) {
////                        Image(systemName: "plus")
////                    }
////                }
//            }
//            .sheet(isPresented: $showingAddFoodSheet) {
//                AddFoodView(calorieLogId: selectedCalorieLogId ?? 0)
//            }
        }
    }
}

// Subview for displaying a single food entry
struct FoodEntryRows: View {
    let entry: FoodEntry
  
    var body: some View {
        VStack(alignment: .leading) {
            Text(entry.foodName)
                .bold()
            Text("Serving: \(entry.servingSize, specifier: "%.1f")\(entry.servingUnit)")
            HStack {
                Text("Calories: \(entry.calories ?? 0)")
                Spacer()
                Text("P: \(entry.protein ?? 0.0, specifier: "%.1f")g")
                Spacer()
                Text("C: \(entry.carbs ?? 0.0, specifier: "%.1f")g")
                Spacer()
                Text("F: \(entry.fat ?? 0.0, specifier: "%.1f")g")
            }
            .font(.caption)
            .foregroundColor(.secondary)
            Text("Meal: \(entry.mealType.capitalized)")
                 .font(.caption)
                 .foregroundColor(.secondary)
            
            // Optional: Display product details if available
//            if let product = entry.food_product {
//                Text("Brand: \(product.brands ?? "N/A")")
//                    .font(.caption2)
//                    .foregroundColor(.gray)
//            }
        }
        .padding(.vertical, 4)
    }
}

// New AddFoodView for searching and adding food
struct AddFoodView: View {
    let calorieLogId: Int
    @State private var searchQuery = ""
    @State private var searchResults: [FoodProduct] = []
    @State private var isSearching = false
    @State private var selectedFood: FoodProduct? = nil
    @State private var showingFoodDetailForm = false
    @Environment(\.presentationMode) var presentationMode
    
    // Fetch food data from backend API
    private func searchFoods() {
        isSearching = true
        
        // Create URL with search parameter if query is not empty
        var urlComponents = URLComponents(string: AppConfig.apiBaseURL + "/food-products/")
        

        
        if !searchQuery.isEmpty {
            urlComponents?.queryItems = [
                URLQueryItem(name: "search", value: searchQuery)
            ]
        }
        
        guard let url = urlComponents?.url else {
            isSearching = false
            return
        }
        
        URLSession.shared.dataTask(with: url) { data, response, error in
            defer { 
                DispatchQueue.main.async {
                    isSearching = false
                }
            }
            
            if let error = error {
                print("Error fetching food products: \(error)")
                return
            }
            
            guard let data = data else {
                print("No data received")
                return
            }
            
            do {
                let decoder = JSONDecoder()
                let foodProducts = try decoder.decode([FoodProduct].self, from: data)
                
                DispatchQueue.main.async {
                    self.searchResults = foodProducts
                }
            } catch {
                print("Error decoding food products: \(error)")
            }
        }.resume()
    }
    
    var body: some View {
        NavigationView {
            VStack {
                // Search Bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.gray)
                    
                    TextField("Search for food...", text: $searchQuery)
                        .onChange(of: searchQuery) { oldValue, newValue in
                            searchFoods()
                        }
                    
                    if !searchQuery.isEmpty {
                        Button(action: {
                            searchQuery = ""
                            searchResults = []
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.gray)
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(Color(.systemGray6))
                .cornerRadius(10)
                .padding()
                
                if isSearching {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                        .padding()
                } else {
                    List {
                        // Use the new SearchResultRow view
                        ForEach(searchResults) { food in
                            Button(action: {
                                // Check for mapping before showing detail form
                                if let mappingResult = ProductMappingService.shared.mapFoodProduct(food) {
                                    switch mappingResult {
                                    case .alcohol(let alcoholBeverage):
                                        print("Fuzzy mapped search result '\(food.productName ?? "")' to alcohol product '\(alcoholBeverage.name)'")
                                        // Navigate to alcohol detail view (we'll need to add this navigation)
                                        selectedFood = food // For now, still show detail form
                                        showingFoodDetailForm = true
                                    case .caffeine(let caffeineProduct):
                                        print("Fuzzy mapped search result '\(food.productName ?? "")' to caffeine product '\(caffeineProduct.name)'")
                                        // Navigate to caffeine detail view (we'll need to add this navigation)
                                        selectedFood = food // For now, still show detail form
                                        showingFoodDetailForm = true
                                    }
                                } else {
                                    selectedFood = food
                                    showingFoodDetailForm = true
                                }
                            }) {
                                SearchResultRow(food: food)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                }
            }
            .navigationTitle("Add Food")
            .navigationBarItems(trailing: Button("Cancel") {
                presentationMode.wrappedValue.dismiss()
            })
            .sheet(isPresented: $showingFoodDetailForm) {
                if let food = selectedFood {
                    FoodDetailForm(calorieLogId: calorieLogId, foodProduct: food, onSave: {
                        // On save callback
                        presentationMode.wrappedValue.dismiss()
                    })
                }
            }
            .onAppear {
                // Initial load of food products when view appears
                searchFoods()
            }
        }
    }
    
    // Helper to determine color based on nutriscore
    private func scoreColor(for score: String) -> Color {
        switch score.uppercased() {
        case "A": return Color.green
        case "B": return Color(red: 0.4, green: 0.7, blue: 0.2)
        case "C": return Color.yellow
        case "D": return Color.orange
        case "E": return Color.red
        default: return Color.gray
        }
    }
}

// Form to enter details for the selected food
struct FoodDetailForm: View {
    let calorieLogId: Int
    let foodProduct: FoodProduct
    let onSave: () -> Void
    
    @State private var servingSize: Double = 100
    @State private var mealType: String = "lunch"
    @State private var timeConsumed = Date()
    
    @Environment(\.presentationMode) var presentationMode
    
    private var caloriesPerServing: Int {
        let calories = foodProduct.caloriesPer100g
        return Int(calories * servingSize / 100)
    }
    
    private var proteinPerServing: Double {
        let protein = foodProduct.proteinPer100g
        return protein * servingSize / 100
    }
    
    private var carbsPerServing: Double {
        let carbs = foodProduct.carbsPer100g
        return carbs * servingSize / 100
    }
    
    private var fatPerServing: Double {
        let fat = foodProduct.fatPer100g
        return fat * servingSize / 100
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Food Info")) {
                    Text(foodProduct.productName ?? "Unnamed Product")
                        .font(.headline)
                    if let brands = foodProduct.brands {
                        Text("Brand: \(brands)")
                    }
                }
                
                Section(header: Text("Serving")) {
                    HStack {
                        Text("Amount")
                        Spacer()
                        TextField("Serving Size", value: $servingSize, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                        Text("g")
                    }
                }
                
                Section(header: Text("Meal Details")) {
                    Picker("Meal", selection: $mealType) {
                        Text("Breakfast").tag("breakfast")
                        Text("Lunch").tag("lunch")
                        Text("Dinner").tag("dinner")
                        Text("Snack").tag("snack")
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    
                    DatePicker("Time Consumed", selection: $timeConsumed, displayedComponents: [.date, .hourAndMinute])
                }
                
                Section(header: Text("Nutrition (Based on your serving)")) {
                    HStack {
                        Text("Calories")
                        Spacer()
                        Text("\(caloriesPerServing) kcal")
                    }
                    
                    HStack {
                        Text("Protein")
                        Spacer()
                        Text("\(proteinPerServing, specifier: "%.1f") g")
                    }
                    
                    HStack {
                        Text("Carbs")
                        Spacer()
                        Text("\(carbsPerServing, specifier: "%.1f") g")
                    }
                    
                    HStack {
                        Text("Fat")
                        Spacer()
                        Text("\(fatPerServing, specifier: "%.1f") g")
                    }
                }
                
                Section {
                    Button("Add to Log") {
                        // Here you would normally call your API to add the food entry
                        // For demo purposes, just close the sheet
                        addFoodToLog()
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    .foregroundColor(.white)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(10)
                }
            }
            .navigationTitle("Add Food Details")
            .navigationBarItems(trailing: Button("Cancel") {
                presentationMode.wrappedValue.dismiss()
            })
        }
    }
    
    private func addFoodToLog() {
        // In a real app, this would make a network request to your API
        // Example POST request to add a food entry to the user's log
        
        // Create an ISO8601 formatter for the timeConsumed
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        let timeConsumedString = formatter.string(from: timeConsumed)
        
        // TODO: Replace with actual API call using URLSession or your networking library
        print("Adding food to log \(calorieLogId): \(foodProduct.productName ?? "Unnamed Product"), \(servingSize)g, \(mealType), \(timeConsumedString)")
        
        // For now, just close the form
        presentationMode.wrappedValue.dismiss()
        onSave()
    }
}

// --- NEW HELPER VIEW FOR SEARCH RESULTS --- 
struct SearchResultRow: View {
    let food: FoodProduct

    var body: some View {
        VStack(alignment: .leading) {
            Text(food.productName ?? "Unnamed Product")
                .font(.headline)
                .foregroundColor(.primary) // Ensure text is visible
            if let brands = food.brands, !brands.isEmpty {
                Text(brands)
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }
            HStack {
                // Access nutriments directly
                Text("\(Int(food.caloriesPer100g)) kcal per 100g")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                if let score = food.nutriscoreGrade, !score.isEmpty {
                    Text("Score: \(score.uppercased())")
                        .font(.caption)
                        .padding(4)
                        .background(scoreColor(for: score)) // Use the helper function
                        .foregroundColor(.white)
                        .cornerRadius(4)
                }
            }
        }
    }

    // Helper function to determine color based on nutriscore (can be moved if used elsewhere)
    private func scoreColor(for score: String) -> Color {
        switch score.uppercased() {
        case "A": return Color.green
        case "B": return Color(red: 0.4, green: 0.7, blue: 0.2)
        case "C": return Color.yellow
        case "D": return Color.orange
        case "E": return Color.red
        default: return Color.gray
        }
    }
}

// MARK: - Preview
//
//#Preview {
//    // Create Sample Data for Preview
//    let sampleFoodProduct = FoodProduct(
//        id: "001", product_name: "Sample Beef Burger", brands: "Preview Brand",
//        nutriscore_grade: "C", categories: "Meat", product_quantity: 1, quantity: "1 burger",
//        nutrition_data_per: "100g", allergens_tags: [], food_groups_tags: [], categories_tags: [],
//        nutriments: [
//            "energy-kcal_100g": .double(250),
//            "proteins_100g": .double(20),
//            "carbohydrates_100g": .double(5),
//            "fat_100g": .double(15)
//        ]
//    )
//
//    let sampleFoodEntry1 = FoodEntry(
//        id: 1, daily_log: 1, food_product: sampleFoodProduct, food_name: "Sample Beef Burger",
//        serving_size: 113.0, serving_unit: "g", calories: 283, protein: 22.6, carbs: 5.7, fat: 16.9,
//        meal_type: "lunch", time_consumed: "2024-01-01T12:00:00Z", created_at: "2024-01-01T12:05:00Z", updated_at: "2024-01-01T12:05:00Z"
//    )
//    
//     let sampleFoodEntry2 = FoodEntry(
//         id: 2, daily_log: 1, food_product: nil, food_name: "Apple", // Example manual entry
//         serving_size: 150, serving_unit: "g", calories: 80, protein: 0.5, carbs: 22, fat: 0.3,
//         meal_type: "snack", time_consumed: "2024-01-01T15:00:00Z", created_at: "2024-01-01T15:05:00Z", updated_at: "2024-01-01T15:05:00Z"
//     )
//
//    let sampleCalorieLog1 = DailyCalorieTracker(
//        id: 1, user: "+11234567890", date: "2024-05-15", total_calories: 363, calorie_goal: 2000,
//        protein_grams: 23.1, carbs_grams: 27.7, fat_grams: 17.2, created_at: "2024-05-15T10:00:00Z", updated_at: "2024-05-15T18:00:00Z",
//        food_entries: [sampleFoodEntry1, sampleFoodEntry2]
//    )
//    
//    let sampleCalorieLog2 = DailyCalorieTracker(
//        id: 2, user: "+11234567890", date: "2024-05-14", total_calories: 1850, calorie_goal: 2000,
//        protein_grams: 100, carbs_grams: 200, fat_grams: 70, created_at: "2024-05-14T10:00:00Z", updated_at: "2024-05-14T18:00:00Z",
//        food_entries: [] // Example day with no entries
//    )
//
//
//    let sampleUser = AppUser(
//        phone: "+11234567890", name: "Sample User", otp_code: nil, otp_created_at: 0, is_phone_verified: 0, date_joined: 0, lifetime_points: nil,
//        available_points: true, lifetime_savings: "2024-01-01T00:00:00Z", info: nil,
//        current_activity_plan: nil, activity_plan_history: nil, goals: nil,
//        calorie_logs: [sampleCalorieLog1, sampleCalorieLog2], // Add sample logs
//        max_propositions: []
//    )
//
//    NutritionDetailView(appUser: sampleUser)
//}
//
//// Additional preview for the search and add functionality
//#Preview {
//    AddFoodView(calorieLogId: 1)
//}
//
//// Preview for the food detail form
//#Preview {
//    let sampleFood = FoodProduct(
//        id: "002", product_name: "Chicken Breast", brands: "Organic Farms",
//        nutriscore_grade: "A", categories: "Poultry", product_quantity: 1, quantity: "100g",
//        nutrition_data_per: "100g", allergens_tags: [], food_groups_tags: ["meat"], categories_tags: [],
//        nutriments: ["energy-kcal_100g": .double(165), "proteins_100g": .double(31), "carbohydrates_100g": .double(0), "fat_100g": .double(3.6)]
//    )
//    
//    return FoodDetailForm(calorieLogId: 1, foodProduct: sampleFood, onSave: {})
//} 
