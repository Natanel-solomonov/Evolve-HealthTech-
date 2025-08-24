/*
import SwiftUI
import HealthKit
import Combine

/// Centralised state + navigation for the multi-step onboarding experience.
/// Lives for the entire app session (RootView owns one `@StateObject`).
final class OnboardingFlowManager: ObservableObject {
    // MARK: - Step Enum
    enum Step: Int, CaseIterable, Codable {
        case nameEntry = 0, healthProfile, goalSelection, goalDetails

        var title: String {
            switch self {
            case .nameEntry: return "Name"
            case .healthProfile: return "Health"
            case .goalSelection: return "Goals"
            case .goalDetails: return "Goal Details"
            }
        }
    }

    // MARK: - Persistence Keys
    private enum Keys {
        static let currentStep = "onboardingCurrentStep"
    }

    // MARK: - Persistence backing (must be declared before properties that use them)
    @AppStorage(Keys.currentStep) private var savedStep: Int = 0

    // MARK: - Published State
    @Published var step: Step = .nameEntry

    // User-entered data fields
    @Published var firstName: String = ""
    @Published var lastName: String  = ""

    @Published var healthProfile = HealthProfile()

    @Published var selectedGoalIDs: Set<UUID> = []
    @Published var goalDetails: [GoalDetailQuestion] = []

    private var cancellables = Set<AnyCancellable>()

    // MARK: - Init
    init() {
        step = Step(rawValue: savedStep) ?? .nameEntry

        // Persist changes reactively
        $step
            .dropFirst()
            .sink { [weak self] in self?.savedStep = $0.rawValue }
            .store(in: &cancellables)
    }

    // MARK: - Navigation helpers
    func goForward() {
        guard step.rawValue < Step.allCases.count - 1 else { return }
        let next = Step(rawValue: step.rawValue + 1) ?? step
        // When transitioning from goalSelection → goalDetails, prebuild detail models.
        if step == .goalSelection && next == .goalDetails {
            goalDetails = selectedGoalIDs.map { id in
                let title = goalTitle(for: id)
                return GoalDetailQuestion(goalId: id, goalTitle: title, questionText: "What are your specific targets for \(title)?", suggestedResponses: ["Not sure", "Need ideas", "Specific target in mind"])
            }
        }
        step = next
    }

    func goBack() {
        guard step.rawValue > 0 else { return }
        step = Step(rawValue: step.rawValue - 1) ?? step
    }

    // MARK: - Validation per step
    func canGoForward() -> Bool {
        switch step {
        case .nameEntry:
            return !firstName.isEmpty && !lastName.isEmpty
        case .healthProfile:
            // For now, allow if HealthKit authorised & mandatory fields exist; relax otherwise.
            return healthProfile.age != nil && healthProfile.height != nil && healthProfile.weight != nil
        case .goalSelection:
            return !selectedGoalIDs.isEmpty
        case .goalDetails:
            return true
        }
    }

    // MARK: helpers
    private func goalTitle(for id: UUID) -> String {
        Goal.all.first(where: { $0.id == id })?.title ?? "Goal"
    }
} 
*/ 