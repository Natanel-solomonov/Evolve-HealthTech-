import SwiftUI

struct DailyFoodLogView: View {
    @EnvironmentObject var authManager: AuthenticationManager
    @Environment(\.dismiss) private var dismiss
    let currentDate: Date
    var onEntryDeleted: (FoodEntry) -> Void
    @Environment(\.theme) private var theme: any Theme

    // Updated Evolve Color Scheme to match DashboardView/NutritionView
    private var gradientStartColor: Color { Color("Nutrition").opacity(0.6) }
    private var gradientEndColor: Color { Color("Nutrition") }
    private var accentColor: Color { Color.blue } // Consistent accent blue
    // cardBackgroundColor will be applied via the white card style

    // Grouping
    private var groupedEntries: [String: [FoodEntry]] {
        Dictionary(grouping: entries, by: { $0.mealType.capitalized })
    }
    private let mealOrder = ["Breakfast", "Lunch", "Dinner", "Snacks"]

    @State private var entries: [FoodEntry] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showNutritionCardSheet = false

    var body: some View {
        ZStack {
            // Background Gradient
            theme.background.ignoresSafeArea()

            VStack(spacing: 0) { // Use a VStack to separate ScrollView from the bottom button
            ScrollView {
                if isLoading {
                    ProgressView("Loading Diary...")
                        .padding(.top, 40)
                } else if let errorMessage = errorMessage {
                    Text("Error: \(errorMessage)")
                        .foregroundColor(.red)
                        .padding(.top, 40)
                } else if entries.isEmpty {
                    Text("No food logged for this date yet.")
                        .foregroundColor(theme.primaryText.opacity(0.7))
                        .padding(.top, 40)
                } else {
                    VStack(spacing: 25) {
                        ForEach(mealOrder, id: \.self) { mealType in
                            if let items = groupedEntries[mealType], !items.isEmpty {
                                // Section Header
                                HStack {
                                    Text(mealType)
                                        .font(.system(size: 17))
                                        .fontWeight(.medium)
                                            .foregroundColor(theme.primaryText) // Section headers on gradient should be white
                                    Spacer()
                                }
                                .padding(.horizontal)

                                // Entries
                                ForEach(items) { entry in
                                    DailyFoodLogCard(
                                        entry: entry,
                                            // cardBackgroundColor removed, will use white card style
                                        accentColor: theme.accent,
                                        onDelete: {
                                            Task { await deleteEntry(entry) }
                                        }
                                    )
                                }
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 30)
                }
            }
                // Removed .padding(.bottom, 30) from ScrollView's content VStack
                // Add Spacer to push button to bottom if VStack is used for main layout outside ZStack
                // Spacer()
            }
            // Sticky Button at the bottom of the ZStack
            VStack { // VStack to allow Spacer and Button
                Spacer() // Pushes the button to the bottom of this VStack
                Button(action: {
                    showNutritionCardSheet = true
                }) {
                    Text("View My Nutrition Card")
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .padding(.vertical, 15)
                        .frame(maxWidth: .infinity)
                        .background(Color.blue.opacity(0.85))
                        .cornerRadius(10)
                        .font(.system(size: 17))
                }
                .padding(.horizontal, 20)
                .padding(.bottom, (UIApplication.shared.connectedScenes.first as? UIWindowScene)?.windows.first?.safeAreaInsets.bottom ?? 0 > 0 ? 0 : 20)
                .padding(.bottom, 10)
            }
            // .edgesIgnoringSafeArea(.bottom) // Let's remove this and rely on specific bottom padding for now

        }
        .navigationTitle("\(currentDate, style: .date) Diary")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: { dismiss() }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 22))
                        .foregroundColor(theme.primaryText)
                }
            }
        }
        .onAppear { Task { await fetchEntries() } }
        .fullScreenCover(isPresented: $showNutritionCardSheet) {
            NutritionCardView()
                .environmentObject(authManager)
        }
    }

    // MARK: - Networking
    private func fetchEntries() async {
        let userPhone = "+12159136110" // TODO: Replace with actual user's phone or remove if backend uses authenticated user from token
        isLoading = true
        errorMessage = nil

        // Create an instance of FoodSearchAPI using the authManager's httpClient
        let foodSearchAPI = FoodSearchAPI(httpClient: authManager.httpClient)
        
        // Call the instance method
        let result = await foodSearchAPI.fetchDailyLogEntries(userPhone: userPhone, date: currentDate)
        isLoading = false

        switch result {
        case .success(let fetched):
            entries = fetched
        case .failure(let error):
            errorMessage = error.localizedDescription
        }
    }

    private func deleteEntry(_ entry: FoodEntry) async {
        let entryId = entry.id

        let foodSearchAPI = FoodSearchAPI(httpClient: authManager.httpClient)
        
        foodSearchAPI.deleteFoodEntry(entryId: entryId) { result in // Use unwrapped entryId
            DispatchQueue.main.async {
                switch result {
                case .success():
                    self.onEntryDeleted(entry)
                    self.entries.removeAll { $0.id == entry.id }
                case .failure(let error):
                    self.errorMessage = "Failed to delete entry. \(error.localizedDescription)"
                }
            }
        }
    }
}

// MARK: - Entry Card
struct DailyFoodLogCard: View {
    let entry: FoodEntry
    // let cardBackgroundColor: Color // Removed, will use white card style
    let accentColor: Color
    var onDelete: () -> Void
    @Environment(\.theme) private var theme: any Theme

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 6) {
                Text(entry.foodName)
                    .font(.system(size: 15))
                    .fontWeight(.semibold)
                    .foregroundColor(theme.primaryText) // Dark text on white card
                Text("\(entry.servingSize, specifier: "%.0f")g - \(entry.calories ?? 0, specifier: "%.0f") kcal")
                    .font(.system(size: 12))
                    .foregroundColor(theme.secondaryText) // Dark secondary text
                HStack(spacing: 12) {
                    Text("P:\(entry.protein ?? 0.0, specifier: "%.1f")g")
                    Text("C:\(entry.carbs ?? 0.0, specifier: "%.1f")g")
                    Text("F:\(entry.fat ?? 0.0, specifier: "%.1f")g")
                }
                .font(.system(size: 10))
                .fontWeight(.medium)
                .foregroundColor(accentColor) // Macro details can use accent color
            }
            Spacer()
            Button(action: onDelete) {
                Image(systemName: "trash.fill")
                    .font(.system(size: 15))
                    .foregroundColor(theme.secondaryText) // Trash icon color on white card
            }
        }
        .padding()
        // .background(cardBackgroundColor) // Replaced with white card style
        .background(
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .themedFill(theme.cardStyle)
                .shadow(color: theme.defaultShadow.color, radius: theme.defaultShadow.radius, x: theme.defaultShadow.x, y: theme.defaultShadow.y)
        )
        // .cornerRadius(18) // Removed redundant, background provides cornerRadius(15)
    }
}

// MARK: - Preview
struct DailyFoodLogView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            DailyFoodLogView(currentDate: Date(), onEntryDeleted: { _ in })
                .environmentObject(PreviewConstants.sampleAuthManagerUpdated)
        }
        .preferredColorScheme(.dark)
    }
}
