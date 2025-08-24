import SwiftUI

struct RepsAndWeightPickerView: View {
    @Binding var workoutExercise: WorkoutExercise
    @Environment(\.presentationMode) var presentationMode

    // Local state for the pickers, initialized from the binding
    @State private var selectedReps: Int
    @State private var selectedWeight: Int
    @Environment(\.theme) private var theme: any Theme

    // Define the ranges for the pickers
    private let repRange = 1...50
    private let weightRange = Array(stride(from: 5, through: 300, by: 1))

    init(workoutExercise: Binding<WorkoutExercise>) {
        self._workoutExercise = workoutExercise
        _selectedReps = State(initialValue: workoutExercise.wrappedValue.reps ?? 10)
        _selectedWeight = State(initialValue: workoutExercise.wrappedValue.weight ?? 50)
    }

    var body: some View {
        VStack(spacing: 0) {
            // MARK: - Header
            VStack {
                Text(workoutExercise.exercise.name)
                    .font(.system(size: 22))
                    .fontWeight(.bold)
                Text("\(workoutExercise.sets ?? 0) Sets")
                    .font(.system(size: 15))
                    .foregroundColor(theme.secondaryText)
            }
            .padding()

            Divider()

            // MARK: - Pickers
            HStack {
                // Reps Picker
                Picker("Reps", selection: $selectedReps) {
                    ForEach(repRange, id: \.self) { rep in
                        Text("\(rep) reps").tag(rep)
                    }
                }
                .pickerStyle(.wheel)
                .frame(width: 150)
                .clipped()

                // Weight Picker
                Picker("Weight", selection: $selectedWeight) {
                    ForEach(weightRange, id: \.self) { weight in
                        Text("\(weight) lbs").tag(weight)
                    }
                }
                .pickerStyle(.wheel)
                .frame(width: 150)
                .clipped()
            }
            .padding(.vertical)

            Spacer()

            // MARK: - Save Button
            Button(action: {
                // Update the binding with the selected values
                workoutExercise.reps = selectedReps
                workoutExercise.weight = selectedWeight
                presentationMode.wrappedValue.dismiss()
            }) {
                Text("Save")
                    .font(.system(size: 17))
                    .fontWeight(.bold)
                    .foregroundColor(theme.background)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(theme.primaryText)
                    .cornerRadius(15)
            }
            .padding()
        }
        .presentationDetents([.height(400)]) // Give the sheet a fixed height
        .presentationDragIndicator(.visible)
    }
}

// MARK: - Preview
struct RepsAndWeightPickerView_Previews: PreviewProvider {
    // A stateful wrapper for the preview
    private struct PreviewWrapper: View {
        @State private var workoutExercise = WorkoutExercise(
            id: UUID(),
            exercise: Exercise(
                id: UUID(), name: "KB Double Swings", force: nil, level: "Beginner",
                mechanic: nil, equipment: "Kettlebell", isCardio: true, primaryMuscles: ["Glutes"],
                secondaryMuscles: [], instructions: [], category: "Strength", picture1: nil, picture2: nil,
                isDiagnostic: false, cluster: nil
            ),
            sets: 4, reps: 10, weight: 75, equipment: "Kettlebell", order: 1, time: nil
        )

        var body: some View {
            RepsAndWeightPickerView(workoutExercise: $workoutExercise)
        }
    }

    static var previews: some View {
        VStack {
            Text("Legacy Theme")
            PreviewWrapper()
                .liquidGlassTheme()
            
            Text("Liquid Glass Theme")
        PreviewWrapper()
                .environment(\.theme, LiquidGlassTheme())
        }
    }
} 