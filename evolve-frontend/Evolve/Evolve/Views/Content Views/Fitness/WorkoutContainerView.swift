import SwiftUI

struct WorkoutContainerView: View {
    @State var workout: Workout
    @State private var selectedViewIndex = 0
    @State private var isPaused = false
    @State private var showingAddExerciseSheet = false
    
    @State private var guidedExerciseIndex: Int
    @State private var currentSet: Int = 1
    @State private var showCompletionView = false
    
    @EnvironmentObject var authManager: AuthenticationManager
    var onEndWorkout: ((_ markComplete: Bool) -> Void)?
    var onFinish: (() -> Void)?
    var onSaveProgress: ((_ exerciseIndex: Int, _ currentSet: Int, _ completedExercises: [UUID]) -> Void)?
    var activityId: UUID?
    var savedProgress: WorkoutProgress?
    var customWorkoutActivityId: UUID? // For custom workouts that need adhoc completion logs
    @Environment(\.presentationMode) var presentationMode
    @Environment(\.theme) private var theme: any Theme

    // Add UserActivityAPI instance
    private var userActivityAPI: UserActivityAPI {
        UserActivityAPI(httpClient: authManager.httpClient)
    }

    init(workout: Workout, activityId: UUID? = nil, savedProgress: WorkoutProgress? = nil, customWorkoutActivityId: UUID? = nil, onEndWorkout: ((_ markComplete: Bool) -> Void)? = nil, onFinish: (() -> Void)? = nil, onSaveProgress: ((_ exerciseIndex: Int, _ currentSet: Int, _ completedExercises: [UUID]) -> Void)? = nil) {
        print("DEBUG: WorkoutContainerView init called")
        print("DEBUG: onEndWorkout callback is \(onEndWorkout == nil ? "nil" : "set")")
        print("DEBUG: onFinish callback is \(onFinish == nil ? "nil" : "set")")
        print("DEBUG: customWorkoutActivityId: \(customWorkoutActivityId?.uuidString ?? "nil")")
        
        _workout = State(initialValue: workout)
        self.activityId = activityId
        self.savedProgress = savedProgress
        self.customWorkoutActivityId = customWorkoutActivityId
        self.onEndWorkout = onEndWorkout
        self.onFinish = onFinish
        self.onSaveProgress = onSaveProgress
        
        // Initialize exercise index and set based on saved progress
        if let progress = savedProgress {
            _guidedExerciseIndex = State(initialValue: progress.currentExerciseIndex)
            _currentSet = State(initialValue: progress.currentSet)
            
            // Apply completed exercises to the workout
            var updatedWorkout = workout
            for exerciseId in progress.completedExercises {
                if let index = updatedWorkout.workoutexercises.firstIndex(where: { $0.id == exerciseId }) {
                    updatedWorkout.workoutexercises[index].isCompleted = true
                }
            }
            _workout = State(initialValue: updatedWorkout)
        } else {
            _guidedExerciseIndex = State(initialValue: workout.workoutexercises.firstIndex(where: { !$0.isCompleted }) ?? 0)
            _currentSet = State(initialValue: 1)
        }
    }

    // Function to save current progress
    private func saveCurrentProgress() {
        guard activityId != nil else { return }
        
        // TODO: Implement progress saving functionality
        // Will need to access progress manager from the calling view
    }

    // Function to handle workout completion
    private func handleWorkoutCompletion() {
        print("DEBUG: handleWorkoutCompletion called")
        print("DEBUG: onFinish callback is \(onFinish == nil ? "nil" : "set")")
        
        guard let activityId = activityId else {
            print("DEBUG: No activityId found")
            // Check if this is a custom workout that needs an adhoc completion log
            if let customActivityId = customWorkoutActivityId {
                print("DEBUG: Custom workout detected, creating adhoc completion log")
                createAdhocCompletionLog(for: customActivityId)
            } else {
                print("DEBUG: No custom workout activity ID, calling onFinish directly")
                // No associated activity, just call the completion handler
                onFinish?()
                print("DEBUG: onFinish call completed")
            }
            return
        }
        
        print("DEBUG: Found activityId: \(activityId), updating scheduled activity")
        
        // Mark the UserScheduledActivity as complete
        let updateData = UpdateUserScheduledActivityRequest(
            isComplete: true,
            customNotes: nil
        )
        
        userActivityAPI.updateScheduledActivity(
            activityId: activityId.uuidString,
            updateData: updateData
        ) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(_):
                    print("DEBUG: Successfully marked scheduled activity as complete, calling onFinish")
                    // Call the completion handler
                    self.onFinish?()
                    print("DEBUG: onFinish call completed")
                case .failure(let error):
                    print("DEBUG: Failed to mark scheduled activity as complete: \(error), calling onFinish anyway")
                    // Still call the completion handler even if the API call fails
                    // The user has completed the workout locally
                    self.onFinish?()
                    print("DEBUG: onFinish call completed")
                }
            }
        }
    }
    
    // Function to create adhoc completion log for custom workouts
    private func createAdhocCompletionLog(for activityId: UUID) {
        print("DEBUG: createAdhocCompletionLog called for activityId: \(activityId)")
        
        let logData = CreateAdhocCompletionLogRequest(
            activityId: activityId.uuidString,
            activityNameAtCompletion: workout.name,
            descriptionAtCompletion: workout.description,
            pointsAwarded: 50, // Default points for custom workout completion
            userNotesOnCompletion: nil
        )
        
        Task {
            do {
                print("DEBUG: Creating adhoc completion log via API")
                let _ = try await userActivityAPI.createAdhocCompletionLog(logData: logData)
                DispatchQueue.main.async {
                    print("DEBUG: Successfully created adhoc completion log for custom workout, calling onFinish")
                    self.onFinish?()
                    print("DEBUG: onFinish call completed")
                }
            } catch {
                DispatchQueue.main.async {
                    print("DEBUG: Failed to create adhoc completion log: \(error), calling onFinish anyway")
                    // Still call the completion handler even if the API call fails
                    self.onFinish?()
                    print("DEBUG: onFinish call completed")
                }
            }
        }
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .top) {
                // MARK: - Content Area
                ZStack {
                    if selectedViewIndex == 0 {
                        // Guided View
                        Group {
                            if workout.workoutexercises.indices.contains(guidedExerciseIndex) {
                                GuidedWorkoutView(workout: $workout, currentIndex: $guidedExerciseIndex, currentSet: $currentSet)
                            } else {
                                // Empty view while completion screen is presented
                                Color("Fitness").edgesIgnoringSafeArea(.all)
                            }
                        }
                        .transition(.opacity)
                    } else {
                        // List View
                        ListWorkoutView(workout: $workout)
                            .transition(.opacity)
                    }
                }
                .edgesIgnoringSafeArea(.all)

                // MARK: - Top Controls
                HStack(spacing: 12) {
                    // Left Menu Button
                    Menu {
                        Button(action: {
                            showingAddExerciseSheet = true
                        }) {
                            Label("Add Exercise", systemImage: "plus")
                        }
                        
                        Button(action: {
                            // TODO: Implement stopwatch functionality
                        }) {
                            Label("Stopwatch", systemImage: "stopwatch")
                        }
                        
                        Button(action: {
                            // TODO: Implement timer functionality
                        }) {
                            Label("Timer", systemImage: "timer")
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 20))
                            .foregroundColor(theme.primaryText)
                            .frame(width: 50, height: 50)
                            .background(theme.navigationBarMaterial)
                            .clipShape(Circle())
                    }
                    
                    Spacer()

                    // Center View Switcher
                    HStack(spacing: 30) {
                        Button(action: { withAnimation { selectedViewIndex = 0 } }) {
                            Text("Guided").fontWeight(selectedViewIndex == 0 ? .bold : .regular)
                                .foregroundColor(selectedViewIndex == 0 ? theme.primaryText : theme.secondaryText)
                        }
                        Button(action: { withAnimation { selectedViewIndex = 1 } }) {
                            Text("List").fontWeight(selectedViewIndex == 1 ? .bold : .regular)
                                .foregroundColor(selectedViewIndex == 1 ? theme.primaryText : theme.secondaryText)
                        }
                    }
                    .font(.system(size: 16))
                    .padding(.horizontal, 20)
                    .frame(height: 50)
                    .background(Capsule().fill(theme.navigationBarMaterial))
                    
                    Spacer()

                    // Right Pause/Play Button
                    Button(action: {
                        if isPaused {
                            Haptic.light.play()
                        } else {
                            Haptic.warning.play()
                        }
                        withAnimation(.easeInOut(duration: 0.2)) { isPaused.toggle() }
                    }) {
                        Image(systemName: isPaused ? "play.fill" : "pause.fill")
                            .font(.system(size: 20))
                            .foregroundColor(theme.primaryText)
                            .frame(width: 50, height: 50)
                            .background(theme.navigationBarMaterial)
                            .clipShape(Circle())
                    }
                }
                .padding(.horizontal)
                .padding(.top, geometry.safeAreaInsets.top)
                
                // MARK: - Pause Dialog Overlay
                if isPaused {
                    PauseWorkoutDialog(
                        onResume: {
                            Haptic.light.play()
                            withAnimation(.easeInOut(duration: 0.2)) { isPaused = false }
                        },
                        onEnd: {
                            isPaused = false
                            
                            print("DEBUG: End Workout button pressed")
                            
                            // Save current progress before ending
                            let completedExercises = workout.workoutexercises.compactMap { exercise in
                                exercise.isCompleted ? exercise.id : nil
                            }
                            onSaveProgress?(guidedExerciseIndex, currentSet, completedExercises)
                            
                            print("DEBUG: onEndWorkout callback is \(onEndWorkout == nil ? "nil" : "set")")
                            print("DEBUG: Calling onEndWorkout with false (ended early)")
                            onEndWorkout?(false) // false = ended early, not completed
                            print("DEBUG: onEndWorkout call completed")
                            // Note: We don't mark the scheduled activity as complete when ending early
                        }
                    )
                }
            }
            .edgesIgnoringSafeArea(.all)
            .sheet(isPresented: $showingAddExerciseSheet) {
                ExerciseListView { selectedExercise in
                    let newWorkoutExercise = WorkoutExercise(
                        id: UUID(),
                        exercise: selectedExercise,
                        sets: 3,
                        reps: 10,
                        weight: nil,
                        equipment: selectedExercise.equipment,
                        order: (workout.workoutexercises.last?.order ?? 0) + 1,
                        time: nil
                    )
                    workout.workoutexercises.append(newWorkoutExercise)
                }
            }

            .onChange(of: guidedExerciseIndex) {
                if !workout.workoutexercises.indices.contains(guidedExerciseIndex) {
                    showCompletionView = true
                }
            }
            .fullScreenCover(isPresented: $showCompletionView) {
                WorkoutCompletionView {
                    print("DEBUG: WorkoutCompletionView Finish button pressed")
                    // First dismiss the completion view
                    showCompletionView = false
                    // Then handle completion after a small delay to ensure the view dismisses
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        print("DEBUG: About to call handleWorkoutCompletion")
                        handleWorkoutCompletion()
                    }
                }
            }
        }
    }
}

// MARK: - Preview
struct WorkoutContainerView_Previews: PreviewProvider {
    static var previews: some View {
        WorkoutContainerView(workout: Workout(
            id: UUID(), name: "Full Body Strength", description: "A comprehensive workout.", duration: "60 mins",
            createdAt: "2023-10-27T10:00:00Z",
            updatedAt: "2023-10-27T10:00:00Z",
            workoutexercises: [
                WorkoutExercise(
                    id: UUID(),
                    exercise: Exercise(id: UUID(), name: "Push-Ups", force: "push", level: "Beginner", mechanic: "compound", equipment: "none", isCardio: false, primaryMuscles: ["Chest"], secondaryMuscles: ["Triceps"], instructions: ["Get into a plank position.", "Lower your body until your chest nearly touches the floor."], category: "Strength", picture1: nil, picture2: nil, isDiagnostic: false, cluster: nil),
                    sets: 3, reps: 15, weight: nil, equipment: "none", order: 1, time: nil
                ),
                // 1. Standard Exercise (Weight & Reps)
                WorkoutExercise(
                    id: UUID(),
                    exercise: Exercise(id: UUID(), name: "Concentration Curl", force: "push", level: "Intermediate", mechanic: "compound", equipment: "Barbell", isCardio: false, primaryMuscles: ["Biceps"], secondaryMuscles: ["Glutes"], instructions: ["Place the barbell on your upper back.", "Squat down until your thighs are parallel to the floor."], category: "Strength", picture1: nil, picture2: nil, isDiagnostic: false, cluster: nil),
                    sets: 3, reps: 8, weight: 35, equipment: "Dumbbell", order: 2, time: nil
                ),
                // 2. Bodyweight Exercise (Reps only)
                
                // 3. Cardio Exercise (Timer)
                WorkoutExercise(
                    id: UUID(),
                    exercise: Exercise(id: UUID(), name: "Jumping Jacks", force: nil, level: "Beginner", mechanic: nil, equipment: "none", isCardio: true, primaryMuscles: ["full body"], secondaryMuscles: [], instructions: [], category: "Cardio", picture1: nil, picture2: nil, isDiagnostic: false, cluster: nil),
                    sets: 1, reps: nil, weight: nil, equipment: "none", order: 3, time: "60s"
                ),
                WorkoutExercise(
                    id: UUID(),
                    exercise: Exercise(id: UUID(), name: "Push-Ups", force: "push", level: "Beginner", mechanic: "compound", equipment: "none", isCardio: false, primaryMuscles: ["Chest"], secondaryMuscles: ["Triceps"], instructions: ["Get into a plank position.", "Lower your body until your chest nearly touches the floor."], category: "Strength", picture1: nil, picture2: nil, isDiagnostic: false, cluster: nil),
                    sets: 3, reps: 15, weight: nil, equipment: "none", order: 4, time: nil
                ),
                WorkoutExercise(
                    id: UUID(),
                    exercise: Exercise(id: UUID(), name: "Push-Ups", force: "push", level: "Beginner", mechanic: "compound", equipment: "none", isCardio: false, primaryMuscles: ["Chest"], secondaryMuscles: ["Triceps"], instructions: ["Get into a plank position.", "Lower your body until your chest nearly touches the floor."], category: "Strength", picture1: nil, picture2: nil, isDiagnostic: false, cluster: nil),
                    sets: 3, reps: 15, weight: nil, equipment: "none", order: 5, time: nil
                ),
                WorkoutExercise(
                    id: UUID(),
                    exercise: Exercise(id: UUID(), name: "Push-Ups", force: "push", level: "Beginner", mechanic: "compound", equipment: "none", isCardio: false, primaryMuscles: ["Chest"], secondaryMuscles: ["Triceps"], instructions: ["Get into a plank position.", "Lower your body until your chest nearly touches the floor."], category: "Strength", picture1: nil, picture2: nil, isDiagnostic: false, cluster: nil),
                    sets: 3, reps: 15, weight: nil, equipment: "none", order: 6, time: nil
                ),
                WorkoutExercise(
                    id: UUID(),
                    exercise: Exercise(id: UUID(), name: "Push-Ups", force: "push", level: "Beginner", mechanic: "compound", equipment: "none", isCardio: false, primaryMuscles: ["Chest"], secondaryMuscles: ["Triceps"], instructions: ["Get into a plank position.", "Lower your body until your chest nearly touches the floor."], category: "Strength", picture1: nil, picture2: nil, isDiagnostic: false, cluster: nil),
                    sets: 3, reps: 15, weight: nil, equipment: "none", order: 7, time: nil
                )
            ]
        ))
        .environmentObject(AuthenticationManager())
    }
} 
