import SwiftUI
import Combine // For ObservableObject and Published

@MainActor
class BarcodeScannerViewModel: ObservableObject {
    // MARK: - Published Properties for UI Updates
    @Published var scannedBarcode: String? = nil
    @Published var fetchedProduct: FoodProduct? = nil  // Changed from OpenFoodFactsProduct to FoodProduct
    @Published var scannedProduct: FoodProduct? = nil  // For sheet presentation
    @Published var isLoading: Bool = false
    @Published var errorMessage: String? = nil
    @Published var showScannerSheet: Bool = false

    // MARK: - Services
    private let foodSearchAPI: FoodSearchAPI

    // MARK: - Initialization
    init(authenticationManager: AuthenticationManager) {
        self.foodSearchAPI = FoodSearchAPI(httpClient: AuthenticatedHTTPClient(authenticationManager: authenticationManager))
    }

    // MARK: - Public Methods
    func handleScannedBarcode(
        _ barcode: String,
        onProductFound: @escaping (FoodProduct) -> Void,
        onAlcoholFound: @escaping (AlcoholicBeverage) -> Void,
        onCaffeineFound: @escaping (CaffeineProduct) -> Void,
        onMappedAlcoholFound: @escaping (FoodProduct, AlcoholicBeverage) -> Void,
        onMappedCaffeineFound: @escaping (FoodProduct, CaffeineProduct) -> Void,
        onProductNotFound: @escaping () -> Void
    ) {
        print("BarcodeScannerViewModel: Handling scanned barcode - \(barcode)")
        self.scannedBarcode = barcode
        self.isLoading = true
        self.errorMessage = nil
        self.fetchedProduct = nil // Clear previous product
        self.scannedProduct = nil // Clear previous scanned product
        self.showScannerSheet = false // Dismiss scanner sheet

        Task {
            do {
                let result = try await foodSearchAPI.fetchProductByBarcode(barcode: barcode)
                
                await MainActor.run {
                    switch result {
                    case .food(let product):
                        self.fetchedProduct = product
                        self.scannedProduct = product // Set for sheet presentation
                        print("BarcodeScannerViewModel: Successfully fetched food product '\(product.productName ?? "N/A")'")
                        onProductFound(product)
                        
                    case .alcohol(let alcoholBeverage):
                        print("BarcodeScannerViewModel: Successfully fetched alcohol product '\(alcoholBeverage.name)'")
                        onAlcoholFound(alcoholBeverage)
                        
                    case .caffeine(let caffeineProduct):
                        print("BarcodeScannerViewModel: Successfully fetched caffeine product '\(caffeineProduct.name)'")
                        onCaffeineFound(caffeineProduct)
                        
                    case .mappedAlcohol(let foodProduct, let alcoholBeverage):
                        print("BarcodeScannerViewModel: Mapped food product '\(foodProduct.productName ?? "N/A")' to alcohol product '\(alcoholBeverage.name)'")
                        onMappedAlcoholFound(foodProduct, alcoholBeverage)
                        
                    case .mappedCaffeine(let foodProduct, let caffeineProduct):
                        print("BarcodeScannerViewModel: Mapped food product '\(foodProduct.productName ?? "N/A")' to caffeine product '\(caffeineProduct.name)'")
                        onMappedCaffeineFound(foodProduct, caffeineProduct)
                    }
                }
            } catch {
                print("BarcodeScannerViewModel: Product not found - \(error.localizedDescription)")
                await MainActor.run {
                    self.errorMessage = nil // Don't show error, let the UI handle it gracefully
                    onProductNotFound()
                }
            }
            self.isLoading = false
        }
    }

    func clearProductDetails() {
        self.scannedBarcode = nil
        self.fetchedProduct = nil
        self.scannedProduct = nil
        self.errorMessage = nil
        self.isLoading = false
    }
}
