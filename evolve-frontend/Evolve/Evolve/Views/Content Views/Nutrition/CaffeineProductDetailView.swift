// CaffeineProductDetailView.swift
import SwiftUI

struct CaffeineProductDetailView: View {
    @EnvironmentObject var authManager: AuthenticationManager
    @State private var selectedQuantity = 1.0
    @State private var isLogging = false
    @State private var hasLogged = false // Prevent multiple API calls
    private let viewId = UUID() // Track view instance
    
    let product: CaffeineProduct
    let onLog: (CaffeineProduct, Double) -> Void
    let onDismiss: () -> Void
    private let quantities: [Double] = [0.5, 1.0, 1.5, 2.0, 2.5, 3.0]
    
    // Colors to match nutrition theme
    private var gradientStartColor: Color { Color("Nutrition").opacity(0.6) }
    private var gradientEndColor: Color { Color("Nutrition") }
    private var accentColor: Color { Color(red: 0.8, green: 0.4, blue: 0.1) }
    
    var totalCalories: Int {
        Int(product.caloriesPerServing * selectedQuantity)
    }
    
    var totalCaffeine: Double {
        product.caffeineMgPerServing * selectedQuantity
    }
    
    var totalSugar: Double {
        (product.sugarGPerServing ?? 0) * selectedQuantity
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
                            Text(product.categoryIcon)
                                .font(.system(size: 60))
                                .frame(width: 100, height: 100)
                                .background(Color.white.opacity(0.15))
                                .cornerRadius(25)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 25)
                                        .stroke(Color.white.opacity(0.3), lineWidth: 2)
                                )
                            
                            // Product Name and Brand
                            VStack(spacing: 8) {
                                Text(product.displayName)
                                    .font(.title2)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                                    .multilineTextAlignment(.center)
                                    .lineLimit(3)
                                
                                if let brand = product.brand, !brand.isEmpty {
                                    Text(brand)
                                        .font(.subheadline)
                                        .foregroundColor(.white.opacity(0.8))
                                }
                            }
                        }
                        
                        // Nutrition Info Card
                        CaffeineNutritionInfoCard(
                            calories: totalCalories,
                            caffeine: totalCaffeine,
                            sugar: totalSugar,
                            servingDescription: product.servingDisplay,
                            quantity: selectedQuantity
                        )
                        
                        // Quantity Selection
                        CaffeineQuantitySelectionCard(
                            selectedQuantity: $selectedQuantity,
                            quantities: quantities
                        )
                        
                        // Caffeine Warning (if high caffeine)
                        if totalCaffeine > 200 {
                            CaffeineWarningCard(caffeine: totalCaffeine)
                        }
                        
                        // Log Button
                        Button(action: {
                            print("CaffeineProductDetailView: Log button tapped")
                            logProduct()
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
                                
                                let servingText = selectedQuantity == 1.0 ? "serving" : "servings"
                                Text(isLogging ? "Logging..." : (hasLogged ? "Logged!" : "Log \(selectedQuantity.formatted(.number.precision(.fractionLength(0...1)))) \(servingText)"))
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
            print("CaffeineProductDetailView [\(viewId)]: View appeared for product: \(product.name)")
        }
        .onDisappear {
            print("CaffeineProductDetailView [\(viewId)]: View disappeared for product: \(product.name)")
            // Reset logging state if view is dismissed without logging
            if !hasLogged {
                isLogging = false
                hasLogged = false
            }
        }
    }
    
    private func logProduct() {
        print("CaffeineProductDetailView [\(viewId)]: logProduct() called, isLogging: \(isLogging), hasLogged: \(hasLogged)")
        
        // Prevent multiple calls
        guard !isLogging && !hasLogged else {
            print("CaffeineProductDetailView [\(viewId)]: Already logging or has logged, ignoring call")
            return
        }
        
        guard let userPhone = authManager.currentUser?.phone else {
            print("CaffeineProductDetailView [\(viewId)]: User not logged in")
            return
        }
        
        isLogging = true
        hasLogged = true
        print("CaffeineProductDetailView [\(viewId)]: Set isLogging to true and hasLogged to true")
        
        let taskId = UUID()
        print("CaffeineProductDetailView [\(viewId)]: Creating Task with ID: \(taskId)")
        
        Task {
            print("CaffeineProductDetailView [\(viewId)]: Task [\(taskId)] started execution")
            do {
                print("CaffeineProductDetailView [\(viewId)]: Task [\(taskId)] - Creating CaffeineAPI instance")
                let caffeineAPI = CaffeineAPI(httpClient: authManager.httpClient)
                print("CaffeineProductDetailView [\(viewId)]: Task [\(taskId)] - About to call logCaffeineProduct for \(product.name)")
                let response = try await caffeineAPI.logCaffeineProduct(
                    product: product,
                    quantity: selectedQuantity,
                    mealType: "caffeine", // Default meal type for caffeine
                    userPhone: userPhone
                )
                print("CaffeineProductDetailView [\(viewId)]: Task [\(taskId)] - API call completed successfully: \(response)")
                
                await MainActor.run {
                    print("CaffeineProductDetailView [\(viewId)]: Task [\(taskId)] - About to call onLog callback")
                    // Call the callback to update local UI
                    onLog(product, selectedQuantity)
                    print("CaffeineProductDetailView [\(viewId)]: Task [\(taskId)] - onLog callback completed")
                    isLogging = false
                    
                    // Add a small delay to show success state before dismissing
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        print("CaffeineProductDetailView [\(viewId)]: Task [\(taskId)] - About to call onDismiss")
                        onDismiss()
                    }
                }
            } catch {
                await MainActor.run {
                    print("CaffeineProductDetailView [\(viewId)]: Task [\(taskId)] - Error logging product: \(error)")
                    // Don't call onLog callback on error - let user retry
                    isLogging = false
                }
            }
            print("CaffeineProductDetailView [\(viewId)]: Task [\(taskId)] completed execution")
        }
    }
}

// MARK: - Caffeine Nutrition Info Card
struct CaffeineNutritionInfoCard: View {
    let calories: Int
    let caffeine: Double
    let sugar: Double
    let servingDescription: String
    let quantity: Double
    
    var body: some View {
        VStack(spacing: 16) {
            // Serving Info
            Text("Per \(quantity.formatted(.number.precision(.fractionLength(0...1)))) × \(servingDescription)")
                .font(.caption)
                .foregroundColor(.white.opacity(0.8))
                .multilineTextAlignment(.center)
            
            // Main stats
            HStack(spacing: 0) {
                // Calories
                CaffeineNutritionStatView(
                    value: "\(calories)",
                    unit: "cal",
                    label: "Calories",
                    color: .orange
                )
                
                Divider()
                    .background(Color.white.opacity(0.3))
                    .frame(height: 60)
                
                // Caffeine (prominently displayed)
                CaffeineNutritionStatView(
                    value: "\(Int(caffeine))",
                    unit: "mg",
                    label: "Caffeine",
                    color: .yellow
                )
                
                if sugar > 0 {
                    Divider()
                        .background(Color.white.opacity(0.3))
                        .frame(height: 60)
                    
                    // Sugar
                    CaffeineNutritionStatView(
                        value: String(format: "%.1f", sugar),
                        unit: "g",
                        label: "Sugar",
                        color: .pink
                    )
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

// MARK: - Caffeine Nutrition Stat View
struct CaffeineNutritionStatView: View {
    let value: String
    let unit: String
    let label: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            HStack(alignment: .lastTextBaseline, spacing: 2) {
                Text(value)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(color)
                Text(unit)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(color.opacity(0.8))
            }
            
            Text(label)
                .font(.caption)
                .foregroundColor(.white.opacity(0.8))
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Caffeine Quantity Selection Card
struct CaffeineQuantitySelectionCard: View {
    @Binding var selectedQuantity: Double
    let quantities: [Double]
    
    var body: some View {
        VStack(spacing: 16) {
            Text("How many servings?")
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(.white)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                ForEach(quantities, id: \.self) { quantity in
                    Button(action: {
                        selectedQuantity = quantity
                    }) {
                        Text(quantity == 1.0 ? "1" : quantity.formatted(.number.precision(.fractionLength(0...1))))
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(selectedQuantity == quantity ? .black : .white)
                            .frame(width: 60, height: 44)
                            .background(selectedQuantity == quantity ? Color.white : Color.white.opacity(0.2))
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.white.opacity(0.3), lineWidth: 1)
                            )
                    }
                    .scaleEffect(selectedQuantity == quantity ? 1.05 : 1.0)
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

// MARK: - Caffeine Warning Card
struct CaffeineWarningCard: View {
    let caffeine: Double
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.title2)
                .foregroundColor(.orange)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("High Caffeine Content")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                
                Text("This contains \(Int(caffeine))mg of caffeine. The recommended daily limit is 400mg.")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.8))
                    .multilineTextAlignment(.leading)
            }
            
            Spacer()
        }
        .padding(16)
        .background(Color.orange.opacity(0.2))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.orange.opacity(0.4), lineWidth: 1)
        )
    }
}

// MARK: - Preview
struct CaffeineProductDetailView_Previews: PreviewProvider {
    static var previews: some View {
        CaffeineProductDetailView(
            product: sampleCaffeineProduct,
            onLog: { product, quantity in
                print("Logged \(quantity) servings of \(product.name)")
            },
            onDismiss: {
                print("Dismissed")
            }
        )
        .environmentObject(AuthenticationManager())
    }
    
    static let sampleCaffeineProduct = CaffeineProduct(
        id: "sample-id",
        name: "Cappuccino",
        brand: "Starbucks",
        category: "coffee",
        subCategory: "cappuccino",
        flavorOrVariant: nil,
        servingSizeML: 355,
        servingSizeDesc: "12 fl oz cup",
        caffeineMgPerServing: 150,
        caffeineMgPer100ML: 42.25,
        caloriesPerServing: 120,
        sugarGPerServing: 10,
        upc: nil,
        source: "test",
        createdAt: "2025-07-24T12:00:00Z",
        updatedAt: "2025-07-24T12:00:00Z"
    )
} 