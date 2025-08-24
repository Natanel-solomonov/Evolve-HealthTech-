import SwiftUI

struct WaterSettingsModal: View {
    @Environment(\.dismiss) var dismiss
    @Binding var waterGoal: Double
    @State private var tempWaterGoal: Double
    @State private var selectedUnit: WaterUnit = .milliliters
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    let onSave: (Double, WaterUnit) -> Void
    
    init(waterGoal: Binding<Double>, onSave: @escaping (Double, WaterUnit) -> Void) {
        self._waterGoal = waterGoal
        self._tempWaterGoal = State(initialValue: waterGoal.wrappedValue)
        self.onSave = onSave
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 8) {
                    Image(systemName: "drop.fill")
                        .font(.largeTitle)
                        .foregroundColor(.blue)
                    
                    Text("Water Settings")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text("Customize your daily water intake goal")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top)
                
                // Settings form
                VStack(spacing: 20) {
                    // Daily goal section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Daily Goal")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        // Goal input with unit conversion
                        HStack {
                            TextField("Goal", value: $tempWaterGoal, format: .number)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .keyboardType(.decimalPad)
                            
                            Text("ml")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        
                        // Preset goal buttons
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Quick Goals")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 12) {
                                ForEach(WaterGoalPreset.allCases, id: \.self) { preset in
                                    Button(action: {
                                        tempWaterGoal = preset.value
                                    }) {
                                        VStack(spacing: 4) {
                                            Text(preset.displayValue)
                                                .font(.subheadline)
                                                .fontWeight(.medium)
                                            
                                            Text(preset.description)
                                                .font(.caption2)
                                                .foregroundColor(.secondary)
                                        }
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 12)
                                        .background(
                                            RoundedRectangle(cornerRadius: 8)
                                                .fill(tempWaterGoal == preset.value ? Color.blue.opacity(0.2) : Color.gray.opacity(0.1))
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: 8)
                                                        .stroke(tempWaterGoal == preset.value ? Color.blue : Color.clear, lineWidth: 2)
                                                )
                                        )
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }
                            }
                        }
                    }
                    
                    // Display preferences section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Display Unit")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        Picker("Unit", selection: $selectedUnit) {
                            ForEach(WaterUnit.allCases, id: \.self) { unit in
                                Text(unit.displayName).tag(unit)
                            }
                        }
                        .pickerStyle(SegmentedPickerStyle())
                    }
                    
                    // Tips section
                    VStack(alignment: .leading, spacing: 8) {
                        Text("💡 Tips")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        VStack(alignment: .leading, spacing: 6) {
                            Text("• The recommended daily intake is 8 glasses (2L)")
                            Text("• Increase intake during exercise or hot weather")
                            Text("• Start your day with a glass of water")
                        }
                        .font(.caption)
                        .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.blue.opacity(0.05))
                    )
                }
                .padding(.horizontal)
                
                Spacer()
                
                // Error message
                if let errorMessage = errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundColor(.red)
                        .padding(.horizontal)
                }
                
                // Save button
                Button(action: saveSettings) {
                    HStack {
                        if isLoading {
                            ProgressView()
                                .scaleEffect(0.8)
                                .foregroundColor(.white)
                        }
                        
                        Text(isLoading ? "Saving..." : "Save Changes")
                            .font(.headline)
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(isLoading ? Color.gray : Color.blue)
                    )
                }
                .disabled(isLoading)
                .padding(.horizontal)
                .padding(.bottom)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func saveSettings() {
        guard tempWaterGoal >= 500 && tempWaterGoal <= 10000 else {
            errorMessage = "Please enter a goal between 500ml and 10L"
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        // Simulate API call delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            waterGoal = tempWaterGoal
            onSave(tempWaterGoal, selectedUnit)
            isLoading = false
            dismiss()
        }
    }
}

enum WaterUnit: String, CaseIterable {
    case milliliters = "ml"
    case fluidOunces = "fl_oz"
    case cups = "cups"
    case glasses = "glasses"
    
    var displayName: String {
        switch self {
        case .milliliters: return "ml"
        case .fluidOunces: return "fl oz"
        case .cups: return "Cups"
        case .glasses: return "Glasses"
        }
    }
    
    func convert(from ml: Double) -> Double {
        switch self {
        case .milliliters: return ml
        case .fluidOunces: return ml * 0.033814
        case .cups: return ml * 0.004227
        case .glasses: return ml / 250 // Assuming 250ml per glass
        }
    }
    
    func convertToMl(from value: Double) -> Double {
        switch self {
        case .milliliters: return value
        case .fluidOunces: return value / 0.033814
        case .cups: return value / 0.004227
        case .glasses: return value * 250
        }
    }
}

enum WaterGoalPreset: CaseIterable {
    case light
    case moderate
    case active
    case athletic
    
    var value: Double {
        switch self {
        case .light: return 1500
        case .moderate: return 2000
        case .active: return 2500
        case .athletic: return 3000
        }
    }
    
    var displayValue: String {
        return "\(Int(value))ml"
    }
    
    var description: String {
        switch self {
        case .light: return "Light"
        case .moderate: return "Standard"
        case .active: return "Active"
        case .athletic: return "Athletic"
        }
    }
}

// Preview
struct WaterSettingsModal_Previews: PreviewProvider {
    @State static var waterGoal: Double = 2000
    
    static var previews: some View {
        WaterSettingsModal(
            waterGoal: $waterGoal,
            onSave: { goal, unit in
                print("Saved goal: \(goal)ml, unit: \(unit)")
            }
        )
    }
} 