import SwiftUI
import UniformTypeIdentifiers
import Combine

// MARK: - Offer View
struct RewardsView: View {
    @EnvironmentObject var authManager: AuthenticationManager
    @StateObject private var cinematicManager = CinematicStateManager()
    @Environment(\.theme) private var theme: any Theme

    @State private var promotions: [AffiliatePromotion] = []
    @State private var isLoading = false
    @State private var errorMessage: String? = nil

    @State private var selectedPromotionForRedemption: AffiliatePromotion? = nil
    @State private var showingDiscountCode = false
    
    // Redemption state
    @State private var isRedeeming = false
    @State private var redemptionError: String? = nil
    @State private var lastRedemptionResponse: RedemptionResponse? = nil
    @State private var shouldRefreshProducts = false
    
    // Background gradient colors
    private let leftGradientColor: Color = Color("Mind")
    private let rightGradientColor: Color = Color("Sleep")
    @State private var useGradientBackground = false
    
    // Get the dynamic theme color from environment (defaulting to Mind color for offers)
    @Environment(\.dynamicThemeColor) private var dynamicThemeColor
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background – mimics the one used in DashboardView
                GridBackground()
                    .cinematicBackground(isActive: cinematicManager.isAnyActive)
                
                if useGradientBackground {
                    TopHorizontalGradient(leftColor: leftGradientColor, rightColor: rightGradientColor)
                        .frame(height: geometry.size.height * 0.6)
                        .frame(maxHeight: .infinity, alignment: .top)
                        .ignoresSafeArea()
                } else {
                    TopSolidColor(color: dynamicThemeColor)
                        .frame(height: geometry.size.height * 0.6)
                        .frame(maxHeight: .infinity, alignment: .top)
                        .ignoresSafeArea()
                }

                VStack(spacing: 0) {
                    // Content
                    ScrollView {
                        LazyVStack(spacing: 20) {
                            // Header with offers title and settings
                            OffersHeaderView(onSettingsTap: {
                                cinematicManager.present("settings")
                            })
                                .padding(.bottom, 0)
                            
                            // Balance View - Three separate cards
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text("Balance")
                                        .font(.system(size: 21, weight: .semibold))
                                        .foregroundColor(theme.primaryText)
                                    Spacer()
                                }
                                
                                if let user = authManager.currentUser {
                                    BalanceCardsView(
                                        pointsAvailable: user.availablePoints,
                                        totalPoints: user.lifetimePoints,
                                        totalMoneySaved: user.lifetimeSavings
                                    )
                                } else {
                                    BalanceCardsView(pointsAvailable: 0, totalPoints: 0, totalMoneySaved: 0.0)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            
                            // My Products Section
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text("My Products")
                                        .font(.system(size: 21, weight: .semibold))
                                        .foregroundColor(theme.primaryText)
                                    Spacer()
                                }
                                
                                MyProductsView(shouldRefresh: $shouldRefreshProducts)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            
                            // Offers Section
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text("My Offers")
                                        .font(.system(size: 21, weight: .semibold))
                                        .foregroundColor(theme.primaryText)
                                    Spacer()
                                }

                                if isLoading {
                                    ProgressView("Loading Offers...")
                                        .padding(.vertical, 50)
                                } else if let errorMsg = errorMessage {
                                    VStack {
                                         Image(systemName: "exclamationmark.triangle.fill")
                                             .foregroundColor(.red)
                                             .font(.largeTitle)
                                         Text("Error loading offers:")
                                         Text(errorMsg)
                                             .font(.caption)
                                             .foregroundColor(theme.secondaryText)
                                         Button("Retry") { Task { await fetchPromotions() } }
                                         .padding(.top)
                                    }
                                    .padding(.vertical, 50)
                                } else if promotions.isEmpty {
                                    VStack(spacing: 12) {
                                        
                                        Text("No offers available at the moment.")
                                            .foregroundColor(theme.secondaryText)
                                            .font(.system(size: 16, weight: .medium))
                                            .multilineTextAlignment(.center)
                                        
                                        Text("Check back soon for new deals!")
                                            .font(.system(size: 14))
                                            .foregroundColor(theme.secondaryText.opacity(0.7))
                                            .multilineTextAlignment(.center)
                                    }
                                    .padding(.vertical, 50)
                                } else {
                                    VStack(spacing: 16) {
                                        ForEach(promotions) { promotion in
                                            FullImageOfferCardView(
                                                promotion: promotion,
                                                onRedeem: { selectedPromotion in
                                                    self.redeemPromotion(selectedPromotion)
                                                },
                                                isLoading: isRedeeming && selectedPromotionForRedemption?.id == promotion.id
                                            )
                                            .frame(maxWidth: .infinity)
                                        }
                                    }
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(.horizontal)
                        .padding(.bottom) // Padding for the ScrollView content
                    }
                    .refreshable {
                        // Always refresh user data to get latest balance
                        authManager.fetchCurrentUserDetails()
                        
                        await fetchPromotions(isRefresh: true)
                    }
                }
                
                // Cinematic settings overlay
                if cinematicManager.isActive("settings") {
                    SettingsView<AuthenticationManager>(
                        onDismiss: {
                            cinematicManager.dismiss("settings")
                        }
                    )
                    .environmentObject(authManager)
                    .cinematicOverlay()
                }
            }
            .dismissKeyboardOnTap()
        }
        .alert("Redemption Error", isPresented: Binding<Bool>(
            get: { redemptionError != nil },
            set: { _ in redemptionError = nil }
        )) {
            Button("OK") {
                redemptionError = nil
            }
        } message: {
            Text(redemptionError ?? "Unknown error occurred")
        }
        .sheet(isPresented: $showingDiscountCode) {
            if let promotion = selectedPromotionForRedemption {
                DiscountCodeView(
                    promotion: promotion,
                    discountCode: lastRedemptionResponse?.discountCode.code ?? "N/A",
                    onMarkAsRedeemed: {
                        self.showingDiscountCode = false
                    }
                )
            } else {
                Text("Error: No promotion selected.")
            }
        }
        .task {
            // Always refresh user details to ensure balance is current
            authManager.fetchCurrentUserDetails()
            
            // Fetch promotions from backend
            await fetchPromotions()
        }
    }

    private func redeemPromotion(_ promotion: AffiliatePromotion) {
        guard !isRedeeming else { return }
        
        selectedPromotionForRedemption = promotion
        isRedeeming = true
        redemptionError = nil
        
        let affiliateAPI = AffiliateAPI(httpClient: authManager.httpClient)
        
        affiliateAPI.redeemPromotion(promotionId: promotion.id) { result in
            DispatchQueue.main.async {
                self.isRedeeming = false
                
                switch result {
                case .success(let response):
                    print("Redemption successful: \(response.message)")
                    self.lastRedemptionResponse = response
                    self.selectedPromotionForRedemption = promotion
                    self.showingDiscountCode = true
                    
                    // Refresh user data to update points balance
                    self.authManager.fetchCurrentUserDetails()
                    
                    // Refresh promotions to update availability
                    Task {
                        await self.fetchPromotions(isRefresh: true)
                    }
                    
                    // Refresh user products after successful redemption
                    self.shouldRefreshProducts = true
                    
                case .failure(let error):
                    print("Redemption failed: \(error.localizedDescription)")
                    
                    // Handle specific error messages
                    switch error {
                    case .custom(let message):
                        self.redemptionError = message
                    case .requestFailed(_):
                        self.redemptionError = "No internet connection. Please check your network and try again."
                    case .serverError(_, _):
                        self.redemptionError = "Server error. Please try again later."
                    case .unauthorized:
                        self.redemptionError = "You are not authorized to redeem this promotion."
                    default:
                        self.redemptionError = "Failed to redeem promotion. Please try again."
                    }
                }
            }
        }
    }

    private func fetchPromotions(isRefresh: Bool = false) async {

        guard let userId = authManager.currentUser?.id else {
            await MainActor.run { errorMessage = "User ID not found." }
            return
        }

        let activeOnly = true  // Always fetch only active promotions
        
        if isRefresh {
            AffiliatePromotionCache.shared.clear(for: userId, activeOnly: activeOnly)
        }

        // Try to load from cache first, but not on a pull-to-refresh
        if !isRefresh, let cachedPromotions = AffiliatePromotionCache.shared.load(for: userId, activeOnly: activeOnly) {
            await MainActor.run { 
                self.promotions = cachedPromotions.sorted { $0.affiliate.name < $1.affiliate.name } 
            }
            return
        }
        
        await MainActor.run {
            self.isLoading = true
            self.errorMessage = nil
        }

        let affiliateAPI = AffiliateAPI(httpClient: authManager.httpClient)
        
        do {
            let fetchedPromotions: [AffiliatePromotion] = try await withCheckedThrowingContinuation { continuation in
                affiliateAPI.fetchUserAffiliatePromotions(userId: userId, activeOnly: activeOnly) { result in
                    continuation.resume(with: result)
                }
            }
            
            print("OfferView: Network fetch successful for \(fetchedPromotions.count) promotions (activeOnly: \(activeOnly)).")
            let sortedPromotions = fetchedPromotions.sorted { $0.affiliate.name < $1.affiliate.name }
            
            // Log promotion details for debugging
            for promotion in sortedPromotions.prefix(3) {
                print("OfferView: Promotion - \(promotion.title), Active: \(promotion.isCurrentlyActive), Expires: \(promotion.daysUntilExpiry) days")
            }
            
            // Save to new cache
            AffiliatePromotionCache.shared.save(promotions: sortedPromotions, for: userId, activeOnly: activeOnly)
            
            await MainActor.run {
                self.promotions = sortedPromotions
            }

        } catch {
            print("OfferView: Network fetch failed for promotions: \(error.localizedDescription)")
            await MainActor.run {
                // Only show error if we don't have cached data
                if AffiliatePromotionCache.shared.load(for: userId, activeOnly: activeOnly) == nil {
                    self.errorMessage = "Failed to fetch promotions: \(error.localizedDescription)"
                }
            }
        }
        
        await MainActor.run {
            if self.isLoading {
                self.isLoading = false
            }
        }
    }
}

private struct OffersHeaderView: View {
    @Environment(\.theme) private var theme: any Theme
    @EnvironmentObject var authManager: AuthenticationManager
    let onSettingsTap: () -> Void

    private var userInitials: String {
        guard let user = authManager.currentUser, !user.firstName.isEmpty, !user.lastName.isEmpty else {
            return ""
        }
        
        let firstInitial = String(user.firstName.first!)
        let lastInitial = String(user.lastName.first!)
        
        return "\(firstInitial)\(lastInitial)"
    }

    var body: some View {
        HStack {
            Text("Rewards")
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(theme.primaryText)
            
            Spacer()

            Button(action: onSettingsTap) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [Color.white, Color("OffWhite")]),
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .shadow(color: .black.opacity(0.15), radius: 4, x: 0, y: 4)
                        .frame(width: 40, height: 40)
                    
                    if userInitials.isEmpty {
                        Image(systemName: "person.fill")
                            .foregroundColor(theme.primaryText)
                    } else {
                        Text(userInitials)
                            .font(.headline)
                            .foregroundColor(theme.primaryText)
                    }
                }
            }
        }
        .padding(.top, 10)
    }
}

struct RewardsView_Previews: PreviewProvider {
    static var previews: some View {
        RewardsView()
            .environmentObject(PreviewConstants.sampleAuthManagerUpdated) // Assuming PreviewConstants exists
    }
}


// MARK: - Models
struct Product: Identifiable {
    let id = UUID()
    let imageName: String
    let productName: String
    let priceInfo: String
}

// MARK: - Single Product Vendor View

struct SingleProductVendorView: View {
    // Takes an AffiliatePromotion instance
    let promotion: AffiliatePromotion
    // Add a closure to handle the redeem action, accepting the promotion
    let onRedeem: (AffiliatePromotion) -> Void
    @Environment(\.theme) private var theme: any Theme

    var body: some View {
        GeometryReader { geometry in
            let cardWidth = geometry.size.width
            let cardHeight = cardWidth * 1.2 // Reduced from 1.5 to 1.3 to better match the new image height ratio
            let spacing: CGFloat = 16
            let imagePadding: CGFloat = 20
            let vendorSize = min(40, cardWidth * 0.15)
            let imageHeight = cardHeight * 0.5 // Reduced from 0.65 to 0.5

            VStack(spacing: 0) {
                // Vendor Header
                HStack(alignment: .center, spacing: spacing / 2) {
                    // Use AsyncImage for affiliate logo
                    AsyncImage(url: promotion.affiliate.fullLogoURL) { phase in
                        if let image = phase.image {
                            image.resizable()
                                .scaledToFit()
                        } else if phase.error != nil {
                            // Placeholder on error
                            Image(systemName: "building.2")
                                .resizable()
                                .scaledToFit()
                                .foregroundColor(.gray)
                        } else {
                            // Placeholder while loading
                            ProgressView()
                        }
                    }
                    .frame(width: vendorSize, height: vendorSize)
                    .padding(5)
                    .background(Color.gray.opacity(0.2))
                    .clipShape(RoundedRectangle(cornerRadius: 5))

                    VStack(alignment: .leading, spacing: 2) {
                        Text(promotion.affiliate.name) // Use promotion data
                            .font(.system(size: 17))
                            .foregroundColor(theme.primaryText)
                            .lineLimit(1)
                        Text(promotion.affiliate.location ?? "Online") // Use promotion data, provide default
                            .font(.system(size: 12))
                            .foregroundColor(theme.primaryText)
                            .lineLimit(1)
                    }
                    Spacer()
                }
                .padding(.top, spacing)
                .padding(.horizontal, spacing)
                .padding(.bottom, spacing / 2)

                // Top section: Image - Use AsyncImage with the computed property
                 Group {
                     AsyncImage(url: promotion.fullProductImageURL) { phase in
                         if let image = phase.image {
                             image.resizable()
                                 .scaledToFit()
                         } else if phase.error != nil {
                             // Placeholder if error loading image
                             Rectangle()
                                 .fill(Color.gray.opacity(0.3))
                                 .overlay(Image(systemName: "photo").foregroundColor(.white))
                         } else {
                             // Placeholder while loading
                             ProgressView()
                         }
                     }
                 }
                .frame(height: imageHeight)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                .padding(.horizontal, imagePadding)
                .clipped()

                Spacer()

                // Middle section: Text details
                VStack(alignment: .leading, spacing: 4) {
                    // Removed status Text view
                    Text(promotion.title) // Use promotion data
                        .font(.system(size: 28))
                        .foregroundColor(theme.primaryText)
                        .lineLimit(1)
                    Text(promotion.description) // Use promotion data
                        .font(.system(size: 17))
                        .foregroundColor(theme.primaryText)
                        .lineLimit(2)
                }
                .padding(.horizontal, spacing)
                .padding(.bottom, spacing)
                .frame(maxWidth: .infinity, alignment: .leading)

                // Bottom section: Price and Buy button
                HStack {
                     // Combine points and original price
                     HStack(spacing: 8) {
                         if let priceString = promotion.originalPrice {
                             Text("$\(priceString)")
                                 .strikethrough()
                                 .font(.system(size: 17))
                                 .foregroundColor(theme.secondaryText)
                         }
                         Text("\(promotion.pointValue ?? 0) Points")
                             .font(.system(size: 17))
                             .foregroundColor(theme.primaryText)
                     }

                    Spacer()

                    Button("Redeem") {
                        // Call the closure with the promotion when the button is tapped
                        onRedeem(promotion)
                        // print("Redeem button tapped for \(promotion.title)") // Keep or remove logging as needed
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.black)
                    .foregroundColor(.white)
                    .cornerRadius(20)
                    .font(.system(size: 17))
                }
                .padding(.horizontal, spacing)
                .padding(.vertical, spacing / 2)
                .background(Color.gray.opacity(0.2))
            }
            .frame(width: cardWidth, height: cardHeight)
            .background(theme.background)
            .cornerRadius(15)
            .shadow(color: theme.defaultShadow.color, radius: theme.defaultShadow.radius, x: theme.defaultShadow.x, y: theme.defaultShadow.y)
            .frame(maxWidth: .infinity)
        }
        .aspectRatio(400/680, contentMode: .fit) // Match BalanceView's aspect ratio approach but with appropriate height ratio
    }
}

// MARK: - Full Image Offer Card View
struct FullImageOfferCardView: View {
    let promotion: AffiliatePromotion
    let onRedeem: (AffiliatePromotion) -> Void
    let isLoading: Bool
    @Environment(\.theme) private var theme: any Theme

    var body: some View {
        ZStack {
            // Background image filling entire card
            Group {
                if let productImage = promotion.productImage, !productImage.hasPrefix("http") {
                    // Local asset image
                    Image(productImage)
                        .resizable()
                        .scaledToFill()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .clipped()
                } else {
                    // Remote URL image
                    AsyncImage(url: promotion.fullProductImageURL) { phase in
                        if let image = phase.image {
                            image
                                .resizable()
                                .scaledToFill()
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .clipped()
                        } else if phase.error != nil {
                            // Placeholder if error loading image
                            Rectangle()
                                .fill(Color.gray.opacity(0.3))
                                .overlay(
                                    Image(systemName: "photo")
                                        .foregroundColor(.white)
                                        .font(.system(size: 40))
                                )
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                        } else {
                            // Placeholder while loading
                            Rectangle()
                                .fill(Color.gray.opacity(0.2))
                                .overlay(ProgressView().tint(.white))
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                        }
                    }
                }
            }
            
            // Content overlay
            VStack {
                // Top overlay for expired status
                if !promotion.isCurrentlyActive {
                    HStack {
                        HStack(spacing: 4) {
                            Image(systemName: "clock.fill")
                                .font(.system(size: 12))
                            Text("EXPIRED")
                                .font(.system(size: 12, weight: .bold))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.red.opacity(0.8))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                        
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                }
                
                Spacer()
                
                // Bottom overlay with solid background
                VStack(alignment: .leading, spacing: 8) {
                    // Title at the top
                    Text(promotion.title)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    // Bottom row with offer specifics and button
                    HStack {
                        // Offer specifics information
                        VStack(alignment: .leading, spacing: 4) {
                            if let offerSpecifics = promotion.offerSpecifics {
                                Text(offerSpecifics)
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.white)
                            } else {
                                Text("\(promotion.pointValue ?? 0) Points")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.white)
                            }
                            
                            // Show expiry status
                            Text(promotion.expiryStatusMessage)
                                .font(.system(size: 12, weight: .regular))
                                .foregroundColor(.white.opacity(0.8))
                        }
                        
                        Spacer()
                        
                        // Redeem button with point value
                        Button(isLoading ? "Redeeming..." : "\(promotion.pointValue ?? 0) pts") {
                            onRedeem(promotion)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(promotion.isCurrentlyActive && !isLoading ? .white : .gray)
                        .foregroundColor(promotion.isCurrentlyActive && !isLoading ? .black : .white)
                        .font(.system(size: 16, weight: .semibold))
                        .disabled(!promotion.isCurrentlyActive || isLoading)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .frame(height: 100)
                .background(
                    Rectangle()
                        .fill(.black.opacity(0.8))
                        .blur(radius: 0.5)
                )
            }
        }
        .aspectRatio(3/4, contentMode: .fit)
        .background(theme.background)
        .clipShape(RoundedRectangle(cornerRadius: 15))
        .shadow(color: theme.defaultShadow.color, radius: theme.defaultShadow.radius, x: theme.defaultShadow.x, y: theme.defaultShadow.y)
    }
}

// MARK: - Vendor View
struct VendorView: View {
    // Vendor properties as input parameters
    let vendorLogoName: String
    let vendorName: String
    let vendorLocation: String
    let products: [Product]
    
    // Define two flexible columns for the grid.
    let gridColumns: [GridItem] = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
    ]
    @Environment(\.theme) private var theme: any Theme
     
    var body: some View {
        GeometryReader { geometry in
            // Define a dynamic card width as 90% of available width.
            let spacing: CGFloat = 16
            // Compute product width based on geometry width and spacing: three spacing values (leading, between columns, trailing)
            let productWidth = (geometry.size.width - (spacing * 3)) / 2
            let productCardScale: CGFloat = 0.8
            let productCardSize = productWidth * productCardScale
            // Optionally, compute a vendor image size relative to geometry width (maximum 80)
            let vendorSize = min(80, geometry.size.width * 0.2) // UPDATED: Use geometry.size.width
            
            VStack(alignment: .leading, spacing: spacing) {
                // Vendor Header: Vendor image on the left and details on the right.
                HStack(alignment: .center, spacing: spacing) {
                    Rectangle()
                        .fill(Color.white)
                        .frame(width: vendorSize / 2, height: vendorSize / 2)
                        .clipped()
                        .cornerRadius(15)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(vendorName)
                            .font(.system(size: 17))
                            .foregroundColor(theme.primaryText.opacity(0.9))
                            .lineLimit(1)
                        Text(vendorLocation)
                            .font(.system(size: 12))
                            .foregroundColor(theme.primaryText.opacity(0.9))
                            .lineLimit(1)
                    }
                }
                .padding(.horizontal, spacing)
                
                // Products grid: Displays a grid of featured products.
                LazyVGrid(columns: [
                    GridItem(.flexible(), spacing: spacing),
                    GridItem(.flexible(), spacing: spacing)
                ], spacing: spacing) {
                    ForEach(products) { product in
                        VStack(alignment: .leading, spacing: 4) {
                            Rectangle()
                                .fill(Color.white)
                                .frame(width: productCardSize, height: productCardSize)
                                .cornerRadius(15)
                            
                            Text(product.productName)
                                .font(.system(size: 12))
                                .foregroundColor(theme.primaryText.opacity(0.9))
                                .lineLimit(1)
                            
                            Text(product.priceInfo)
                                .font(.system(size: 10))
                                .foregroundColor(theme.primaryText.opacity(0.9))
                                .lineLimit(1)
                        }
                    }
                }
            }
            .padding(spacing)
            .frame(maxWidth: .infinity) // ENSURE this takes full width
            .background(Color(red: 0.13, green: 0.13, blue: 0.13))
            .cornerRadius(15)
            .shadow(color: theme.defaultShadow.color, radius: theme.defaultShadow.radius, x: theme.defaultShadow.x, y: theme.defaultShadow.y)
            // Center the card horizontally. - This is handled by the parent container now.
            // REMOVED .frame(maxWidth: .infinity) - Was redundant with inner frame
        }
        .frame(height: 240)
    }
}

struct VendorView_Previews: PreviewProvider {
    static var previews: some View {
        VendorView(
            vendorLogoName: "vendor_logo",
            vendorName: "Roots Natural Kitchen",
            vendorLocation: "College Park, MD",
            products: [
                Product(imageName: "product1", productName: "El Jefe", priceInfo: "$13.25 or 950 Points"),
                Product(imageName: "product2", productName: "Pesto Caesar", priceInfo: "$11.75 or 850 Points"),
                Product(imageName: "product1", productName: "El Jefe", priceInfo: "$13.25 or 950 Points"),
                Product(imageName: "product2", productName: "Pesto Caesar", priceInfo: "$11.75 or 850 Points")
            ]
        )
    }
}

// MARK: - Balance Cards View
struct BalanceCardsView: View {
    let pointsAvailable: Int
    let totalPoints: Int
    let totalMoneySaved: Double
    @Environment(\.theme) private var theme: any Theme
    
    var body: some View {
        HStack(spacing: 12) {
            // Points Available Card
            BalanceCardView(
                title: "Points Available",
                value: "\(pointsAvailable)"
            )
            
            // Lifetime Points Card
            BalanceCardView(
                title: "Lifetime Points",
                value: "\(totalPoints)"
            )
            
            // Savings Card
            BalanceCardView(
                title: "Savings",
                value: String(format: "$%.2f", totalMoneySaved)
            )
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Balance Card View
struct BalanceCardView: View {
    let title: String
    let value: String
    @Environment(\.theme) private var theme: any Theme
    
    var body: some View {
        VStack(spacing: 8) {
            Text(value)
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(theme.primaryText)
                .multilineTextAlignment(.center)
            
            Text(title)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(theme.primaryText)
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, minHeight: 90)
        .background(
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .fill(theme.background)
                .shadow(color: theme.defaultShadow.color, radius: theme.defaultShadow.radius, x: theme.defaultShadow.x, y: theme.defaultShadow.y)
        )
    }
}

// MARK: - My Products View
struct MyProductsView: View {
    @Environment(\.theme) private var theme: any Theme
    @EnvironmentObject var authManager: AuthenticationManager
    @State private var userProducts: [UserProduct] = []
    @State private var isLoading = false
    @Binding var shouldRefresh: Bool // Binding to trigger refresh
    
    var body: some View {
        Group {
            if isLoading {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Loading your products...")
                        .font(.system(size: 14))
                        .foregroundColor(theme.secondaryText)
                }
                .frame(height: 60)
            } else if userProducts.isEmpty {
                HStack {
                    
                    Text("Once you redeem an offer, it will be listed here.")
                        .font(.system(size: 14))
                        .foregroundColor(theme.secondaryText)
                }
                .frame(height: 60)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(userProducts.prefix(5)) { product in // Show max 5 products
                            UserProductCardView(product: product, authManager: authManager)
                        }
                    }
                    .padding(.vertical, 8)
                }
            }
        }
        .onChange(of: shouldRefresh) { oldValue, newValue in
            if newValue {
                fetchUserProducts()
                shouldRefresh = false // Reset after refresh
            }
        }
        .onAppear {
            fetchUserProducts()
        }
    }
    
    private func fetchUserProducts() {
        guard !isLoading else { return }
        
        isLoading = true
        
        let affiliateAPI = AffiliateAPI(httpClient: authManager.httpClient)
        
        affiliateAPI.fetchUserProducts(activeOnly: true) { result in
            DispatchQueue.main.async {
                self.isLoading = false
                
                switch result {
                case .success(let products):
                    self.userProducts = products
                case .failure(let error):
                    print("Failed to fetch user products: \(error.localizedDescription)")
                    // Keep existing products if fetch fails
                }
            }
        }
    }
}

// MARK: - User Product Card View
struct UserProductCardView: View {
    let product: UserProduct
    let authManager: AuthenticationManager
    @Environment(\.theme) private var theme: any Theme
    
    var body: some View {
        VStack(spacing: 0) {
            // Card with product image - fixed position
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white)
                    .frame(width: 90, height: 90)
                    .shadow(color: theme.defaultShadow.color, radius: theme.defaultShadow.radius, x: theme.defaultShadow.x, y: theme.defaultShadow.y)
                
                // Product image - try to use imageName first, fallback to productImage
                Group {
                    if let imageName = product.imageName, !imageName.isEmpty {
                        // First try local asset
                        Image(imageName)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 65, height: 65)
                    } else if let productImage = product.productImage, !productImage.isEmpty {
                        // Then try remote URL - handle both full URLs and Django media paths
                        let imageURL: URL? = {
                            if productImage.hasPrefix("http") {
                                return URL(string: productImage)
                            } else if productImage.hasPrefix("/media/") || productImage.hasPrefix("media/") {
                                // Django media file - construct full URL using the same base as API calls
                                let baseURL = AppConfig.apiBaseURL.replacingOccurrences(of: "/api", with: "")
                                let fullPath = productImage.hasPrefix("/") ? productImage : "/\(productImage)"
                                return URL(string: baseURL + fullPath)
                            } else {
                                // Try as-is in case it's a relative path
                                return URL(string: productImage)
                            }
                        }()
                        
                        AsyncImage(url: imageURL) { phase in
                            switch phase {
                            case .success(let image):
                                image
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 65, height: 65)
                            case .failure(_):
                                // Fallback to category icon on image load failure
                                Image(systemName: categoryIcon(for: product.category))
                                    .font(.system(size: 30))
                                    .foregroundColor(theme.secondaryText.opacity(0.6))
                                    .frame(width: 65, height: 65)
                            case .empty:
                                // Loading placeholder
                                ProgressView()
                                    .scaleEffect(0.8)
                                    .frame(width: 65, height: 65)
                            @unknown default:
                                // Unknown case fallback
                                Image(systemName: categoryIcon(for: product.category))
                                    .font(.system(size: 30))
                                    .foregroundColor(theme.secondaryText.opacity(0.6))
                                    .frame(width: 65, height: 65)
                            }
                        }
                    } else {
                        // Fallback icon based on category
                        Image(systemName: categoryIcon(for: product.category))
                            .font(.system(size: 30))
                            .foregroundColor(theme.secondaryText.opacity(0.6))
                            .frame(width: 65, height: 65)
                    }
                }
                
                // Status indicator overlay for non-active products
                if product.status.lowercased() != "active" {
                    VStack {
                        HStack {
                            Spacer()
                            Circle()
                                .fill(statusColor(for: product.status))
                                .frame(width: 12, height: 12)
                                .overlay(
                                    Circle()
                                        .stroke(Color.white, lineWidth: 1.5)
                                )
                        }
                        Spacer()
                    }
                    .padding(6)
                }
            }
            
            // Fixed height container for text to prevent icon movement
            VStack {
                Text(product.productName)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(theme.primaryText)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .frame(width: 90)
                
                // Show expiry info if product will expire soon
                if let daysUntilExpiry = product.daysUntilExpiry {
                    if daysUntilExpiry <= 30 && daysUntilExpiry > 0 {
                        Text("Expires in \(daysUntilExpiry)d")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.orange)
                            .lineLimit(1)
                    } else if daysUntilExpiry <= 0 {
                        Text("Expired")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.red)
                            .lineLimit(1)
                    }
                }
            }
            .frame(height: 50) // Increased height to accommodate expiry text
            .padding(.top, 8)
        }
    }
    
    private func categoryIcon(for category: String) -> String {
        switch category.lowercased() {
        case "nutrition", "food":
            return "leaf"
        case "fitness":
            return "dumbbell"
        case "health", "wellness":
            return "heart"
        case "beauty":
            return "sparkles"
        case "supplements":
            return "pills"
        default:
            return "bag"
        }
    }
    
    private func statusColor(for status: String) -> Color {
        switch status.lowercased() {
        case "inactive":
            return Color.gray
        case "expired":
            return Color.red
        default:
            return Color.green
        }
    }
}


// MARK: - Balance View
struct BalanceView: View {
  let pointsAvailable: Int
  let totalPoints: Int
  let totalMoneySaved: Double
  @Environment(\.theme) private var theme: any Theme
  
  var body: some View {
    GeometryReader { geo in
      let width = geo.size.width
      let height = geo.size.height
      
      // Card background with rounded corners and a shadow
      Rectangle()
        .fill(theme.background)
        .cornerRadius(height * 0.087)
        .shadow(color: theme.defaultShadow.color,
                radius: theme.defaultShadow.radius, y: theme.defaultShadow.y)
        .overlay(
          HStack(spacing: 0) {
            // Points Available Section
            VStack(spacing: height * 0.02) {
              Text("\(pointsAvailable)")
                .font(.system(size: height * 0.28))
              Text("Points Available")
                .font(.system(size: 17))
                .foregroundColor(theme.primaryText)
            }
            .frame(width: width * 0.4)
            
            // Left section (Total Points Generated)
            VStack(spacing: height * 0.02) {
              Text("\(totalPoints)")
                .font(.system(size: 20))
                .foregroundColor(theme.primaryText)
              Text("Lifetime Points")
                .font(.system(size: 12))
                .foregroundColor(theme.primaryText)
            }
            .frame(width: width * 0.3)
            
            // Right section (Total Money Saved)
            VStack(spacing: height * 0.02) {
              Text(String(format: "$%.2f", totalMoneySaved))
                .font(.system(size: 20))
                .foregroundColor(theme.primaryText)
              Text("Savings")
                .font(.system(size: 12))
                .foregroundColor(theme.primaryText)
            }
            .frame(width: width * 0.3)
          }
          .padding(.horizontal, width * 0.05)
        )
    }
    .aspectRatio(400/120, contentMode: .fit)
  }
}

struct BalanceView_Previews: PreviewProvider {
  static var previews: some View {
      VStack(spacing: 20) {
          Text("New Balance Cards")
          BalanceCardsView(pointsAvailable: 1564, totalPoints: 10564, totalMoneySaved: 151.00)
              .environment(\.theme, LiquidGlassTheme())
          
          Text("My Products Section")
          MyProductsView(shouldRefresh: .constant(false)) // Use constant binding for preview
              .environment(\.theme, LiquidGlassTheme())
          
          Text("Original Balance View")
          BalanceView(pointsAvailable: 1564, totalPoints: 10564, totalMoneySaved: 151.00)
              .environment(\.theme, LiquidGlassTheme())
      }
      .padding()
      .background(Color.gray.opacity(0.2))
  }
}

