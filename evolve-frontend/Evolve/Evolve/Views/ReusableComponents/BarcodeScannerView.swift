import SwiftUI
import CodeScanner // Make sure you have added this Swift Package

struct BarcodeScannerView: View {
    @ObservedObject var viewModel: BarcodeScannerViewModel
    @Environment(\.dismiss) var dismiss // To dismiss the scanner view itself
    let onProductFound: (FoodProduct) -> Void
    let onAlcoholFound: (AlcoholicBeverage) -> Void
    let onCaffeineFound: (CaffeineProduct) -> Void
    let onMappedAlcoholFound: (FoodProduct, AlcoholicBeverage) -> Void
    let onMappedCaffeineFound: (FoodProduct, CaffeineProduct) -> Void
    let onProductNotFound: () -> Void

    // For haptic feedback
    private let hapticFeedbackGenerator = UINotificationFeedbackGenerator()

    var body: some View {
        NavigationView { // Provides a navigation bar for title and cancel button
            ZStack {
                CodeScannerView(
                    codeTypes: [.ean8, .ean13, .upce, .qr, .code128, .gs1DataBar], // Common food barcodes
                    scanMode: .once, // Scan once then process
                    simulatedData: "0123456789012", // For testing in simulator
                    completion: handleScan
                )
                .edgesIgnoringSafeArea(.all)

                // Viewfinder Overlay
                VStack {
                    Spacer()
                    Text("Align barcode within the frame")
                        .font(.system(size: 14))
                        .padding(8)
                        .background(Color.black.opacity(0.6))
                        .foregroundColor(.white)
                        .cornerRadius(8)
                        .padding(.bottom, 20)

                    RoundedRectangle(cornerRadius: 25)
                        .stroke(Color.white.opacity(0.8), lineWidth: 3)
                        .frame(width: 280, height: 180) // Adjust size as needed
                        // .blendMode(.overlay) // Optional: for a different visual effect

                    Spacer()
                    Spacer() // Add more spacer to push viewfinder up a bit from center if desired
                }
                .edgesIgnoringSafeArea(.all) // Allow overlay to use full space if needed for alignment


                // Top instruction text (retained from previous version)
                VStack {
                    Text("Scan Food Barcode")
                        .font(.system(size: 22))
                        .fontWeight(.semibold)
                        .padding()
                        .background(Color.black.opacity(0.6))
                        .foregroundColor(.white)
                        .cornerRadius(10)
                        .padding(.top, 50)
                    Spacer()
                }
            }
            .navigationBarTitleDisplayMode(.inline) // No title text, just for the bar
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        viewModel.showScannerSheet = false
                        dismiss()
                    }
                    .foregroundColor(.white)
                    .font(.system(size: 17))
                }
            }
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarBackground(Material.thin, for: .navigationBar)
        }
        .accentColor(.white)
        .onAppear {
            hapticFeedbackGenerator.prepare() // Prepare the haptic engine
        }
    }

    private func handleScan(result: Result<ScanResult, ScanError>) {
        switch result {
        case .success(let scanResult):
            print("BarcodeScannerView: Scan successful - \(scanResult.string)")
            hapticFeedbackGenerator.notificationOccurred(.success) // Haptic feedback for success
            viewModel.handleScannedBarcode(
                scanResult.string,
                onProductFound: onProductFound, 
                onAlcoholFound: onAlcoholFound,
                onCaffeineFound: onCaffeineFound,
                onMappedAlcoholFound: onMappedAlcoholFound,
                onMappedCaffeineFound: onMappedCaffeineFound,
                onProductNotFound: onProductNotFound
            )
        case .failure(let error):
            print("BarcodeScannerView: Scan failed - \(error.localizedDescription)")
            hapticFeedbackGenerator.notificationOccurred(.error) // Haptic feedback for error
            viewModel.errorMessage = "Scan failed: \(error.localizedDescription)"
            viewModel.showScannerSheet = false 
        }
    }
}

// MARK: - Preview
struct BarcodeScannerView_Previews: PreviewProvider {
    static var previews: some View {
        let mockAuthManager = AuthenticationManager()
        let mockViewModel = BarcodeScannerViewModel(authenticationManager: mockAuthManager)
        mockViewModel.showScannerSheet = true 
        return BarcodeScannerView(
            viewModel: mockViewModel,
            onProductFound: { _ in },
            onAlcoholFound: { _ in },
            onCaffeineFound: { _ in },
            onMappedAlcoholFound: { _, _ in },
            onMappedCaffeineFound: { _, _ in },
            onProductNotFound: { }
        )
    }
} 