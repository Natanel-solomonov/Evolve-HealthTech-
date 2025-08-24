// CaffeineProductBrowserView.swift
import SwiftUI
import Combine

struct CaffeineProductBrowserView: View {
    @EnvironmentObject var authManager: AuthenticationManager
    @State private var products: [CaffeineProduct] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var searchText = ""
    @State private var selectedProduct: CaffeineProduct?
    @State private var isSearching = false
    @State private var searchSubject = PassthroughSubject<String, Never>()
    @State private var cancellables = Set<AnyCancellable>()
    
    let category: CaffeineCategory
    let onBack: () -> Void
    let onProductLogged: () -> Void
    let onProductLoggedWithData: (Double, Double, Double, Double, Double, Double, Double, Double, Double, Double, Double, Double, Double) -> Void
    
    // Computed property for more descriptive category names
    private var categoryDisplayName: String {
        switch category.key {
        case "coffee": return "Coffee & Espresso"
        case "energy_drink": return "Energy Drinks"
        case "tea": return "Tea & Herbal"
        case "soda": return "Soda & Soft Drinks"
        case "supplement": return "Caffeine Supplements"
        default: return category.name
        }
    }
    
    // Colors to match nutrition theme
    private var gradientStartColor: Color { Color("Nutrition").opacity(0.6) }
    private var gradientEndColor: Color { Color("Nutrition") }
    
    // Create CaffeineAPI instance
    private var caffeineAPI: CaffeineAPI {
        CaffeineAPI(httpClient: authManager.httpClient)
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
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.white.opacity(0.7))
                        
                        TextField("Search \(category.name.lowercased())...", text: $searchText)
                            .foregroundColor(.white)
                            .accentColor(.white)
                            .onChange(of: searchText) { oldValue, newValue in
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
                    .padding(.horizontal, 15)
                    .padding(.vertical, 12)
                    .background(Color.white.opacity(0.2))
                    .cornerRadius(10)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
                
                // Content Area
                if isLoading && products.isEmpty {
                    VStack {
                        Spacer()
                        SpinningLoaderView()
                        Text("Loading \(category.name.lowercased())...")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.8))
                            .padding(.top, 10)
                        Spacer()
                    }
                } else if let errorMessage = errorMessage, products.isEmpty {
                    VStack {
                        Spacer()
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 50))
                            .foregroundColor(.white.opacity(0.8))
                        Text("Error loading products")
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding(.top, 10)
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.8))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 20)
                        
                        Button("Try Again") {
                            loadProducts()
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(Color.white.opacity(0.2))
                        .cornerRadius(10)
                        .padding(.top, 20)
                        
                        Spacer()
                    }
                } else {
                    // Products List
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(products) { product in
                                CaffeineProductRow(
                                    product: product,
                                    onTap: {
                                        selectedProduct = product
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
            loadProducts()
        }
        .sheet(item: $selectedProduct) { product in
            CaffeineProductDetailView(
                product: product,
                onLog: { loggedProduct, quantity in
                    // Don't make API call here - let the detail view handle it
                    // Just handle the callback to update UI
                    let caffeineMg = loggedProduct.caffeineMgPerServing * quantity
                    let calories = loggedProduct.caloriesPerServing * quantity
                    
                    // Call the callback with nutrition data including caffeine
                    onProductLoggedWithData(
                        calories,   // calories
                        0,         // protein
                        0,         // carbs
                        0,         // fat
                        0,         // fiber
                        0,         // iron
                        0,         // calcium
                        0,         // vitamin A
                        0,         // vitamin C
                        0,         // vitamin B12
                        0,         // folate
                        0,         // potassium
                        caffeineMg // caffeine
                    )
                    
                    // Also call the simple callback
                    onProductLogged()
                },
                onDismiss: {
                    selectedProduct = nil
                }
            )
            .environmentObject(authManager)
        }
        .onChange(of: selectedProduct) { oldValue, newValue in
            if let newProduct = newValue {
                print("CaffeineProductBrowserView: Selected product: \(newProduct.name)")
            } else {
                print("CaffeineProductBrowserView: Cleared selected product")
            }
        }
        .navigationBarHidden(true)
    }
    
    private func setupSearchDebounce() {
        searchSubject
            .debounce(for: .milliseconds(500), scheduler: RunLoop.main)
            .removeDuplicates()
            .sink { [self] searchText in
                performSearch(query: searchText)
            }
            .store(in: &cancellables)
    }
    
    private func performSearch(query: String) {
        isSearching = true
        
        Task {
            do {
                let response: CaffeineSearchResponse
                
                if query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    // Load category products if search is empty
                    let categoryResponse = try await caffeineAPI.getProductsByCategory(categoryKey: category.key)
                    response = CaffeineSearchResponse(
                        products: categoryResponse.products,
                        totalCount: categoryResponse.totalCount,
                        hasMore: categoryResponse.hasMore
                    )
                } else {
                    // Perform search with category filter
                    response = try await caffeineAPI.searchCaffeineProducts(
                        query: query,
                        category: category.key
                    )
                }
                
                await MainActor.run {
                    self.products = response.products
                    self.isSearching = false
                    self.errorMessage = nil
                }
            } catch {
                await MainActor.run {
                    self.isSearching = false
                    if self.products.isEmpty {
                        self.errorMessage = "Failed to load products"
                    }
                }
                print("CaffeineProductBrowserView: Error searching products: \(error)")
            }
        }
    }
    
    private func loadProducts() {
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                let response = try await caffeineAPI.getProductsByCategory(categoryKey: category.key)
                await MainActor.run {
                    self.products = response.products
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = "Failed to load \(category.name.lowercased()). Please check your connection."
                    self.isLoading = false
                }
                print("CaffeineProductBrowserView: Error loading products: \(error)")
            }
        }
    }
    
    // Note: logProduct function removed - API calls are now handled by CaffeineProductDetailView
}

// MARK: - Caffeine Product Row
struct CaffeineProductRow: View {
    let product: CaffeineProduct
    let onTap: () -> Void
    
    var body: some View {
        Button(action: {
            print("CaffeineProductRow: Tapped on product: \(product.name)")
            onTap()
        }) {
            HStack(spacing: 15) {
                // Product Icon
                Text(product.categoryIcon)
                    .font(.system(size: 30))
                    .frame(width: 50, height: 50)
                    .background(Color.white.opacity(0.15))
                    .cornerRadius(12)
                
                // Product Info
                VStack(alignment: .leading, spacing: 4) {
                    // Product Name
                    Text(product.displayName)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .multilineTextAlignment(.leading)
                        .lineLimit(2)
                    
                    // Serving Size
                    Text(product.servingDisplay)
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.8))
                        .lineLimit(1)
                    
                    // Calories (if any)
                    if product.caloriesPerServing > 0 {
                        Text("\(Int(product.caloriesPerServing)) cal")
                            .font(.caption2)
                            .foregroundColor(.white.opacity(0.6))
                    }
                }
                
                Spacer()
                
                // Caffeine Amount (prominently displayed)
                VStack(alignment: .trailing, spacing: 2) {
                    Text(product.caffeineDisplay)
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.orange)
                    
                    Text("caffeine")
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.6))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.white.opacity(0.1))
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
            )
        }
        .buttonStyle(CaffeineProductRowButtonStyle())
    }
}

// MARK: - Product Row Button Style
struct CaffeineProductRowButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .opacity(configuration.isPressed ? 0.8 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - Preview
struct CaffeineProductBrowserView_Previews: PreviewProvider {
    static var previews: some View {
        CaffeineProductBrowserView(
            category: CaffeineCategory(key: "coffee", name: "Coffee", icon: "☕", count: 1700),
            onBack: {},
            onProductLogged: {},
            onProductLoggedWithData: { _, _, _, _, _, _, _, _, _, _, _, _, _ in }
        )
        .environmentObject(AuthenticationManager())
    }
} 