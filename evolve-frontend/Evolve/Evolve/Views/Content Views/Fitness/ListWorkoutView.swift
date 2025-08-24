import SwiftUI

struct ListWorkoutView: View {
    @Binding var workout: Workout
    @State private var showingEditExerciseSheet = false
    @State private var exerciseToEdit: Binding<WorkoutExercise>? = nil
    @Environment(\.theme) private var theme: any Theme

    private func formattedEquipment(for exercise: WorkoutExercise) -> String {
        let equipment = exercise.equipment ?? exercise.exercise.equipment
        if equipment.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == "none" {
            return "No Equipment"
        }
        // Proper capitalization for equipment names
        return equipment.capitalized
    }
    
    // Get muscle image name based on primary muscle
    private func muscleImageName(for exercise: WorkoutExercise) -> String? {
        return exercise.exercise.primaryMuscles.first?.capitalized
    }
    
    // Format exercise details
    private func exerciseDetails(for exercise: WorkoutExercise) -> String {
        if exercise.exercise.isCardio {
            return exercise.time ?? "Duration"
        } else {
            let sets = exercise.sets ?? 3
            let reps = exercise.reps ?? 10
            if let weight = exercise.weight, weight > 0 {
                return "\(sets) sets × \(reps) reps × \(weight) lbs"
            } else {
                return "\(sets) sets × \(reps) reps"
            }
        }
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Grid background
                GridBackground()
                
                // Top solid color gradient with Fitness color
                TopSolidColor(color: Color("Fitness"))
                    .frame(height: geometry.size.height * 0.6)
                    .frame(maxHeight: .infinity, alignment: .top)
                    .ignoresSafeArea()
                
        VStack(spacing: 0) {
            List {
                ForEach($workout.workoutexercises) { $workoutExercise in
                            ExerciseCard(
                                workoutExercise: $workoutExercise,
                                muscleImageName: muscleImageName(for: $workoutExercise.wrappedValue),
                                details: exerciseDetails(for: $workoutExercise.wrappedValue),
                                equipment: formattedEquipment(for: $workoutExercise.wrappedValue),
                                onTap: {
                            self.exerciseToEdit = $workoutExercise
                            self.showingEditExerciseSheet = true
                                },
                                onToggleComplete: {
                                    $workoutExercise.wrappedValue.isCompleted.toggle()
                                },
                                onDelete: {
                                    if let index = workout.workoutexercises.firstIndex(where: { $0.id == $workoutExercise.wrappedValue.id }) {
                                        workout.workoutexercises.remove(at: index)
                                        updateExerciseOrders()
                                    }
                                }
                            )
                            .padding(.vertical, 4)
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                        }
                        .onMove(perform: moveExercises)
                        .onDelete(perform: delete)
                    }
                    .listStyle(PlainListStyle())
                    .scrollContentBackground(.hidden)
                    .contentMargins(.top, 120) // Space for top controls
                }
            }
        }
        .sheet(item: $exerciseToEdit) { exerciseBinding in
            EditWorkoutExerciseView(workoutExercise: exerciseBinding)
        }
    }
    
    func delete(at offsets: IndexSet) {
        workout.workoutexercises.remove(atOffsets: offsets)
        updateExerciseOrders()
    }
    
    // MARK: - Drag and Drop Functions
    
    private func moveExercises(from source: IndexSet, to destination: Int) {
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
            workout.workoutexercises.move(fromOffsets: source, toOffset: destination)
            updateExerciseOrders()
        }
        
        // Add haptic feedback for successful reorder
        Haptic.light.play()
    }
    
    private func updateExerciseOrders() {
        // Update the order property of each exercise to match their new positions
        for (index, _) in workout.workoutexercises.enumerated() {
            workout.workoutexercises[index].order = index + 1
        }
    }
}

// MARK: - Exercise Card (styled like Activity Cards)
struct ExerciseCard: View {
    @Binding var workoutExercise: WorkoutExercise
    let muscleImageName: String?
    let details: String
    let equipment: String
    let onTap: () -> Void
    let onToggleComplete: () -> Void
    let onDelete: () -> Void
    
    @Environment(\.theme) private var theme: any Theme
    @State private var showingMenu = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 12) {
                // Left muscle image - aligned with exercise info
                Group {
                    if let imageName = muscleImageName, !imageName.isEmpty {
                        Image(imageName)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 64, height: 64)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    } else {
                        // Fallback placeholder for missing images
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: 64, height: 64)
                            .overlay(
                                Image(systemName: "dumbbell")
                                    .foregroundColor(.gray)
                                    .font(.system(size: 16))
                            )
                    }
                }
                
                // Content - vertical stack
                VStack(alignment: .leading, spacing: 6) {
                    // Exercise name (up to 2 lines)
                    Text(workoutExercise.exercise.name)
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(theme.primaryText)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    
                    // Exercise details (sets/reps/weight or time)
                    Text(details)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(theme.secondaryText)
                    
                    // Equipment tag
                    HStack {
                        Text(equipment)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 4)
                            .background(
                                Capsule()
                                    .fill(Color("Fitness"))
                            )
                        Spacer()
                    }
                }
                
                Spacer()
                
                // Right side: Drag handle, Three dots menu and completion status
                VStack(spacing: 4) {
                    // Drag handle at the top
                    Image(systemName: "line.3.horizontal")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(theme.secondaryText.opacity(0.6))
                        .frame(width: 30, height: 20)
                    
                    // Three dots menu 
                    // Button(action: { showingMenu = true }) {
                    //     Image(systemName: "ellipsis")
                    //         .font(.system(size: 16, weight: .medium))
                    //         .foregroundColor(theme.secondaryText)
                    //         .frame(width: 30, height: 30)
                    //         .background(Circle().fill(Color.clear))
                    // }
                    
                    // Completion checkmark below the three dots
                    if workoutExercise.isCompleted {
                        ZStack {
                            Circle()
                                .fill(Color.green)
                                .frame(width: 20, height: 20)
                            
                            Image(systemName: "checkmark")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.white)
                        }
                    } else {
                        // Invisible spacer to maintain consistent layout
                        Circle()
                            .fill(Color.clear)
                            .frame(width: 20, height: 20)
                    }
                }
            }
            .frame(minHeight: 88) // Ensure consistent minimum height
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .fill(theme.background)
                .shadow(color: theme.defaultShadow.color.opacity(0.8), radius: theme.defaultShadow.radius * 1.5, x: theme.defaultShadow.x, y: theme.defaultShadow.y * 1.5)
        )
        .onTapGesture {
            onTap()
        }
        .sheet(isPresented: $showingMenu) {
            ExerciseMenuView(
                exercise: workoutExercise,
                onToggleComplete: onToggleComplete,
                onDelete: onDelete
            )
            .presentationDetents([.height(200)])
        }
    }
}

// MARK: - Exercise Menu View
private struct ExerciseMenuView: View {
    let exercise: WorkoutExercise
    let onToggleComplete: () -> Void
    let onDelete: () -> Void
    
    @Environment(\.dismiss) private var dismiss
    @Environment(\.theme) private var theme: any Theme
    
    var body: some View {
        VStack(spacing: 0) {
            // Handle bar
            RoundedRectangle(cornerRadius: 3)
                .fill(Color.secondary.opacity(0.3))
                .frame(width: 40, height: 6)
                .padding(.top, 8)
                .padding(.bottom, 20)
            
            VStack(spacing: 16) {
                ExerciseMenuButton(
                    icon: exercise.isCompleted ? "xmark.circle" : "checkmark.circle",
                    title: exercise.isCompleted ? "Mark as incomplete" : "Mark as complete"
                ) {
                    dismiss()
                    onToggleComplete()
                }
                
                ExerciseMenuButton(icon: "pencil", title: "Edit exercise") {
                    dismiss()
                    // Edit action handled by parent onTap
                }
                
                ExerciseMenuButton(icon: "trash", title: "Delete exercise", isDestructive: true) {
                    dismiss()
                    onDelete()
                }
            }
            .padding(.horizontal, 20)
            
            Spacer()
        }
        .background(theme.background)
    }
}

// MARK: - Exercise Menu Button
private struct ExerciseMenuButton: View {
    let icon: String
    let title: String
    let isDestructive: Bool
    let action: () -> Void
    @Environment(\.theme) private var theme: any Theme
    
    init(icon: String, title: String, isDestructive: Bool = false, action: @escaping () -> Void) {
        self.icon = icon
        self.title = title
        self.isDestructive = isDestructive
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundColor(isDestructive ? .red : theme.primaryText)
                    .frame(width: 24)
                
                Text(title)
                    .font(.system(size: 17))
                    .foregroundColor(isDestructive ? .red : theme.primaryText)
                
                Spacer()
            }
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
    }
}

struct ListWorkoutView_Previews: PreviewProvider {
    
    private struct PreviewWrapper: View {
        @State private var workout = Workout(
            id: UUID(), name: "My Workout", description: "A sample workout for preview.", duration: "45 mins",
            createdAt: "2023-10-27T10:00:00Z",
            updatedAt: "2023-10-27T10:00:00Z",
            workoutexercises: [
                WorkoutExercise(id: UUID(), exercise: Exercise(id: UUID(), name: "Push-Ups", force: nil, level: "Beginner", mechanic: nil, equipment: "None", isCardio: false, primaryMuscles: ["Chest"], secondaryMuscles: ["Triceps"], instructions: ["Do a push up."], category: "Strength", picture1: nil, picture2: nil, isDiagnostic: false, cluster: nil), sets: 3, reps: 10, weight: nil, equipment: "None", order: 1, time: nil),
                WorkoutExercise(id: UUID(), exercise: Exercise(id: UUID(), name: "Squats", force: nil, level: "Beginner", mechanic: nil, equipment: "Barbell", isCardio: false, primaryMuscles: ["Quadriceps"], secondaryMuscles: [], instructions: [], category: "Strength", picture1: nil, picture2: nil, isDiagnostic: false, cluster: nil), sets: 3, reps: 10, weight: 50, equipment: "Barbell", order: 2, time: nil)
            ]
        )
        
        var body: some View {
            ListWorkoutView(workout: $workout)
        }
    }
    
    static var previews: some View {
        PreviewWrapper()
    }
} 
