// CaffeineCategoriesView.swift
import SwiftUI

struct CaffeineCategoriesView: View {
    @EnvironmentObject var authManager: AuthenticationManager
    @State private var categories: [CaffeineCategory] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    
    let onCategorySelected: (CaffeineCategory) -> Void
    let onBack: () -> Void
    
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
                        Text("☕")
                            .font(.title2)
                        Text("Caffeine Categories")
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                    }
                    
                    Spacer()
                    
                    // Invisible spacer for balance
                    Rectangle()
                        .fill(Color.clear)
                        .frame(width: 44, height: 44)
                }
                .padding(.horizontal)
                .padding(.top, (UIApplication.shared.connectedScenes.first as? UIWindowScene)?.windows.first?.safeAreaInsets.top ?? 0)
                .padding(.bottom, 30)
                
                // Content Area
                if isLoading {
                    VStack {
                        Spacer()
                        SpinningLoaderView()
                        Text("Loading caffeine categories...")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.8))
                            .padding(.top, 10)
                        Spacer()
                    }
                } else if let errorMessage = errorMessage {
                    VStack {
                        Spacer()
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 50))
                            .foregroundColor(.white.opacity(0.8))
                        Text("Error loading categories")
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding(.top, 10)
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.8))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 20)
                        
                        Button("Try Again") {
                            loadCategories()
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
                    // Categories Grid
                    ScrollView {
                        LazyVGrid(columns: [
                            GridItem(.flexible(), spacing: 15),
                            GridItem(.flexible(), spacing: 15)
                        ], spacing: 20) {
                            ForEach(categories) { category in
                                CaffeineCategoryCard(
                                    category: category,
                                    onTap: {
                                        onCategorySelected(category)
                                    }
                                )
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 50)
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
        
        Task {
            do {
                let response = try await caffeineAPI.getCaffeineCategories()
                await MainActor.run {
                    self.categories = response.categories
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = "Failed to load categories. Please check your connection."
                    self.isLoading = false
                }
                print("CaffeineCategoriesView: Error loading categories: \(error)")
            }
        }
    }
}

// MARK: - Caffeine Category Card
struct CaffeineCategoryCard: View {
    let category: CaffeineCategory
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 16) {
                // Category Icon
                Text(category.icon)
                    .font(.system(size: 40))
                    .frame(width: 80, height: 80)
                    .background(Color.white.opacity(0.15))
                    .cornerRadius(20)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color.white.opacity(0.3), lineWidth: 2)
                    )
                
                // Category Info
                VStack(spacing: 6) {
                    Text(category.name)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                    
                    Text("\(category.count) products")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.8))
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
            .background(Color.white.opacity(0.1))
            .cornerRadius(20)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
            )
        }
        .buttonStyle(CaffeineCategoryCardButtonStyle())
    }
}

// MARK: - Category Card Button Style
struct CaffeineCategoryCardButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .opacity(configuration.isPressed ? 0.8 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}

// MARK: - Spinning Loader View
struct SpinningLoaderView: View {
    @State private var isRotating = false
    
    var body: some View {
        Circle()
            .trim(from: 0, to: 0.8)
            .stroke(Color.white.opacity(0.8), lineWidth: 3)
            .frame(width: 30, height: 30)
            .rotationEffect(Angle(degrees: isRotating ? 360 : 0))
            .animation(Animation.linear(duration: 1).repeatForever(autoreverses: false), value: isRotating)
            .onAppear {
                isRotating = true
            }
    }
}

// MARK: - Preview
struct CaffeineCategoriesView_Previews: PreviewProvider {
    static var previews: some View {
        CaffeineCategoriesView(
            onCategorySelected: { category in
                print("Selected category: \(category.name)")
            },
            onBack: {
                print("Back tapped")
            }
        )
        .environmentObject(AuthenticationManager())
    }
} 