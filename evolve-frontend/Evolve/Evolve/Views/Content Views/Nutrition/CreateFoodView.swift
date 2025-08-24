import SwiftUI

struct CreateFoodView: View {
    @EnvironmentObject var authManager: AuthenticationManager
    @Environment(\.dismiss) var dismiss
    
    let onDismiss: (() -> Void)?
    
    init(onDismiss: (() -> Void)? = nil) {
        self.onDismiss = onDismiss
    }
    
    // State for all the input fields
    @State private var name: String = ""
    @State private var barcode: String = ""
    @State private var calories: String = ""
    @State private var protein: String = ""
    @State private var carbs: String = ""
    @State private var fat: String = ""
    
    // Optional fields
    @State private var calcium: String = ""
    @State private var iron: String = ""
    @State private var potassium: String = ""
    @State private var vitaminA: String = ""
    @State private var vitaminC: String = ""
    @State private var vitaminB12: String = ""
    
    @State private var showOptionalFields = false
    
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    // Validation
    private var isFormValid: Bool {
        !name.isEmpty &&
        !calories.isEmpty && Double(calories) != nil &&
        !protein.isEmpty && Double(protein) != nil &&
        !carbs.isEmpty && Double(carbs) != nil &&
        !fat.isEmpty && Double(fat) != nil
    }

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Required Information")) {
                    TextField("Food Name (e.g., My Special Sandwich)", text: $name)
                    TextField("Calories (kcal)", text: $calories)
                        .keyboardType(.decimalPad)
                    TextField("Protein (g)", text: $protein)
                        .keyboardType(.decimalPad)
                    TextField("Carbohydrates (g)", text: $carbs)
                        .keyboardType(.decimalPad)
                    TextField("Fat (g)", text: $fat)
                        .keyboardType(.decimalPad)
                }

                Section {
                    Toggle(isOn: $showOptionalFields.animation()) {
                        Text("Add Micronutrients (Optional)")
                    }
                    
                    if showOptionalFields {
                        TextField("Calcium (mg)", text: $calcium)
                            .keyboardType(.decimalPad)
                        TextField("Iron (mg)", text: $iron)
                            .keyboardType(.decimalPad)
                        TextField("Potassium (mg)", text: $potassium)
                            .keyboardType(.decimalPad)
                        TextField("Vitamin A (mcg)", text: $vitaminA)
                            .keyboardType(.decimalPad)
                        TextField("Vitamin C (mg)", text: $vitaminC)
                            .keyboardType(.decimalPad)
                        TextField("Vitamin B12 (mcg)", text: $vitaminB12)
                            .keyboardType(.decimalPad)
                    }
                }
                
                Section(header: Text("Barcode (Optional)")) {
                    TextField("Scan or Enter Barcode ID", text: $barcode)
                }
                
                if let errorMessage = errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundColor(.red)
                    }
                }

                Section {
                    Button(action: createFood) {
                        HStack {
                            Spacer()
                            if isLoading {
                                ProgressView()
                            } else {
                                Text("Save Custom Food")
                            }
                            Spacer()
                        }
                    }
                    .disabled(!isFormValid || isLoading)
                }
            }
            .navigationTitle("Create Custom Food")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        if let onDismiss = onDismiss {
                            onDismiss()
                        } else {
                        dismiss()
                        }
                    }
                }
            }
        }
    }
    
    func createFood() {
        guard isFormValid else {
            errorMessage = "Please fill out all required fields with valid numbers."
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        // Construct the payload using the Codable struct
        let payload = CreateCustomFoodPayload(
            name: name,
            calories: Double(calories)!,
            protein: Double(protein)!,
            carbs: Double(carbs)!,
            fat: Double(fat)!,
            barcodeId: barcode.isEmpty ? nil : barcode,
            calcium: Double(calcium),
            iron: Double(iron),
            potassium: Double(potassium),
            vitaminA: Double(vitaminA),
            vitaminC: Double(vitaminC),
            vitaminB12: Double(vitaminB12)
        )

        Task {
            do {
                let _: CustomFood = try await authManager.httpClient.request(
                    endpoint: "/custom-foods/",
                    method: "POST",
                    body: payload,
                    requiresAuth: true
                )
                
                await MainActor.run {
                    isLoading = false
                    if let onDismiss = onDismiss {
                        onDismiss()
                    } else {
                    dismiss()
                    }
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    errorMessage = "Failed to save food: \(error.localizedDescription)"
                }
            }
        }
    }
}

// A placeholder struct for the response if needed, for now we can decode to a dictionary or an empty response
struct CustomFood: Codable, Identifiable {
    let id: Int
    // Add other fields if you need to use the response object
}

// Struct for the request payload
struct CreateCustomFoodPayload: Codable {
    let name: String
    let calories: Double
    let protein: Double
    let carbs: Double
    let fat: Double
    let barcodeId: String?
    let calcium: Double?
    let iron: Double?
    let potassium: Double?
    let vitaminA: Double?
    let vitaminC: Double?
    let vitaminB12: Double?
    
    enum CodingKeys: String, CodingKey {
        case name, calories, protein, carbs, fat
        case barcodeId = "barcode_id"
        case calcium, iron, potassium
        case vitaminA = "vitamin_a"
        case vitaminC = "vitamin_c"
        case vitaminB12 = "vitamin_b12"
    }
}

struct CreateFoodView_Previews: PreviewProvider {
    static var previews: some View {
        CreateFoodView()
            .environmentObject(AuthenticationManager())
    }
}
