import SwiftUI

struct RoutineView: View {
    let routine: Routine

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(routine.title)
                .font(.largeTitle)
                .fontWeight(.bold)
                .padding(.horizontal)

            if !routine.description.isEmpty {
                Text(routine.description)
                    .font(.body)
                    .padding(.horizontal)
            }

            ScrollView {
                VStack(spacing: 12) {
                    ForEach(routine.steps) { step in
                        RoutineStepCard(step: step)
                    }
                }
                .padding()
            }
        }
        .navigationTitle("Routine")
    }
}

struct RoutineStepCard: View {
    let step: RoutineStep

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: step.icon)
                .font(.title)
                .frame(width: 40, height: 40)
                .foregroundColor(.accentColor)

            VStack(alignment: .leading) {
                Text(step.name)
                    .font(.headline)
                    .fontWeight(.semibold)
            }

            Spacer()
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(12)
    }
}

struct RoutineView_Previews: PreviewProvider {
    static var previews: some View {
        let previewSteps = [
            RoutineStep(id: UUID(), name: "Drink Water", icon: "cup.and.saucer.fill", order: 1),
            RoutineStep(id: UUID(), name: "Meditate for 10 minutes", icon: "heart.fill", order: 2),
            RoutineStep(id: UUID(), name: "Go for a walk", icon: "figure.walk", order: 3)
        ]
        
        let previewRoutine = Routine(
            id: UUID(),
            user: SimpleAppUser(id: "1234", firstName: "John", lastName: "Doe", phone: "+11234567890"),
            title: "Morning Routine",
            description: "A simple routine to start the day fresh.",
            scheduledTime: "08:00:00",
            createdAt: "2023-01-01T12:00:00Z",
            updatedAt: "2023-01-01T12:00:00Z",
            steps: previewSteps
        )
        
        NavigationView {
            RoutineView(routine: previewRoutine)
        }
    }
} 
