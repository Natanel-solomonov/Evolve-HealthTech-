import SwiftUI

struct EditWorkoutExerciseView: View {
    @Binding var workoutExercise: WorkoutExercise
    @Environment(\.presentationMode) var presentationMode

    // Local state for text fields to handle string input
    @State private var setsString: String
    @State private var repsString: String
    @State private var weightString: String
    @Environment(\.theme) private var theme: any Theme

    init(workoutExercise: Binding<WorkoutExercise>) {
        self._workoutExercise = workoutExercise
        // Initialize local state strings from the binding
        _setsString = State(initialValue: "\(workoutExercise.wrappedValue.sets ?? 0)")
        _repsString = State(initialValue: "\(workoutExercise.wrappedValue.reps ?? 0)")
        _weightString = State(initialValue: workoutExercise.wrappedValue.weight.map { String($0) } ?? "")
    }

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Edit Details")) {
                    HStack {
                        Text("Sets:")
                        TextField("Sets", text: $setsString)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                    }
                    HStack {
                        Text("Reps:")
                        TextField("Reps", text: $repsString)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                    }
                    HStack {
                        Text("Weight (lbs):")
                        TextField("Weight", text: $weightString)
                            .keyboardType(.decimalPad) // Use decimal pad for weight
                            .multilineTextAlignment(.trailing)
                    }
                }
            }
            .navigationTitle("Edit Exercise")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        // Update the binding with new values, converting from String
                        workoutExercise.sets = Int(setsString) ?? workoutExercise.sets
                        workoutExercise.reps = Int(repsString) ?? workoutExercise.reps
                        // Handle optional weight: nil if string is empty, otherwise convert
                        if weightString.isEmpty {
                            workoutExercise.weight = nil
                        } else {
                            workoutExercise.weight = Int(weightString) ?? workoutExercise.weight
                        }
                        presentationMode.wrappedValue.dismiss()
                    }
                    .foregroundColor(theme.accent)
                }
            }
        }
        .font(.system(size: 17))
    }
}

struct EditWorkoutExerciseView_Previews: PreviewProvider {
    // Helper struct to provide a stateful environment for the preview
    private struct PreviewWrapper: View {
        @State private var workoutExercise = WorkoutExercise(
            id: UUID(),
            exercise: Exercise(
                id: UUID(),
                name: "Bench Press",
                force: "push",
                level: "intermediate",
                mechanic: "compound",
                equipment: "barbell",
                isCardio: false,
                primaryMuscles: ["Chest"],
                secondaryMuscles: ["Shoulders", "Triceps"],
                instructions: ["Lie down on a flat bench...", "Press the weight up..."],
                category: "Strength",
                picture1: nil,
                picture2: nil,
                isDiagnostic: false,
                cluster: nil
            ),
            sets: 3,
            reps: 10,
            weight: 135,
            equipment: "Barbell",
            order: 1,
            time: "60s"
        )

        var body: some View {
            EditWorkoutExerciseView(workoutExercise: $workoutExercise)
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
