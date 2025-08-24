import SwiftUI

struct WorkoutListView: View {
    @State private var workouts: [Workout] = []
    @State private var selectedWorkout: Workout?
    @State private var searchText = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var authManager: AuthenticationManager
    
    var filteredWorkouts: [Workout] {
        if searchText.isEmpty {
            return workouts
        } else {
            return workouts.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                if isLoading {
                    ProgressView()
                        .scaleEffect(1.5)
                } else if let errorMessage = errorMessage {
                    VStack {
                        Text("Error")
                            .font(.system(size: 28))
                            .foregroundColor(.red)
                        Text(errorMessage)
                            .multilineTextAlignment(.center)
                            .padding()
                            .font(.system(size: 17))
                        Button("Try Again") {
                            fetchWorkouts()
                        }
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                    }
                    .padding()
                } else if workouts.isEmpty {
                    Text("No workouts found")
                        .font(.system(size: 22))
                        .foregroundColor(.secondary)
                } else {
                    List {
                        ForEach(filteredWorkouts) { workout in
                            WorkoutRow(workout: workout)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    selectedWorkout = workout
                                }
                        }
                    }
                    .listStyle(InsetGroupedListStyle())
                    .searchable(text: $searchText, prompt: "Search workouts")
                }
            }
            .navigationTitle("Workouts")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                    .font(.system(size: 17))
                }
            }
            .onAppear {
                if workouts.isEmpty {
                    fetchWorkouts()
                }
            }
            .fullScreenCover(item: $selectedWorkout) { workout in
                WorkoutContainerView(workout: workout, onFinish: {
                    selectedWorkout = nil
                })
            }
        }
    }
    
    private func fetchWorkouts() {
        isLoading = true
        errorMessage = nil
        
        let workoutAPI = WorkoutAPI(httpClient: authManager.httpClient)
        workoutAPI.fetchWorkouts { result in
            DispatchQueue.main.async {
                isLoading = false
                
                switch result {
                case .success(let fetchedWorkouts):
                    self.workouts = fetchedWorkouts
                case .failure(let error):
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }
}

struct WorkoutRow: View {
    let workout: Workout
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(workout.name)
                .font(.system(size: 17))
            
            Text(workout.description ?? "")
                .font(.system(size: 15))
                .foregroundColor(.secondary)
                .lineLimit(2)
            
            HStack {
                Label("\(workout.duration)", systemImage: "clock")
                    .font(.system(size: 12))
                
                Spacer()
                
                Text("\(workout.workoutexercises.count) exercises")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            .padding(.top, 4)
        }
        .padding(.vertical, 8)
    }
}

// Preview provider for design-time preview
struct WorkoutListView_Previews: PreviewProvider {
    static var previews: some View {
        WorkoutListView()
            .environmentObject(AuthenticationManager())
    }
} 