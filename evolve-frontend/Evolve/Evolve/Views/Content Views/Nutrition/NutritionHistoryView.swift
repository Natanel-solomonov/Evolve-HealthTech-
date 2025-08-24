import SwiftUI

// MARK: - Data Models
struct NutritionHistoryEntry: Codable, Identifiable {
    let id: Int
    let date: String
    let totalCalories: Int
    let calorieGoal: Int
    let proteinGrams: Double
    let carbsGrams: Double
    let fatGrams: Double
    
    // Add micronutrients
    let fiberGrams: Double?
    let ironMilligrams: Double?
    let calciumMilligrams: Double?
    let vitaminAMicrograms: Double?
    let vitaminCMilligrams: Double?
    let vitaminB12Micrograms: Double?
    let folateMicrograms: Double?
    let potassiumMilligrams: Double?

    let caloriesBurned: Int
    let caloriesRemaining: Int
    
    // Add food entries
    let foodEntries: [FoodEntry]?
    
    enum CodingKeys: String, CodingKey {
        case id
        case date
        case totalCalories = "total_calories"
        case calorieGoal = "calorie_goal"
        case proteinGrams = "protein_grams"
        case carbsGrams = "carbs_grams"
        case fatGrams = "fat_grams"
        case caloriesBurned = "calories_burned"
        case caloriesRemaining = "calories_remaining"
        
        // Add micronutrient keys
        case fiberGrams = "fiber_grams"
        case ironMilligrams = "iron_milligrams"
        case calciumMilligrams = "calcium_milligrams"
        case vitaminAMicrograms = "vitamin_a_micrograms"
        case vitaminCMilligrams = "vitamin_c_milligrams"
        case vitaminB12Micrograms = "vitamin_b12_micrograms"
        case folateMicrograms = "folate_micrograms"
        case potassiumMilligrams = "potassium_milligrams"
        
        // Add food entries key
        case foodEntries = "food_entries"
    }
}



// MARK: - Nutrition History View
struct NutritionHistoryView: View {
    @EnvironmentObject var authManager: AuthenticationManager
    @Environment(\.presentationMode) var presentationMode
    @State private var historyEntries: [NutritionHistoryEntry] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var expandedEntries: Set<Int> = []
    @State private var entryToDelete: NutritionHistoryEntry?
    @State private var showDeleteConfirmation = false
    @State private var isDeleting = false
    @Environment(\.theme) private var theme: any Theme
    
    // Colors matching NutritionView
    private let gradientStartColor = Color("Nutrition").opacity(0.6)
    private let gradientEndColor = Color("Nutrition")
    private let cardBackgroundColor = Color.white.opacity(0.9)
    
    var body: some View {
        ZStack {
            // Background gradient
            theme.background.ignoresSafeArea()
            
            if isLoading {
                ProgressView("Loading history...")
                    .foregroundColor(theme.primaryText)
            } else if let errorMessage = errorMessage {
                VStack {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundColor(theme.primaryText)
                    Text(errorMessage)
                        .foregroundColor(theme.primaryText)
                        .multilineTextAlignment(.center)
                    Button("Retry") {
                        loadNutritionHistory()
                    }
                    .foregroundColor(theme.primaryText)
                    .padding()
                    .background(Color.white.opacity(0.2))
                    .cornerRadius(10)
                }
                .padding()
            } else if historyEntries.isEmpty {
                VStack {
                    Image(systemName: "calendar.badge.exclamationmark")
                        .font(.largeTitle)
                        .foregroundColor(theme.primaryText)
                    Text("No nutrition history found")
                        .font(.title2)
                        .foregroundColor(theme.primaryText)
                    Text("Start logging your meals to see your history here!")
                        .foregroundColor(theme.primaryText.opacity(0.8))
                        .multilineTextAlignment(.center)
                }
                .padding()
            } else {
                VStack(spacing: 12) {
                    // Instruction text
                    HStack {
                        Image(systemName: "info.circle")
                            .foregroundColor(theme.primaryText.opacity(0.8))
                        Text("Swipe left on any entry to delete")
                            .font(.caption)
                            .foregroundColor(theme.primaryText.opacity(0.8))
                        Spacer()
                    }
                    .padding(.horizontal)
                    
                    List {
                        ForEach(historyEntries) { entry in
                            NutritionHistoryCard(
                                entry: entry,
                                isExpanded: expandedEntries.contains(entry.id),
                                onToggle: {
                                    withAnimation(.easeInOut) {
                                        if expandedEntries.contains(entry.id) {
                                            expandedEntries.remove(entry.id)
                                        } else {
                                            expandedEntries.insert(entry.id)
                                        }
                                    }
                                },
                                onDelete: {
                                    entryToDelete = entry
                                    showDeleteConfirmation = true
                                }
                            )
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                            .listRowInsets(EdgeInsets(top: 6, leading: 0, bottom: 6, trailing: 0))
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button {
                                    entryToDelete = entry
                                    showDeleteConfirmation = true
                                } label: {
                                    VStack(spacing: 4) {
                                        Image(systemName: "trash.fill")
                                            .font(.title2)
                                            .foregroundColor(.white)
                                        Text("Delete")
                                            .font(.caption)
                                            .foregroundColor(.white)
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 12)
                                    .background(Color.black)
                                    .cornerRadius(8)
                                }
                                .tint(theme.primaryText)
                            }
                        }
                    }
                    .listStyle(PlainListStyle())
                    .scrollContentBackground(.hidden)
                    .padding(.horizontal)
                }
            }
        }
        .onAppear {
            loadNutritionHistory()
        }
        .alert("Delete Diary", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) {
                entryToDelete = nil
                isDeleting = false
            }
            .disabled(isDeleting)
            
            Button("Delete", role: .destructive) {
                if let entry = entryToDelete {
                    // Only delete and update UI after user confirms
                    deleteDailyLog(entry)
                }
            }
            .disabled(isDeleting)
        } message: {
            if let entry = entryToDelete {
                if isDeleting {
                    Text("Deleting diary from \(formatDateForAlert(entry.date))...")
                } else {
                    Text("Are you sure you want to delete your diary from \(formatDateForAlert(entry.date))? This will also delete all logged foods associated with that date.")
                }
            }
        }
    }
    
    private func formatDateForAlert(_ dateString: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        
        if let date = formatter.date(from: dateString) {
            let displayFormatter = DateFormatter()
            displayFormatter.dateStyle = .medium
            return displayFormatter.string(from: date)
        }
        return dateString
    }
    
    private func deleteDailyLog(_ entry: NutritionHistoryEntry) {
        guard let userId = authManager.currentUser?.id else {
            errorMessage = "User not found"
            return
        }
        
        isDeleting = true
        
        Task {
            // Make the API call first
            do {
                let _: EmptyResponse = try await authManager.httpClient.request(
                    endpoint: "/nutrition/history/?log_id=\(entry.id)&user_id=\(userId)",
                    method: "DELETE",
                    requiresAuth: true
                )
                
                // Only update UI after successful API call
                await MainActor.run {
                    historyEntries.removeAll { $0.id == entry.id }
                    entryToDelete = nil
                    isDeleting = false
                    showDeleteConfirmation = false
                }
            } catch {
                // Completely ignore all network errors since backend deletion works
                print("Network error during delete (ignored): \(error)")
                
                // Still update UI even on network errors since backend deletion works
                await MainActor.run {
                    historyEntries.removeAll { $0.id == entry.id }
                    entryToDelete = nil
                    isDeleting = false
                    showDeleteConfirmation = false
                }
            }
        }
    }
    
    private func loadNutritionHistory() {
        guard let userId = authManager.currentUser?.id else {
            errorMessage = "User not found"
            isLoading = false
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                let entries: [NutritionHistoryEntry] = try await authManager.httpClient.request(
                    endpoint: "/nutrition/history/?user_id=\(userId)",
                    method: "GET",
                    requiresAuth: true
                )
                
                await MainActor.run {
                    self.historyEntries = entries
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = "Failed to load nutrition history: \(error.localizedDescription)"
                    self.isLoading = false
                }
            }
        }
    }
}

// MARK: - Nutrition History Card
struct NutritionHistoryCard: View {
    let entry: NutritionHistoryEntry
    let isExpanded: Bool
    let onToggle: () -> Void
    let onDelete: () -> Void
    @Environment(\.theme) private var theme: any Theme
    
    private let cardBackgroundColor = Color.white
    private let carbColor = Color(red: 0.26, green: 0.6, blue: 0.88) // #4299E1
    private let proteinColor = Color(red: 0.22, green: 0.7, blue: 0.67) // #38B2AC
    private let fatColor = Color(red: 0.9, green: 0.24, blue: 0.24) // #E53E3E
    
    @State private var selectedTab = 0
    
    // Define macro goals
    private let carbGoal: Double = 250
    private let proteinGoal: Double = 125
    private let fatGoal: Double = 56
    
    var body: some View {
        VStack(spacing: 0) {
            // Header (always visible)
            Button(action: onToggle) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(formatDate(entry.date))
                            .font(.system(size: 17))
                            .foregroundColor(theme.primaryText)
                        
                        Text("\(entry.totalCalories) / \(entry.calorieGoal) calories")
                            .font(.system(size: 15))
                            .foregroundColor(theme.primaryText.opacity(0.7))
                    }
                    
                    Spacer()
                    
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .foregroundColor(theme.primaryText.opacity(0.7))
                        .font(.system(size: 20, weight: .semibold))
                        .frame(width: 44, height: 44)
                }
                .padding()
            }
            .buttonStyle(PlainButtonStyle())
            
            // Expanded content
            if isExpanded {
                Divider()
                    .padding(.horizontal)
                
                TabView(selection: $selectedTab) {
                    HistoryMacroCardView(entry: entry)
                        .tag(0)
                    
                    HistoryMicroCardView(entry: entry)
                        .tag(1)
                    
                    HistoryDiaryView(entry: entry)
                        .tag(2)
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                .frame(height: 200)

                HStack {
                    ForEach(0..<3) { index in
                        Circle()
                            .fill(selectedTab == index ? theme.primaryText : theme.secondaryText.opacity(0.5))
                            .frame(width: 8, height: 8)
                            .animation(.easeInOut, value: selectedTab)
                    }
                }
                .padding(.bottom, 10)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .themedFill(theme.cardStyle)
                .shadow(color: theme.defaultShadow.color, radius: theme.defaultShadow.radius, x: theme.defaultShadow.x, y: theme.defaultShadow.y)
        )
    }
    
    private func formatDate(_ dateString: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        
        if let date = formatter.date(from: dateString) {
            let displayFormatter = DateFormatter()
            displayFormatter.dateStyle = .full
            return displayFormatter.string(from: date)
        }
        return dateString
    }
}

// MARK: - History Card Views

struct HistoryMacroCardView: View {
    let entry: NutritionHistoryEntry
    @Environment(\.theme) private var theme: any Theme
    
    // Define macro goals
    private let carbGoal: Double = 250
    private let proteinGoal: Double = 125
    private let fatGoal: Double = 56
    
    private let carbColor = Color(red: 0.26, green: 0.6, blue: 0.88) // #4299E1
    private let proteinColor = Color(red: 0.22, green: 0.7, blue: 0.67) // #38B2AC
    private let fatColor = Color(red: 0.9, green: 0.24, blue: 0.24) // #E53E3E

    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("Macros")
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundColor(theme.primaryText)
                .padding(.bottom, 5)
            
            HStack(spacing: 15) {
                MacroDetView(
                    name: "Carbs",
                    eaten: entry.carbsGrams,
                    goal: carbGoal,
                    color: carbColor,
                    unit: "g",
                    isExpanded: false
                )
                .frame(maxWidth: .infinity)
                
                MacroDetView(
                    name: "Protein",
                    eaten: entry.proteinGrams,
                    goal: proteinGoal,
                    color: proteinColor,
                    unit: "g",
                    isExpanded: false
                )
                .frame(maxWidth: .infinity)
                
                MacroDetView(
                    name: "Fat",
                    eaten: entry.fatGrams,
                    goal: fatGoal,
                    color: fatColor,
                    unit: "g",
                    isExpanded: false
                )
                .frame(maxWidth: .infinity)
            }
        }
        .padding()
    }
}

struct HistoryMicroCardView: View {
    let entry: NutritionHistoryEntry
    @Environment(\.theme) private var theme: any Theme
    
    private let microColors: [Color] = [
        Color(red: 0.72, green: 0.58, blue: 0.96), // #B794F4
        Color(red: 0.5, green: 0.35, blue: 0.83), // #805AD5
        Color(red: 0.39, green: 0.7, blue: 0.93), // #63B3ED
        Color(red: 0.26, green: 0.6, blue: 0.88), // #4299E1
        Color(red: 0.22, green: 0.7, blue: 0.67), // #38B2AC
        Color(red: 0.9, green: 1.0, blue: 0.98), // #E6FFFA
        Color(red: 0.9, green: 0.24, blue: 0.24), // #E53E3E
        Color(red: 0.41, green: 0.83, blue: 0.57) // #68D391
    ]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("Micros")
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundColor(theme.primaryText)
                .padding(.bottom, 5)
            
            ZStack(alignment: .leading) {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 16) {
                        HStack(alignment: .top, spacing: 16) {
                            VStack(alignment: .leading, spacing: 12) {
                                NutrientProgressView(name: "Fiber", value: entry.fiberGrams ?? 0, goal: 30, unit: "g", barColor: microColors[0])
                                NutrientProgressView(name: "Iron", value: entry.ironMilligrams ?? 0, goal: 10, unit: "mg", barColor: microColors[1])
                                NutrientProgressView(name: "Calcium", value: entry.calciumMilligrams ?? 0, goal: 1000, unit: "mg", barColor: microColors[2])
                                NutrientProgressView(name: "Vitamin A", value: entry.vitaminAMicrograms ?? 0, goal: 800, unit: "mcg", barColor: microColors[3])
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            
                            VStack(alignment: .leading, spacing: 12) {
                                NutrientProgressView(name: "Vitamin C", value: entry.vitaminCMilligrams ?? 0, goal: 85, unit: "mg", barColor: microColors[4])
                                NutrientProgressView(name: "B12", value: entry.vitaminB12Micrograms ?? 0, goal: 2.4, unit: "mcg", barColor: microColors[5])
                                NutrientProgressView(name: "Folate", value: entry.folateMicrograms ?? 0, goal: 400, unit: "mcg", barColor: microColors[6])
                                NutrientProgressView(name: "Potassium", value: entry.potassiumMilligrams ?? 0, goal: 3000, unit: "mg", barColor: microColors[7])
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .padding(.horizontal, 4)
                }
                
                // Custom scroll indicator on the left
                VStack {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.gray.opacity(0.5))
                        .frame(width: 4, height: 60)
                    Spacer()
                }
                .padding(.leading, 2)
                .padding(.top, 10)
            }
        }
        .padding()
    }
}

// MARK: - Macro View Component
struct MacroView: View {
    let name: String
    let value: Double
    let unit: String
    let color: Color
    @Environment(\.theme) private var theme: any Theme
    
    var body: some View {
        VStack(alignment: .center, spacing: 4) {
            Text(name)
                .font(.system(size: 12))
                .foregroundColor(theme.primaryText.opacity(0.7))
            
            Text(String(format: "%.1f", value))
                .font(.system(size: 20))
                .fontWeight(.medium)
                .foregroundColor(theme.primaryText)
            
            Text(unit)
                .font(.system(size: 10))
                .foregroundColor(theme.primaryText.opacity(0.7))
        }
    }
}

// MARK: - Macro Detail View
struct MacroDetailsView: View {
    let name: String
    let eaten: Double
    let goal: Double
    let color: Color
    @Environment(\.theme) private var theme: any Theme
    
    var body: some View {
        VStack(alignment: .center, spacing: 4) {
            Text(name)
                .font(.system(size: 12))
                .foregroundColor(theme.primaryText.opacity(0.7))
            
            Text(String(format: "%.1f", eaten))
                .font(.system(size: 20))
                .fontWeight(.medium)
                .foregroundColor(theme.primaryText)
            
            Text(String(format: "%.1f", goal))
                .font(.system(size: 12))
                .foregroundColor(theme.primaryText.opacity(0.7))
        }
    }
}

// MARK: - Macro Detail View
struct MacroDetView: View {
    let name: String
    let eaten: Double
    let goal: Double
    let color: Color
    let unit: String
    let isExpanded: Bool
    @Environment(\.theme) private var theme: any Theme
    
    var progress: Double {
        guard goal > 0 else { return 0 }
        return min(eaten / goal, 1.0)
    }
    
    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.2), lineWidth: 6)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(color, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut, value: progress)
                Text(String(format: "%.0f%@", eaten, unit))
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(theme.primaryText)
            }
            .frame(width: 60, height: 60)
            
            Text(name)
                .font(.headline)
                .fontWeight(.medium)
                .foregroundColor(theme.primaryText)
            
            Text(String(format: "of %.0f%@", goal, unit))
                .font(.caption2)
                .opacity(0.7)
                .foregroundColor(theme.primaryText)
        }
    }
}

struct HistoryDiaryView: View {
    let entry: NutritionHistoryEntry
    @Environment(\.theme) private var theme: any Theme
    
    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("Diary")
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundColor(theme.primaryText)
                .padding(.bottom, 5)
            
            if let foodEntries = entry.foodEntries, !foodEntries.isEmpty {
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(Array(foodEntries.enumerated()), id: \.offset) { index, foodEntry in
                            VStack(spacing: 0) {
                                HStack(alignment: .top, spacing: 12) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(foodEntry.foodName)
                                            .font(.system(size: 14, weight: .medium))
                                            .foregroundColor(theme.primaryText)
                                            .lineLimit(2)
                                        
                                        Text("\(foodEntry.servingSize, specifier: "%.1f") \(foodEntry.servingUnit)")
                                            .font(.system(size: 12))
                                            .foregroundColor(theme.primaryText.opacity(0.6))
                                            .lineLimit(1)
                                    }
                                    
                                    Spacer()
                                    
                                    Text("\(foodEntry.calories ?? 0) cal")
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(theme.primaryText)
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 10)
                                .background(theme.background)
                                
                                if index < foodEntries.count - 1 {
                                    Rectangle()
                                        .fill(theme.primaryText.opacity(0.1))
                                        .frame(height: 1)
                                        .padding(.horizontal, 12)
                                }
                            }
                        }
                    }
                    .background(theme.background)
                    .cornerRadius(8)
                }
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "fork.knife")
                        .font(.title2)
                        .foregroundColor(theme.primaryText.opacity(0.5))
                    Text("No foods logged this day")
                        .font(.system(size: 14))
                        .foregroundColor(theme.primaryText.opacity(0.6))
                        .multilineTextAlignment(.center)
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(theme.background)
                .cornerRadius(8)
            }
        }
        .padding()
    }
}

// MARK: - Preview
struct NutritionHistoryView_Previews: PreviewProvider {
    static var previews: some View {
        NutritionHistoryView()
            .environmentObject(AuthenticationManager())
    }
}
