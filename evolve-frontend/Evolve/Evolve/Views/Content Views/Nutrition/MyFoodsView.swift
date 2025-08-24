import SwiftUI

struct MyFoodsView: View {
    @EnvironmentObject var authManager: AuthenticationManager
    var onBack: () -> Void
    @Environment(\.theme) private var theme: any Theme
    
    @State private var customFoods: [CustomFoodResponse] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    
    // Dropdown states
    @State private var isCreatedFoodsExpanded = false
    @State private var isCustomRecipesExpanded = false
    
    // Delete functionality
    @State private var foodToDelete: CustomFoodResponse?
    @State private var showDeleteConfirmation = false
    @State private var isDeleting = false
    
    // Food confirmation
    @State private var selectedCustomFood: FoodProduct?
    
    // Colors matching NutritionView
    private let gradientStartColor = Color("Nutrition").opacity(0.6)
    private let gradientEndColor = Color("Nutrition")
    private let cardBackgroundColor = Color.white
    
    var body: some View {
        VStack(spacing: 0) {
            myFoodsHeader
                .padding(.top, (UIApplication.shared.connectedScenes.first as? UIWindowScene)?.windows.first?.safeAreaInsets.top ?? 0)
                .background(theme.background.edgesIgnoringSafeArea(.top))

            if isLoading {
                Spacer()
                ProgressView("Loading Your Foods...")
                    .foregroundColor(theme.primaryText)
                Spacer()
            } else if let errorMessage = errorMessage {
                Spacer()
                VStack {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundColor(theme.primaryText)
                    Text(errorMessage)
                        .foregroundColor(theme.primaryText)
                        .multilineTextAlignment(.center)
                    Button("Retry", action: loadCustomFoods)
                        .foregroundColor(theme.primaryText)
                        .padding()
                        .background(Color.white.opacity(0.2))
                        .cornerRadius(10)
                }
                .padding()
                Spacer()
            } else {
                ScrollView {
                    VStack(spacing: 16) {
                        // My Created Foods Dropdown
                        CustomFoodsDropdown(
                            isExpanded: $isCreatedFoodsExpanded,
                            customFoods: customFoods,
                            onTap: { food in
                                selectedCustomFood = convertToFoodProduct(food)
                            },
                            onDelete: { food in
                                foodToDelete = food
                                showDeleteConfirmation = true
                            }
                        )
                        
                        // My Custom Recipes Dropdown
                        CustomRecipesDropdown(
                            isExpanded: $isCustomRecipesExpanded
                        )
                    }
                    .padding()
                }
            }
        }
        .onAppear(perform: loadCustomFoods)
        .edgesIgnoringSafeArea(.top)
        .alert("Delete Custom Food", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) {
                foodToDelete = nil
                isDeleting = false
            }
            .disabled(isDeleting)
            
            Button("Delete", role: .destructive) {
                if let food = foodToDelete {
                    deleteCustomFood(food)
                }
            }
            .disabled(isDeleting)
        } message: {
            if let food = foodToDelete {
                if isDeleting {
                    Text("Deleting \(food.name)...")
                } else {
                    Text("Are you sure you want to delete \(food.name)? This action cannot be undone.")
                }
            }
        }
        .sheet(item: $selectedCustomFood) { foodProduct in
            FoodDetailConfirmationView(
                food: foodProduct,
                date: Date(),
                onLogSuccess: { loggedCals, loggedProtein, loggedCarbs, loggedFat, loggedFiber, loggedIron, loggedCalcium, loggedVitaminA, loggedVitaminC, loggedB12, loggedFolate, loggedPotassium in
                    // Handle successful logging if needed
                    print("Successfully logged custom food: \(foodProduct.productName ?? "Unknown")")
                },
                onNavigateToMain: {
                    // Navigate back to main view after tracking
                    onBack()
                }
            )
            .environmentObject(authManager)
        }
    }
    
    // Helper function to convert CustomFoodResponse to FoodProduct
    private func convertToFoodProduct(_ customFood: CustomFoodResponse) -> FoodProduct {
        return FoodProduct(
            id: "custom_\(customFood.id)",
            productName: customFood.name,
            brands: "Custom Food",
            calories: customFood.calories,
            protein: customFood.protein,
            carbs: customFood.carbs,
            fat: customFood.fat,
            calcium: 0.0, // Custom foods don't have detailed micronutrients
            iron: 0.0,
            potassium: 0.0,
            vitamin_a: 0.0,
            vitamin_c: 0.0,
            vitamin_b12: 0.0,
            fiber: 0.0,
            folate: 0.0
        )
    }
    
    private var myFoodsHeader: some View {
        HStack {
            Button(action: onBack) {
                Image(systemName: "chevron.left").font(.title2).foregroundColor(theme.primaryText)
            }
            Spacer()
            Text("My Foods").font(.headline).fontWeight(.bold).foregroundColor(theme.primaryText)
            Spacer()
            Image(systemName: "chevron.left").font(.title2).foregroundColor(.clear) // For spacing
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
    }

    private func loadCustomFoods() {
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                let foods: [CustomFoodResponse] = try await authManager.httpClient.request(
                    endpoint: "/custom-foods/",
                    method: "GET",
                    requiresAuth: true
                )
                await MainActor.run {
                    self.customFoods = foods
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = "Failed to load custom foods: \(error.localizedDescription)"
                    self.isLoading = false
                }
            }
        }
    }
    
    private func deleteCustomFood(_ food: CustomFoodResponse) {
        isDeleting = true
        
        Task {
            do {
                let _: EmptyResponse = try await authManager.httpClient.request(
                    endpoint: "/custom-foods/\(food.id)/",
                    method: "DELETE",
                    requiresAuth: true
                )
                
                await MainActor.run {
                    customFoods.removeAll { $0.id == food.id }
                    foodToDelete = nil
                    isDeleting = false
                    showDeleteConfirmation = false
                }
            } catch {
                // Optimistically remove from UI even on network errors since deletion usually works
                print("Network error during delete (ignoring): \(error)")
                
                await MainActor.run {
                    customFoods.removeAll { $0.id == food.id }
                    foodToDelete = nil
                    isDeleting = false
                    showDeleteConfirmation = false
                }
                
                // Only show error if item is still there after trying to reload
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    Task {
                        // Reload to check if deletion actually worked
                        await self.verifyDeletion(food: food)
                    }
                }
            }
        }
    }
    
    private func verifyDeletion(food: CustomFoodResponse) async {
        do {
            let foods: [CustomFoodResponse] = try await authManager.httpClient.request(
                endpoint: "/custom-foods/",
                method: "GET",
                requiresAuth: true
            )
            
            await MainActor.run {
                // If the deleted food is still in the list, show error and restore it
                if foods.contains(where: { $0.id == food.id }) {
                    self.customFoods = foods
                    self.errorMessage = "Failed to delete \(food.name). Please try again."
                }
                // If not in the list, deletion was successful, no need to do anything
            }
        } catch {
            // If we can't verify, assume deletion worked to avoid false errors
            print("Failed to verify deletion, assuming success: \(error)")
        }
    }
}

struct CustomFoodsDropdown: View {
    @Binding var isExpanded: Bool
    let customFoods: [CustomFoodResponse]
    let onTap: (CustomFoodResponse) -> Void
    let onDelete: (CustomFoodResponse) -> Void
    @Environment(\.theme) private var theme: any Theme
    
    private let cardBackgroundColor = Color.white
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            Button(action: {
                withAnimation(.easeInOut) {
                    isExpanded.toggle()
                }
            }) {
                HStack {
                    Text("My Created Foods")
                        .font(.system(size: 17))
                        .fontWeight(.bold)
                        .foregroundColor(theme.primaryText)
                    
                    Spacer()
                    
                    Text("(\(customFoods.count))")
                        .font(.system(size: 15))
                        .foregroundColor(theme.primaryText.opacity(0.7))
                    
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .foregroundColor(theme.primaryText.opacity(0.7))
                        .font(.system(size: 16, weight: .semibold))
                        .frame(width: 44, height: 44)
                }
                .padding()
            }
            .buttonStyle(PlainButtonStyle())
            
            // Expanded content
            if isExpanded {
                Divider()
                    .padding(.horizontal)
                
                if customFoods.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "square.and.pencil")
                            .font(.title2)
                            .foregroundColor(theme.primaryText.opacity(0.5))
                        Text("No Custom Foods Yet")
                            .font(.headline)
                            .foregroundColor(theme.primaryText)
                        Text("Create your first custom food from the search screen when a food isn't found.")
                            .font(.subheadline)
                            .foregroundColor(theme.primaryText.opacity(0.7))
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                } else {
                    LazyVStack(spacing: 0) {
                        ForEach(Array(customFoods.enumerated()), id: \.offset) { index, food in
                            CustomFoodCard(
                                food: food,
                                onTap: { onTap(food) },
                                onDelete: { onDelete(food) }
                            )
                            .padding(.bottom, 8)
                            
                            if index < customFoods.count - 1 {
                                Rectangle()
                                    .fill(theme.primaryText.opacity(0.1))
                                    .frame(height: 1)
                                    .padding(.horizontal)
                            }
                        }
                    }
                    .padding(.bottom, 12)
                }
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .themedFill(theme.cardStyle)
                .shadow(color: theme.defaultShadow.color, radius: theme.defaultShadow.radius, x: theme.defaultShadow.x, y: theme.defaultShadow.y)
        )
    }
}

struct CustomFoodCard: View {
    let food: CustomFoodResponse
    let onTap: () -> Void
    let onDelete: () -> Void
    @Environment(\.theme) private var theme: any Theme
    
    @State private var offset: CGFloat = 0
    @State private var showingDeleteButton = false
    
    var body: some View {
        ZStack {
            // Delete button background
            HStack {
                Spacer()
                Button(action: {
                    onDelete()
                }) {
                    VStack(spacing: 4) {
                        Image(systemName: "trash.fill")
                            .font(.title2)
                            .foregroundColor(.white)
                        Text("Delete")
                            .font(.caption)
                            .foregroundColor(.white)
                    }
                    .frame(width: 80)
                    .frame(maxHeight: .infinity)
                    .background(Color.black)
                }
                .opacity(showingDeleteButton ? 1 : 0)
            }
            
            // Main content
            VStack(alignment: .leading, spacing: 8) {
                Text(food.name)
                    .font(.system(size: 16))
                    .fontWeight(.semibold)
                    .foregroundColor(theme.primaryText)
                
                Text("\(food.calories, specifier: "%.0f") kcal")
                    .font(.system(size: 14))
                    .foregroundColor(theme.primaryText.opacity(0.7))
                
                HStack {
                    Text("P: \(food.protein, specifier: "%.1f")g")
                    Spacer()
                    Text("C: \(food.carbs, specifier: "%.1f")g")
                    Spacer()
                    Text("F: \(food.fat, specifier: "%.1f")g")
                }
                .font(.system(size: 12))
                .foregroundColor(theme.primaryText.opacity(0.6))
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(theme.background)
            .offset(x: offset)
            .gesture(
                DragGesture()
                    .onChanged { value in
                        if value.translation.width < 0 {
                            offset = max(value.translation.width, -80)
                            showingDeleteButton = offset < -40
                        }
                    }
                    .onEnded { value in
                        withAnimation(.spring()) {
                            if value.translation.width < -40 {
                                offset = -80
                                showingDeleteButton = true
                            } else {
                                offset = 0
                                showingDeleteButton = false
                            }
                        }
                    }
            )
            .onTapGesture {
                if offset != 0 {
                    withAnimation(.spring()) {
                        offset = 0
                        showingDeleteButton = false
                    }
                } else {
                    onTap()
                }
            }
        }
    }
}

struct CustomRecipesDropdown: View {
    @Binding var isExpanded: Bool
    @Environment(\.theme) private var theme: any Theme
    
    private let cardBackgroundColor = Color.white
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            Button(action: {
                withAnimation(.easeInOut) {
                    isExpanded.toggle()
                }
            }) {
                HStack {
                    Text("My Custom Recipes")
                        .font(.system(size: 17))
                        .fontWeight(.bold)
                        .foregroundColor(theme.primaryText)
                    
                    Spacer()
                    
                    Text("(0)")
                        .font(.system(size: 15))
                        .foregroundColor(theme.primaryText.opacity(0.7))
                    
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .foregroundColor(theme.primaryText.opacity(0.7))
                        .font(.system(size: 16, weight: .semibold))
                        .frame(width: 44, height: 44)
                }
                .padding()
            }
            .buttonStyle(PlainButtonStyle())
            
            // Expanded content
            if isExpanded {
                Divider()
                    .padding(.horizontal)
                
                VStack(spacing: 12) {
                    Image(systemName: "book.closed")
                        .font(.title2)
                        .foregroundColor(theme.primaryText.opacity(0.5))
                    Text("Coming Soon")
                        .font(.headline)
                        .foregroundColor(theme.primaryText)
                    Text("Custom recipes feature will be available in a future update.")
                        .font(.subheadline)
                        .foregroundColor(theme.primaryText.opacity(0.7))
                        .multilineTextAlignment(.center)
                }
                .padding()
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .themedFill(theme.cardStyle)
                .shadow(color: theme.defaultShadow.color, radius: theme.defaultShadow.radius, x: theme.defaultShadow.x, y: theme.defaultShadow.y)
        )
    }
}

struct CustomFoodResponse: Codable, Identifiable {
    let id: Int
    let name: String
    let calories: Double
    let protein: Double
    let carbs: Double
    let fat: Double
}

// MARK: - Empty Response for DELETE operations
struct EmptyResponse: Codable {}

struct MyFoodsView_Previews: PreviewProvider {
    static var previews: some View {
        MyFoodsView(onBack: {})
            .environmentObject(AuthenticationManager())
    }
}
