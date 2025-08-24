import SwiftUI

struct ExerciseListView: View {
    @Environment(\.dismiss) var dismiss
    @State private var searchText = ""
    @State private var exercises: [Exercise] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @EnvironmentObject var authenticationManager: AuthenticationManager
    @Environment(\.theme) private var theme: any Theme

    var onSelect: (Exercise) -> Void

    var filteredExercises: [Exercise] {
        let normalizedSearchText = searchText
            .lowercased()
            .replacingOccurrences(of: "-", with: "")
            .replacingOccurrences(of: " ", with: "")

        if normalizedSearchText.isEmpty {
            return exercises
        } else {
            return exercises.filter { exercise in
                let normalizedExerciseName = exercise.name
                    .lowercased()
                    .replacingOccurrences(of: "-", with: "")
                    .replacingOccurrences(of: " ", with: "")
                return normalizedExerciseName.contains(normalizedSearchText)
            }
        }
    }

    var body: some View {
        NavigationView {
            VStack {
                if isLoading {
                    ProgressView("Loading Exercises...")
                } else if let errorMessage = errorMessage {
                    Text("Error: \(errorMessage)")
                        .foregroundColor(.red)
                        .padding()
                } else {
                    List(filteredExercises) { exercise in
                        Button(exercise.name) {
                            onSelect(exercise)
                            dismiss()
                        }
                        .foregroundColor(theme.primaryText)
                    }
                    .searchable(text: $searchText, prompt: "Search Exercises")
                }
            }
            .navigationTitle("Add Exercise")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                fetchData()
            }
        }
        .font(.system(size: 17))
    }

    private func fetchData() {
        isLoading = true
        errorMessage = nil

        let exerciseAPI = ExerciseAPI(httpClient: authenticationManager.httpClient)

        exerciseAPI.fetchExercises { result in
            DispatchQueue.main.async {
                isLoading = false
                switch result {
                case .success(let fetchedExercises):
                    self.exercises = fetchedExercises
                case .failure(let error):
                    self.errorMessage = error.localizedDescription
                    self.exercises = [] // Clear exercises on error
                }
            }
        }
    }
}

struct ExerciseListView_Previews: PreviewProvider {
    static var previews: some View {
        ExerciseListView(onSelect: { _ in })
            .environmentObject(AuthenticationManager())
    }
} 
