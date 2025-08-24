import SwiftUI
import Combine

struct GuidedWorkoutView: View {
    @Binding var workout: Workout
    @Binding var currentIndex: Int
    @Binding var currentSet: Int
    @State private var isEditingRepsAndWeight = false
    
    // State for expandable bottom sheet
    private enum SheetState {
        case minimized, collapsed, expanded
    }
    @State private var sheetState: SheetState = .collapsed
    @State private var dragOffset: CGSize = .zero
    
    // Timer-related state for cardio exercises
    @State private var timeRemaining: TimeInterval = 0
    @State private var isTimerRunning = false
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    @Environment(\.theme) private var theme: any Theme
    
    private enum ExerciseUIType {
        case standard, bodyweight, cardio
    }
    
    private var currentExercise: Binding<WorkoutExercise> {
        $workout.workoutexercises[currentIndex]
    }
    
    private var exerciseUIType: ExerciseUIType {
        let exercise = currentExercise.wrappedValue
        if exercise.exercise.isCardio {
            return .cardio
        }
        if let weight = exercise.weight, weight > 0 {
            return .standard
        }
        return .bodyweight
    }

    var body: some View {
        if workout.workoutexercises.indices.contains(currentIndex) {
            GeometryReader { geometry in
                let minimizedHeight: CGFloat = 160
                let collapsedHeight: CGFloat = 320
                let expandedHeight = geometry.size.height * 0.85
                
                // Calculate the current height of the sheet based on its state and drag offset
                let sheetHeight: CGFloat = {
                    var targetHeight: CGFloat
                    switch sheetState {
                    case .minimized:
                        targetHeight = minimizedHeight
                    case .collapsed:
                        targetHeight = collapsedHeight
                    case .expanded:
                        targetHeight = expandedHeight
                    }
                    
                    var newHeight = targetHeight - dragOffset.height
                    // Clamp the height to be within the minimized and expanded limits
                    newHeight = max(minimizedHeight, newHeight)
                    newHeight = min(expandedHeight, newHeight)
                    return newHeight
                }()
                
                let dragGesture = DragGesture()
                    .onChanged { value in
                        // Only consider vertical drag
                        if abs(value.translation.width) < abs(value.translation.height) {
                            self.dragOffset = value.translation
                        }
                    }
                    .onEnded { value in
                        withAnimation(.spring()) {
                            let verticalMovement = value.translation.height
                            let threshold: CGFloat = 50
                            
                            switch sheetState {
                            case .expanded:
                                if verticalMovement > threshold {
                                    sheetState = .collapsed
                                }
                            case .collapsed:
                                if verticalMovement < -threshold {
                                    sheetState = .expanded
                                } else if verticalMovement > threshold {
                                    sheetState = .minimized
                                }
                            case .minimized:
                                if verticalMovement < -threshold {
                                    sheetState = .collapsed
                                }
                            }
                            self.dragOffset = .zero
                        }
                    }

                ZStack(alignment: .bottom) {
                    // Background color
                   Color("Fitness").edgesIgnoringSafeArea(.all) // turn into color.clear when you want to show image
//                    Color.clear
                    // White bottom card
                    VStack(spacing: 0) {
                        // Draggable Handle
                        VStack {
                            Capsule()
                                .fill(theme.primaryText)
                                .frame(width: 40, height: 5)
                                .padding(.vertical, sheetState == .minimized ? 24 : 12)
                        }
                        .frame(maxWidth: .infinity)
                        .contentShape(Rectangle())
                        .gesture(dragGesture)

                        if sheetState != .minimized {
                            // Fixed Progress Indicator
                            WorkoutProgressIndicator(
                                workout: $workout,
                                currentIndex: $currentIndex,
                                currentSet: $currentSet
                            )
                            .padding(.top, 10)
                            .padding(.bottom)

                            // Scrollable Content
                            ScrollView {
                                VStack(spacing: 15) {
                                    HStack(spacing: 16) {
                                        if let muscleName = currentExercise.wrappedValue.exercise.primaryMuscles.first?.lowercased().capitalized, !muscleName.isEmpty, UIImage(named: muscleName) != nil {
                                            Image(muscleName)
                                                .resizable()
                                                .scaledToFit()
                                                .frame(width: 50, height: 50)
                                                .background(Color(UIColor.systemGray6))
                                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                        } else {
                                            RoundedRectangle(cornerRadius: 12)
                                                .fill(Color(UIColor.systemGray6))
                                                .frame(width: 50, height: 50)
                                        }

                                        VStack(alignment: .leading) {
                                            Text(currentExercise.wrappedValue.exercise.name).font(.system(size: 20)).fontWeight(.bold)
                                            if exerciseUIType != .cardio && !currentExercise.wrappedValue.isCompleted {
                                                Text("Set \(currentSet)/\(currentExercise.wrappedValue.sets ?? 1)").font(.system(size: 15)).foregroundColor(theme.secondaryText)
                                            }
                                        }
                                        Spacer()
                                    }

                                    // Dynamic UI for reps/weight/timer
                                    switch exerciseUIType {
                                    case .standard:
                                        standardExerciseView
                                    case .bodyweight:
                                        bodyweightExerciseView
                                    case .cardio:
                                        cardioExerciseView
                                    }

                                    // Conditionally visible expanded content
                                    if sheetState == .expanded {
                                        VStack(alignment: .leading, spacing: 20) {
                                            // Equipment Section
                                            VStack(alignment: .leading, spacing: 5) {
                                                Text("Equipment")
                                                    .font(.system(size: 22)).fontWeight(.bold)
                                                Text(formattedEquipment())
                                                    .font(.system(size: 17))
                                                    .foregroundColor(theme.secondaryText)
                                            }

                                            // Instructions Section
                                            VStack(alignment: .leading, spacing: 5) {
                                                Text("Instructions")
                                                    .font(.system(size: 22)).fontWeight(.bold)

                                                if currentExercise.wrappedValue.exercise.instructions.isEmpty {
                                                    Text("No instructions available.").foregroundColor(theme.secondaryText)
                                                } else {
                                                    ForEach(Array(currentExercise.wrappedValue.exercise.instructions.enumerated()), id: \.offset) { index, instruction in
                                                        HStack(alignment: .top, spacing: 8) {
                                                            Text("\(index + 1).")
                                                            Text(instruction)
                                                        }
                                                        .font(.system(size: 17))
                                                    }
                                                }
                                            }

                                            // Tips Section
                                            VStack(alignment: .leading, spacing: 5) {
                                                Text("Tips")
                                                    .font(.system(size: 22)).fontWeight(.bold)
                                                Text("No tips available.")
                                                    .font(.system(size: 17)).foregroundColor(theme.secondaryText)
                                            }
                                        }
                                        .padding(.top)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .transition(.opacity.animation(.easeInOut(duration: 0.3)))
                                    }
                                }
                                .padding(.horizontal)
                            }
                            .padding(.horizontal)
                            .scrollDisabled(sheetState != .expanded)
                        } else {
                            Spacer() // Pushes the button to the bottom in the minimized state
                        }

                        Button(action: completeSetOrExercise) {
                            Text(currentExercise.wrappedValue.isCompleted ? "Completed" : "Complete")
                                .font(.system(size: 17)).fontWeight(.bold).foregroundColor(.white)
                                .frame(maxWidth: .infinity).frame(height: 50)
                                .background(currentExercise.wrappedValue.isCompleted ? Color.green : theme.primaryText)
                                .clipShape(RoundedRectangle(cornerRadius: 20))
                        }
                        .disabled(currentExercise.wrappedValue.isCompleted)
                        .padding(.horizontal)
                        .padding(.bottom, 30)
                    }
                    .padding(.top)
                    .frame(width: geometry.size.width, height: sheetHeight)
                    .background(theme.background)
                    .clipShape(WorkoutRoundedCorner(radius: 30, corners: [.topLeft, .topRight]))
                    .shadow(radius: 20)
                }
                .edgesIgnoringSafeArea(.bottom)
            }
            // .background(
            //     Image("PlaceholderExercise")
            //         .resizable()
            //         .scaledToFill()
            //         .offset(y: -65)
            //         .edgesIgnoringSafeArea(.all)
            // )
            .sheet(isPresented: $isEditingRepsAndWeight) {
                RepsAndWeightPickerView(workoutExercise: currentExercise)
            }
            .onReceive(timer) { _ in
                guard isTimerRunning, timeRemaining > 0 else {
                    if timeRemaining <= 0 { isTimerRunning = false }
                    return
                }
                timeRemaining -= 1
            }
            .onAppear(perform: setupInitialStateForExercise)
            .onChange(of: currentIndex) {
                setupInitialStateForExercise()
            }
        } else {
            // Show an empty view to allow the container to smoothly transition to the completion screen.
            EmptyView()
        }
    }
    
    // MARK: - Subviews for different exercise types
    
    private var standardExerciseView: some View {
        HStack(spacing: 15) {
            VStack(spacing: 2) {
                Text("\(currentExercise.wrappedValue.reps ?? 0)").font(.system(size: 28)).fontWeight(.bold)
                Text("reps").font(.system(size: 12)).foregroundColor(theme.secondaryText)
            }.modifier(InputBoxStyle(theme: theme))
            
            Image(systemName: "multiply").font(.system(size: 17)).fontWeight(.medium).foregroundColor(theme.secondaryText)

            VStack(spacing: 2) {
                Text("\(currentExercise.wrappedValue.weight ?? 0)").font(.system(size: 28)).fontWeight(.bold)
                Text("pounds").font(.system(size: 12)).foregroundColor(theme.secondaryText)
            }.modifier(InputBoxStyle(theme: theme))
        }
        .onTapGesture { isEditingRepsAndWeight = true }
    }
    
    private var bodyweightExerciseView: some View {
        HStack(spacing: 15) {
            VStack(spacing: 2) {
                Text("\(currentExercise.wrappedValue.reps ?? 0)").font(.system(size: 28)).fontWeight(.bold)
                Text("reps").font(.system(size: 12)).foregroundColor(theme.secondaryText)
            }.modifier(InputBoxStyle(theme: theme))
        }
        .onTapGesture { isEditingRepsAndWeight = true }
    }
    
    private var cardioExerciseView: some View {
        HStack(spacing: 15) {
            VStack(spacing: 2) {
                Text(timeRemaining.formatted())
                    .font(.system(size: 28)).fontWeight(.bold)
                Text("Time").font(.system(size: 12)).foregroundColor(theme.secondaryText)
            }
            .modifier(InputBoxStyle(theme: theme))
            
            Button(action: { isTimerRunning.toggle() }) {
                Image(systemName: isTimerRunning ? "pause.circle.fill" : "play.circle.fill")
                    .font(.system(size: 44))
                    .foregroundColor(theme.primaryText)
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func formattedEquipment() -> String {
        let equipment = (currentExercise.wrappedValue.equipment ?? currentExercise.wrappedValue.exercise.equipment).lowercased()
        if equipment == "none" || equipment.isEmpty {
            return "No Equipment"
        }
        return equipment.capitalized
    }
    
    private func setupInitialStateForExercise() {
        isTimerRunning = false
        timeRemaining = parseTime(from: currentExercise.wrappedValue.time)
    }

    private func parseTime(from timeString: String?) -> TimeInterval {
        guard let timeString = timeString else { return 0 }
        let numericString = timeString.trimmingCharacters(in: CharacterSet.decimalDigits.inverted)
        return TimeInterval(numericString) ?? 0
    }
    
    private func completeSetOrExercise() {
        Haptic.success.play()
        
        if exerciseUIType == .cardio {
            workout.workoutexercises[currentIndex].isCompleted = true
            moveToNextExercise()
            return
        }
        
        if currentSet < (currentExercise.wrappedValue.sets ?? 1) {
            currentSet += 1
        } else {
            workout.workoutexercises[currentIndex].isCompleted = true
            moveToNextExercise()
        }
    }
    
    private func moveToNextExercise() {
        if let nextIndex = workout.workoutexercises.firstIndex(where: { !$0.isCompleted }) {
            currentIndex = nextIndex
            currentSet = 1
        } else {
            currentIndex = workout.workoutexercises.count
        }
    }
}

// A helper modifier for the input display boxes
private struct InputBoxStyle: ViewModifier {
    let theme: any Theme
    func body(content: Content) -> some View {
        content
            .padding([.horizontal, .vertical], 10)
            .frame(minWidth: 0, maxWidth: .infinity)
            .background(RoundedRectangle(cornerRadius: 16).themedFill(theme.cardStyle))
    }
}

// A shape for rounding specific corners of a rectangle
private struct WorkoutRoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(roundedRect: rect, byRoundingCorners: corners, cornerRadii: CGSize(width: radius, height: radius))
        return Path(path.cgPath)
    }
}

private extension TimeInterval {
    func formatted() -> String {
        let minutes = Int(self) / 60
        let seconds = Int(self) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

struct GuidedWorkoutView_Previews: PreviewProvider {
    
    private struct PreviewWrapper: View {
        @State private var sampleWorkout = Workout(
            id: UUID(),
            name: "Full Body Strength",
            description: "A comprehensive workout targeting all major muscle groups.",
            duration: "60 mins",
            createdAt: "2023-10-27T10:00:00Z",
            updatedAt: "2023-10-27T10:00:00Z",
            workoutexercises: [
                // 1. Standard Exercise (Weight & Reps)
                WorkoutExercise(
                    id: UUID(),
                    exercise: Exercise(id: UUID(), name: "Concentration Curl", force: "push", level: "Intermediate", mechanic: "compound", equipment: "Barbell", isCardio: false, primaryMuscles: ["Biceps"], secondaryMuscles: ["Glutes"], instructions: ["Place the barbell on your upper back.", "Squat down until your thighs are parallel to the floor."], category: "Strength", picture1: nil, picture2: nil, isDiagnostic: false, cluster: nil),
                    sets: 3, reps: 8, weight: 35, equipment: "Dumbbell", order: 1, time: nil
                ),
                // 2. Bodyweight Exercise (Reps only)
                WorkoutExercise(
                    id: UUID(),
                    exercise: Exercise(id: UUID(), name: "Push-Ups", force: "push", level: "Beginner", mechanic: "compound", equipment: "none", isCardio: false, primaryMuscles: ["Chest"], secondaryMuscles: ["Triceps"], instructions: ["Get into a plank position.", "Lower your body until your chest nearly touches the floor."], category: "Strength", picture1: nil, picture2: nil, isDiagnostic: false, cluster: nil),
                    sets: 3, reps: 15, weight: nil, equipment: "none", order: 2, time: nil
                ),
                // 3. Cardio Exercise (Timer)
                WorkoutExercise(
                    id: UUID(),
                    exercise: Exercise(id: UUID(), name: "Jumping Jacks", force: nil, level: "Beginner", mechanic: nil, equipment: "none", isCardio: true, primaryMuscles: ["full body"], secondaryMuscles: [], instructions: [], category: "Cardio", picture1: nil, picture2: nil, isDiagnostic: false, cluster: nil),
                    sets: 1, reps: nil, weight: nil, equipment: "none", order: 3, time: "60s"
                )
            ]
        )
        @State private var index = 0
        @State private var currentSet = 1
        
        var body: some View {
            GuidedWorkoutView(workout: $sampleWorkout, currentIndex: $index, currentSet: $currentSet)
        }
    }

    static var previews: some View {
        PreviewWrapper()
    }
} 
