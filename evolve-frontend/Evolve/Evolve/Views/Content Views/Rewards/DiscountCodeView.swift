import SwiftUI

struct DiscountCodeView: View {
    let promotion: AffiliatePromotion
    // Assuming the discount code string is passed directly.
    // If the full DiscountCode object is needed, adjust the type.
    let discountCode: String
    let onMarkAsRedeemed: () -> Void // Closure to call the API

    @Environment(\.presentationMode) var presentationMode
    @State private var isRedeeming = false
    @State private var errorMessage: String? = nil
    @Environment(\.theme) private var theme: any Theme

    var body: some View {
        NavigationView { // Use NavigationView for title and potential future navigation
            VStack(spacing: 20) {
                Spacer()

                // Promotion Info
                VStack {
                    Text("Your Discount Code For:")
                        .font(.system(size: 17))
                    Text(promotion.title)
                        .font(.system(size: 22))
                        .multilineTextAlignment(.center)
                    Text("at \(promotion.affiliate.name)")
                        .font(.system(size: 15))
                        .foregroundColor(theme.secondaryText)
                }
                .padding(.horizontal)

                // Discount Code Display
                Text(discountCode)
                    .font(.system(size: 36))
                    .padding()
                    .background(theme.secondaryText.opacity(0.1))
                    .cornerRadius(10)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(theme.secondaryText.opacity(0.3), lineWidth: 1)
                    )
                    .onTapGesture {
                        // Copy to clipboard
                        UIPasteboard.general.string = discountCode
                        // Optionally show feedback like a toast message
                    }
                Text("(Tap code to copy)")
                    .font(.system(size: 12))
                    .foregroundColor(theme.secondaryText)


                Spacer()

                // Error Message
                if let errorMsg = errorMessage {
                    Text("Error: \(errorMsg)")
                        .foregroundColor(.red)
                        .font(.system(size: 12))
                        .padding(.horizontal)
                }

                // Redeem Button
                Button(action: {
                    isRedeeming = true
                    errorMessage = nil
                    onMarkAsRedeemed() // Call the provided closure
                    // The closure should handle the API call and dismiss logic
                }) {
                    HStack {
                        if isRedeeming {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        }
                        Text(isRedeeming ? "Redeeming..." : "Mark as Redeemed")
                            .font(.system(size: 17))
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(isRedeeming ? theme.secondaryText : theme.accent) // Change color when redeeming
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                .disabled(isRedeeming) // Disable button while redeeming
                .padding(.horizontal)
                .padding(.bottom)

            }
            .navigationTitle("Redeem Promotion")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        presentationMode.wrappedValue.dismiss()
                    }
                    .font(.system(size: 17))
                }
            }
        }
    }
}
//
//// Sample data for Preview
//struct DiscountCodeView_Previews: PreviewProvider {
//    static let sampleAffiliate = Affiliate(
//        id: UUID(),
//        name: "Preview Vendor",
//        contact_email: nil, contact_phone: nil, logo: nil, website: nil, location: "Online", date_joined: nil, is_active: true
//    )
//    static let samplePromotion = AffiliatePromotion(
//        id: UUID(),
//        affiliate: sampleAffiliate,
//        title: "Free Coffee",
//        description: "Get a free coffee.",
//        originalPrice: "$5.00", pointValue: 50, productImage: nil, start_date: nil, end_date: nil, is_active: true, assigned_users: nil, discount_code: "PREVIEW123" // Add sample code
//    )
//
//    static var previews: some View {
//        DiscountCodeView(
//            promotion: samplePromotion,
//            discountCode: "PREVIEW123",
//            onMarkAsRedeemed: {
//                print("Mark as redeemed tapped in preview.")
//                // Simulate API delay and success/failure for preview
//                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
//                    // In a real scenario, you'd update state based on API result
//                }
//            }
//        )
//    }
//} 
