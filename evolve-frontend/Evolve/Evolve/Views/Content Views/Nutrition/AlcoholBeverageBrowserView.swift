// AlcoholBeverageBrowserView.swift
import SwiftUI
import Combine

struct AlcoholBeverageBrowserView: View {
    @EnvironmentObject var authManager: AuthenticationManager
    @State private var beverages: [AlcoholicBeverage] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var searchText = ""
    @State private var selectedBeverage: AlcoholicBeverage?
    @State private var isSearching = false
    @State private var searchSubject = PassthroughSubject<String, Never>()
    @State private var cancellables = Set<AnyCancellable>()
    
    let category: AlcoholCategory
    let onBack: () -> Void
    let onBeverageLogged: () -> Void
    let onBeverageLoggedWithData: (Double, Double, Double, Double, Double, Double, Double, Double, Double, Double, Double, Double, Double, Double) -> Void
    
    // Computed property for more descriptive category names
    private var categoryDisplayName: String {
        switch category.key {
        case "beer": return "Beer & Seltzer"
        case "wine": return "Wine & Champagne"
        case "sparkling": return "Sparkling Wine"
        case "liquor": return "Liquor & Spirits"
        case "fortified": return "Fortified Wine"
        default: return category.name
        }
    }
    
    // Colors to match nutrition theme
    private var gradientStartColor: Color { Color("Nutrition").opacity(0.6) }
    private var gradientEndColor: Color { Color("Nutrition") }
    
    // Create AlcoholAPI instance
    private var alcoholAPI: AlcoholAPI {
        AlcoholAPI(httpClient: authManager.httpClient)
    }
    
    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                gradient: Gradient(colors: [gradientStartColor, gradientEndColor]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 0) {
                // Custom Header
                HStack {
                    Button(action: onBack) {
                        Image(systemName: "chevron.left")
                            .font(.title2)
                            .fontWeight(.medium)
                            .foregroundColor(.white)
                            .frame(width: 44, height: 44)
                    }
                    
                    Spacer()
                    
                    VStack(spacing: 2) {
                        Text(category.icon)
                            .font(.title2)
                        Text(categoryDisplayName)
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                    }
                    
                    Spacer()
                    
                    // Invisible spacer for balance
                    Rectangle()
                        .fill(Color.clear)
                        .frame(width: 44, height: 44)
                }
                .padding(.horizontal)
                .padding(.top, (UIApplication.shared.connectedScenes.first as? UIWindowScene)?.windows.first?.safeAreaInsets.top ?? 0)
                .padding(.bottom, 20)
                
                // Search Bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.white.opacity(0.7))
                    
                    TextField("Search \(categoryDisplayName.lowercased())...", text: $searchText)
                        .foregroundColor(.white)
                        .accentColor(.white)
                        .onChange(of: searchText) { _, newValue in
                            searchSubject.send(newValue)
                        }
                    
                    if !searchText.isEmpty {
                        Button(action: {
                            searchText = ""
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.white.opacity(0.7))
                        }
                    }
                }
                .padding()
                .background(Color.white.opacity(0.15))
                .cornerRadius(12)
                .padding(.horizontal)
                .padding(.bottom, 20)
                
                // Main Content
                if isLoading && beverages.isEmpty {
                    Spacer()
                    SpinningLoaderView()
                    Spacer()
                } else if let error = errorMessage, beverages.isEmpty {
                    Spacer()
                    ErrorStateView(message: error) {
                        loadBeverages()
                    }
                    Spacer()
                } else if beverages.isEmpty && !searchText.isEmpty {
                    Spacer()
                    NoSearchResultsView(query: searchText, category: categoryDisplayName)
                    Spacer()
                } else {
                    // Beverages List
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(beverages) { beverage in
                                AlcoholBeverageRow(
                                    beverage: beverage,
                                    onTap: {
                                        selectedBeverage = beverage
                                    }
                                )
                                .padding(.horizontal)
                            }
                            
                            if isSearching || isLoading {
                                HStack {
                                    Spacer()
                                    SpinningLoaderView()
                                    Spacer()
                                }
                                .padding()
                            }
                            
                            Spacer(minLength: 50)
                        }
                        .padding(.top, 10)
                    }
                }
            }
        }
        .onAppear {
            setupSearchDebounce()
            loadBeverages()
        }
        .sheet(item: $selectedBeverage) { beverage in
            AlcoholBeverageDetailView(
                beverage: beverage,
                onLog: { loggedBeverage, quantity in
                    logBeverage(beverage: loggedBeverage, quantity: quantity)
                },
                onDismiss: {
                    selectedBeverage = nil
                }
            )
            .environmentObject(authManager)
        }
        .navigationBarHidden(true)
    }
    
    private func setupSearchDebounce() {
        searchSubject
            .debounce(for: .milliseconds(500), scheduler: DispatchQueue.main)
            .removeDuplicates()
            .sink { query in
                performSearch(query: query)
            }
            .store(in: &cancellables)
    }
    
    private func loadBeverages() {
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                let response = try await alcoholAPI.getBeveragesByCategory(categoryKey: category.key)
                
                await MainActor.run {
                    isLoading = false
                    beverages = response.beverages
                    print("AlcoholBeverageBrowserView: Loaded \(beverages.count) beverages for \(category.name)")
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    errorMessage = "Failed to load beverages: \(error.localizedDescription)"
                    print("AlcoholBeverageBrowserView: Error loading beverages: \(error)")
                }
            }
        }
    }
    
    private func performSearch(query: String) {
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            loadBeverages()
            return
        }
        
        guard query.count >= 2 else {
            return
        }
        
        isSearching = true
        
        Task {
            do {
                let response = try await alcoholAPI.searchAlcoholicBeverages(
                    query: query,
                    category: category.key
                )
                
                await MainActor.run {
                    isSearching = false
                    beverages = response.beverages
                    print("AlcoholBeverageBrowserView: Search returned \(beverages.count) results for '\(query)'")
                }
            } catch {
                await MainActor.run {
                    isSearching = false
                    errorMessage = "Search failed: \(error.localizedDescription)"
                    print("AlcoholBeverageBrowserView: Search error: \(error)")
                }
            }
        }
    }
    
    private func logBeverage(beverage: AlcoholicBeverage, quantity: Int) {
        guard let userPhone = authManager.currentUser?.phone else {
            print("AlcoholBeverageBrowserView: No user phone available")
            return
        }
        
        Task {
            do {
                let _ = try await alcoholAPI.logAlcoholicBeverage(
                    beverage: beverage,
                    quantity: quantity,
                    mealType: "dinner", // Default meal type for alcohol
                    userPhone: userPhone
                )
                
                await MainActor.run {
                    selectedBeverage = nil
                    
                    // Calculate alcohol values for the logged beverage
                    let alcoholGrams = (beverage.alcoholContentPercent / 100.0) * 14.0 * Double(quantity) // 14g per standard drink
                    let standardDrinks = Double(quantity)
                    
                    // Call the callback with nutrition data including alcohol
                    onBeverageLoggedWithData(
                        beverage.calories,           // calories
                        0.0,                         // protein (alcohol has no protein)
                        beverage.carbsGrams,         // carbs
                        0.0,                         // fat (alcohol has no fat)
                        0.0,                         // fiber
                        0.0,                         // iron
                        0.0,                         // calcium
                        0.0,                         // vitaminA
                        0.0,                         // vitaminC
                        0.0,                         // vitaminB12
                        0.0,                         // folate
                        0.0,                         // potassium
                        alcoholGrams,                // alcoholGrams
                        standardDrinks               // standardDrinks
                    )
                    
                    onBeverageLogged()
                    print("AlcoholBeverageBrowserView: Successfully logged \(beverage.name) with \(alcoholGrams)g alcohol and \(standardDrinks) standard drinks")
                }
            } catch {
                await MainActor.run {
                    print("AlcoholBeverageBrowserView: Error logging beverage: \(error)")
                    // Could show an error alert here
                }
            }
        }
    }
}

// MARK: - Alcohol Beverage Row
struct AlcoholBeverageRow: View {
    let beverage: AlcoholicBeverage
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Category Icon
                Text(beverage.categoryIcon)
                    .font(.title2)
                    .frame(width: 44, height: 44)
                    .background(Color.white.opacity(0.15))
                    .cornerRadius(10)
                
                // Beverage Info
                VStack(alignment: .leading, spacing: 6) {
                    Text(beverage.name)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .multilineTextAlignment(.leading)
                    
                    if let brand = beverage.brand, !brand.isEmpty && brand != "Generic" {
                        Text(brand)
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.7))
                    }
                    
                    // Nutrition Info
                    HStack(spacing: 16) {
                        HStack(spacing: 4) {
                            Text("\(Int(beverage.calories))")
                                .font(.caption)
                                .fontWeight(.semibold)
                            Text("cal")
                                .font(.caption)
                        }
                        .foregroundColor(.white.opacity(0.9))
                        
                        if beverage.carbsGrams > 0 {
                            HStack(spacing: 4) {
                                Text(String(format: "%.1f", beverage.carbsGrams))
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                Text("carbs")
                                    .font(.caption)
                            }
                            .foregroundColor(.white.opacity(0.9))
                        }
                        
                        HStack(spacing: 4) {
                            Text(String(format: "%.1f", beverage.alcoholContentPercent))
                                .font(.caption)
                                .fontWeight(.semibold)
                            Text("% ABV")
                                .font(.caption)
                        }
                        .foregroundColor(.white.opacity(0.9))
                        
                        Spacer()
                    }
                }
                
                Spacer()
                
                // Arrow indicator
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.5))
            }
            .padding()
            .background(Color.white.opacity(0.1))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - No Search Results View
struct NoSearchResultsView: View {
    let query: String
    let category: String
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "magnifyingglass.circle")
                .font(.system(size: 50))
                .foregroundColor(.white.opacity(0.7))
            
            Text("No results found")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.white)
            
            Text("No \(category.lowercased()) found matching \"\(query)\"")
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.8))
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Text("Try adjusting your search or browse all \(category.lowercased())")
                .font(.caption)
                .foregroundColor(.white.opacity(0.6))
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .padding()
    }
}

// MARK: - Preview
struct AlcoholBeverageBrowserView_Previews: PreviewProvider {
    static var previews: some View {
        AlcoholBeverageBrowserView(
            category: AlcoholCategory(key: "beer", name: "Beer/Seltzer", icon: "🍺", count: 142),
            onBack: {
                print("Back tapped")
            },
            onBeverageLogged: {
                print("Beverage logged")
            },
            onBeverageLoggedWithData: { calories, protein, carbs, fat, fiber, iron, calcium, vitaminA, vitaminC, vitaminB12, folate, potassium, alcoholGrams, standardDrinks in
                print("Beverage logged with data")
            }
        )
        .environmentObject(PreviewConstants.sampleAuthManagerUpdated)
        .preferredColorScheme(.dark)
    }
} 