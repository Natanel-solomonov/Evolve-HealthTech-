import SwiftUI

struct WorkoutProgressIndicator: View {
    @Binding var workout: Workout
    @Binding var currentIndex: Int
    @Binding var currentSet: Int
    @Environment(\.theme) private var theme: any Theme
    
    private let completedColor = Color(red: 52/255, green: 211/255, blue: 153/255)
    private let largeCircleSize: CGFloat = 15
    private let smallCircleSize: CGFloat = 10

    var body: some View {
        HStack(spacing: 12) {
            ForEach(workout.workoutexercises.indices, id: \.self) { index in
                Group {
                    // Show detailed set progress only for the current, uncompleted exercise.
                    if index == currentIndex && !workout.workoutexercises[index].isCompleted {
                        HStack(spacing: 6) {
                            ForEach(1...(workout.workoutexercises[index].sets ?? 1), id: \.self) { setIndex in
                                if setIndex < currentSet {
                                    // Completed sets are filled black
                                    Circle().fill(theme.primaryText)
                                        .frame(width: smallCircleSize, height: smallCircleSize)
                                } else if setIndex == currentSet {
                                    // Current set has a thicker outline
                                    Circle().stroke(theme.primaryText, lineWidth: 2.5)
                                        .frame(width: smallCircleSize, height: smallCircleSize)
                                } else {
                                    // Incomplete sets are filled and have a shadow
                                    Circle().fill(Color(UIColor.systemGray6))
                                        .frame(width: smallCircleSize, height: smallCircleSize)
                                        .shadow(color: theme.primaryText.opacity(0.15), radius: 1.5, x: 0, y: 1)
                                }
                            }
                        }
                    } else {
                        // For all other exercises (not current, or current but completed), show a single large circle.
                        if workout.workoutexercises[index].isCompleted {
                            // Completed exercises are filled with the new green and a white checkmark.
                            ZStack {
                                Circle().fill(.green)
                                Image(systemName: "checkmark")
                                    .font(.system(size: 8))
                                    .foregroundColor(.white)
                            }
                            .frame(width: largeCircleSize, height: largeCircleSize)
                        } else {
                            // Incomplete exercises are filled and have a shadow.
                            Circle().fill(Color(UIColor.systemGray5))
                                .frame(width: largeCircleSize, height: largeCircleSize)
                                .shadow(color: theme.primaryText.opacity(0.2), radius: 2, x: 0, y: 1)
                        }
                    }
                }
                .onTapGesture {
                    // Allow tapping to navigate to a different exercise
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                        if currentIndex != index {
                            currentIndex = index
                            currentSet = 1 // Reset set count when jumping
                        }
                    }
                }
            }
        }
        .frame(height: 20) // Give the indicator a consistent height
    }
}

struct WorkoutProgressIndicator_Previews: PreviewProvider {
    private struct PreviewWrapper: View {
        static let sampleExercise = Exercise(
            id: UUID(), name: "Bench Press", force: "push", level: "intermediate", mechanic: "compound",
            equipment: "barbell", isCardio: false, primaryMuscles: ["Chest"], secondaryMuscles: ["Shoulders", "Triceps"],
            instructions: [], category: "Strength", picture1: nil, picture2: nil, isDiagnostic: false, cluster: nil
        )

        @State private var workout = Workout(
            id: UUID(),
            name: "Full Body Strength",
            description: "A comprehensive workout.",
            duration: "60 mins",
            createdAt: "2023-10-27T10:00:00Z",
            updatedAt: "2023-10-27T10:00:00Z",
            workoutexercises: [
                WorkoutExercise(id: UUID(), exercise: sampleExercise, sets: 4, reps: 10, weight: 75, equipment: "Kettlebell", order: 1, time: "90s", isCompleted: true),
                WorkoutExercise(id: UUID(), exercise: sampleExercise, sets: 3, reps: 15, weight: 0, equipment: "None", order: 2, time: "60s", isCompleted: false),
                WorkoutExercise(id: UUID(), exercise: sampleExercise, sets: 5, reps: 8, weight: 135, equipment: "Barbell", order: 3, time: "120s", isCompleted: false)
            ]
        )
        @State private var currentIndex = 1
        @State private var currentSet = 2

        var body: some View {
            VStack {
                Text("Workout Progress Indicator")
                    .font(.system(size: 17))
                    .padding(.bottom)
                WorkoutProgressIndicator(workout: $workout, currentIndex: $currentIndex, currentSet: $currentSet)
            }
            .padding()
            .background(Color.white)
            .previewLayout(.sizeThatFits)
        }
    }
    
    static var previews: some View {
        PreviewWrapper()
    }
} 
