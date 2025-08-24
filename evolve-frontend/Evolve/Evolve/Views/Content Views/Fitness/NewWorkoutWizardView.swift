import SwiftUI

struct NewWorkoutWizardView: View {
    @EnvironmentObject var authManager: AuthenticationManager
    @Environment(\.dismiss) var dismiss

    @State private var selectedMuscles: Set<String> = []
    @State private var duration: Int = 40
    @State private var intensity: String = "medium"
    @State private var includeCardio = false
    @State private var isLoading = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var generatedWorkout: Workout?
    @State private var customWorkoutActivityId: UUID?
    @Environment(\.theme) private var theme: any Theme

    private let allMuscles = ["chest", "back", "quadriceps", "hamstrings", "glutes", "shoulders", "biceps", "triceps", "core"]

    var body: some View {
        NavigationView {
            VStack {
                Form {
                    Section(header: Text("Target Muscles")) {
                        ForEach(allMuscles, id: \.self) { muscle in
                            MultipleSelectionRow(title: muscle.capitalized, isSelected: selectedMuscles.contains(muscle)) {
                                if selectedMuscles.contains(muscle) {
                                    selectedMuscles.remove(muscle)
                                } else {
                                    selectedMuscles.insert(muscle)
                                }
                            }
                        }
                    }

                    Section(header: Text("Duration")) {
                        Picker("Duration", selection: $duration) {
                            Text("20 min").tag(20)
                            Text("40 min").tag(40)
                            Text("60 min").tag(60)
                        }.pickerStyle(SegmentedPickerStyle())
                    }

                    Section(header: Text("Intensity")) {
                        Picker("Intensity", selection: $intensity) {
                            Text("Low").tag("low")
                            Text("Medium").tag("medium")
                            Text("High").tag("high")
                        }.pickerStyle(SegmentedPickerStyle())
                    }

                    Toggle("Include cardio warm-up", isOn: $includeCardio)
                }

                Button(action: generateWorkout) {
                    if isLoading {
                        ProgressView()
                    } else {
                        Text("Continue")
                            .bold()
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(selectedMuscles.isEmpty ? theme.secondaryText.opacity(0.5) : theme.accent)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                }
                .disabled(selectedMuscles.isEmpty || isLoading)
                .padding()
            }
            .navigationTitle("Custom Workout")
            .alert("Error", isPresented: $showError, actions: { Button("OK", role: .cancel) {} }, message: { Text(errorMessage) })
            .fullScreenCover(item: $generatedWorkout) { wk in
                Group {
                    let _ = print("DEBUG: NewWorkoutWizardView fullScreenCover presenting with workout: \(wk.name)")
                    WorkoutContainerView(
                        workout: wk,
                        customWorkoutActivityId: customWorkoutActivityId,
                        onEndWorkout: { markComplete in
                            print("DEBUG: onEndWorkout called with markComplete: \(markComplete)")
                            // First dismiss the workout container view
                            generatedWorkout = nil
                            customWorkoutActivityId = nil
                            // Then dismiss the workout wizard to return to main navigation
                            dismiss()
                        },
                        onFinish: {
                            print("DEBUG: onFinish called - workout completed")
                            // First dismiss the workout container view
                            generatedWorkout = nil
                            customWorkoutActivityId = nil
                            // Then dismiss the workout wizard when workout is completed
                            dismiss()
                        }
                    )
                    .environmentObject(authManager)
                }
            }
        }
    }

    private func generateWorkout() {
        guard let httpClient = authManager.httpClient as AuthenticatedHTTPClient? else { return }
        isLoading = true
        Task {
            do {
                let api = CustomWorkoutAPI(httpClient: httpClient)
                let req = GenerateCustomWorkoutRequest(muscleGroups: Array(selectedMuscles), duration: duration, intensity: intensity, includeCardio: includeCardio, scheduleForToday: false)
                let resp = try await api.generateCustomWorkout(request: req)
                // Store the activity ID for completion tracking
                self.customWorkoutActivityId = resp.activityId
                // Fetch workout detail
                let workoutAPI = WorkoutAPI(httpClient: httpClient)
                let workout = try await workoutAPI.fetchWorkoutById(id: resp.workoutId)
                await MainActor.run {
                    self.generatedWorkout = workout
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.isLoading = false
                    self.errorMessage = error.localizedDescription
                    self.showError = true
                }
            }
        }
    }
}

struct MultipleSelectionRow: View {
    var title: String
    var isSelected: Bool
    var action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack {
                Text(title)
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark")
                }
            }
        }
    }
} 
