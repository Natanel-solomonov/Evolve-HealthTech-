// AlcoholCategoriesView.swift
import SwiftUI

struct AlcoholCategoriesView: View {
    @EnvironmentObject var authManager: AuthenticationManager
    @State private var categories: [AlcoholCategory] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    
    let onCategorySelected: (AlcoholCategory) -> Void
    let onBack: () -> Void
    
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
                    
                    Text("Alcoholic Beverages")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    // Invisible spacer for balance
                    Rectangle()
                        .fill(Color.clear)
                        .frame(width: 44, height: 44)
                }
                .padding(.horizontal)
                .padding(.top, (UIApplication.shared.connectedScenes.first as? UIWindowScene)?.windows.first?.safeAreaInsets.top ?? 0)
                .padding(.bottom, 20)
                
                // Main Content
                if isLoading {
                    Spacer()
                    SpinningLoaderView()
                    Spacer()
                } else if let error = errorMessage {
                    Spacer()
                    ErrorStateView(message: error) {
                        loadCategories()
                    }
                    Spacer()
                } else {
                    ScrollView {
                        VStack(spacing: 30) {
                            // Title and subtitle
                            VStack(spacing: 12) {
                                Text("Choose a Category")
                                    .font(.title)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                                    .multilineTextAlignment(.center)
                                
                                Text("Select the type of alcoholic beverage you'd like to track")
                                    .font(.subheadline)
                                    .foregroundColor(.white.opacity(0.8))
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal)
                            }
                            .padding(.top, 20)
                            
                            // Categories Grid
                            LazyVGrid(columns: [
                                GridItem(.flexible(), spacing: 20),
                                GridItem(.flexible(), spacing: 20)
                            ], spacing: 25) {
                                ForEach(categories) { category in
                                    AlcoholCategoryCard(
                                        category: category,
                                        onTap: {
                                            onCategorySelected(category)
                                        }
                                    )
                                }
                            }
                            .padding(.horizontal, 20)
                            
                            Spacer(minLength: 50)
                        }
                    }
                }
            }
        }
        .onAppear {
            loadCategories()
        }
        .navigationBarHidden(true)
    }
    
    private func loadCategories() {
        isLoading = true
        errorMessage = nil
        
        alcoholAPI.getAlcoholCategories { result in
            DispatchQueue.main.async {
                isLoading = false
                
                switch result {
                case .success(let response):
                    categories = response.categories
                    print("AlcoholCategoriesView: Loaded \(categories.count) categories")
                    
                case .failure(let error):
                    errorMessage = "Failed to load categories: \(error.localizedDescription)"
                    print("AlcoholCategoriesView: Error loading categories: \(error)")
                }
            }
        }
    }
}

// MARK: - Alcohol Category Card
struct AlcoholCategoryCard: View {
    let category: AlcoholCategory
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 16) {
                // Category Icon
                Text(category.icon)
                    .font(.system(size: 50))
                    .frame(width: 80, height: 80)
                    .background(Color.white.opacity(0.15))
                    .cornerRadius(20)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color.white.opacity(0.3), lineWidth: 1)
                    )
                
                // Category Info
                VStack(spacing: 6) {
                    Text(category.name)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                    
                    Text("\(category.count) beverages")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 160)
            .background(Color.white.opacity(0.1))
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
            )
            .scaleEffect(1.0)
            .animation(.easeInOut(duration: 0.1), value: false)
        }
        .buttonStyle(AlcoholCategoryButtonStyle())
    }
}

// MARK: - Custom Button Style
struct AlcoholCategoryButtonStyles: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .opacity(configuration.isPressed ? 0.8 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - Error State View
struct ErrorStateView: View {
    let message: String
    let onRetry: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 50))
                .foregroundColor(.white.opacity(0.7))
            
            Text("Something went wrong")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.white)
            
            Text(message)
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.8))
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Button(action: onRetry) {
                HStack {
                    Image(systemName: "arrow.clockwise")
                        .font(.headline)
                    Text("Try Again")
                        .font(.headline)
                        .fontWeight(.semibold)
                }
                .foregroundColor(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(Color.white.opacity(0.2))
                .cornerRadius(12)
            }
        }
        .padding()
    }
}

// MARK: - Preview
struct AlcoholCategoriesView_Previews: PreviewProvider {
    static var previews: some View {
        AlcoholCategoriesView(
            onCategorySelected: { category in
                print("Selected category: \(category.name)")
            },
            onBack: {
                print("Back tapped")
            }
        )
        .environmentObject(PreviewConstants.sampleAuthManagerUpdated)
        .preferredColorScheme(.dark)
    }
}

// MARK: - Sample Data for Preview
extension AlcoholCategoriesView_Previews {
    static var sampleCategories: [AlcoholCategory] {
        [
            AlcoholCategory(key: "beer", name: "Beer (bottle/can or pint)", icon: "🍺", count: 142),
            AlcoholCategory(key: "wine", name: "Glass of wine", icon: "🍷", count: 82),
            AlcoholCategory(key: "sparkling", name: "Champagne / sparkling wine (flute)", icon: "🥂", count: 47),
            AlcoholCategory(key: "fortified", name: "Fortified wine / dessert wine (small glass)", icon: "🍷", count: 54),
            AlcoholCategory(key: "liquor", name: "Shot of liquor (straight spirit)", icon: "🥃", count: 98)
        ]
    }
} 
