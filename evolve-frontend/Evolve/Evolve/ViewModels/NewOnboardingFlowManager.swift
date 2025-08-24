//import SwiftUI
//import HealthKit
//import Combine
//
///// New onboarding flow manager with persistence and resume capability
//final class NewOnboardingFlowManager: ObservableObject {
//    // MARK: - Step Enum
//    enum Step: Int, CaseIterable, Codable {
//        case nameEntry = 0
//        case healthProfile = 1
//        case goalSelection = 2
//        case goalDetails = 3
//        
//        var title: String {
//            switch self {
//            case .nameEntry: return "Name"
//            case .healthProfile: return "Health Profile"
//            case .goalSelection: return "Goals"
//            case .goalDetails: return "Goal Details"
//            }
//        }
//        
//        var description: String {
//            switch self {
//            case .nameEntry: return "Let's get to know each other"
//            case .healthProfile: return "Help us personalize your experience"
//            case .goalSelection: return "What would you like to achieve?"
//            case .goalDetails: return "Tell us more about your goals"
//            }
//        }
//    }
//    
//    // MARK: - Persistence Keys
//    private enum Keys {
//        static let currentStep = "newOnboarding.currentStep"
//        static let firstName = "newOnboarding.firstName"
//        static let lastName = "newOnboarding.lastName"
//        static let healthProfile = "newOnboarding.healthProfile"
//        static let selectedGoalIDs = "newOnboarding.selectedGoalIDs"
//        static let goalDetails = "newOnboarding.goalDetails"
//        static let isInProgress = "newOnboarding.isInProgress"
//    }
//    
//    // MARK: - Published State
//    @Published var currentStep: Step = .nameEntry
//    @Published var isOnboardingInProgress: Bool = false
//    
//    // User data
//    @Published var firstName: String = ""
//    @Published var lastName: String = ""
//    @Published var healthProfile = HealthProfile()
//    @Published var selectedGoalIDs: Set<UUID> = []
//    @Published var goalDetails: [GoalDetailQuestion] = []
//    
//    // MARK: - Persistence Storage
//    @AppStorage(Keys.currentStep) private var savedStepRaw: Int = 0
//    @AppStorage(Keys.firstName) private var savedFirstName: String = ""
//    @AppStorage(Keys.lastName) private var savedLastName: String = ""
//    @AppStorage(Keys.isInProgress) private var savedIsInProgress: Bool = false
//    
//    // Complex types need manual encoding/decoding
//    @AppStorage(Keys.healthProfile) private var savedHealthProfileData: Data = Data()
//    @AppStorage(Keys.selectedGoalIDs) private var savedGoalIDsData: Data = Data()
//    @AppStorage(Keys.goalDetails) private var savedGoalDetailsData: Data = Data()
//    
//    private var cancellables = Set<AnyCancellable>()
//    
//    // MARK: - Init
//    init() {
//        loadSavedProgress()
//        setupAutoSave()
//        
//        // Check if onboarding was in progress
//        if savedStepRaw > 0 || !savedFirstName.isEmpty || !savedLastName.isEmpty {
//            isOnboardingInProgress = true
//        }
//    }
//    
//    // MARK: - Persistence Methods
//    private func loadSavedProgress() {
//        // Load step
//        currentStep = Step(rawValue: savedStepRaw) ?? .nameEntry
//        
//        // Load simple data
//        firstName = savedFirstName
//        lastName = savedLastName
//        isOnboardingInProgress = savedIsInProgress
//        
//        // Load complex data
//        if !savedHealthProfileData.isEmpty,
//           let decoded = try? JSONDecoder().decode(HealthProfile.self, from: savedHealthProfileData) {
//            healthProfile = decoded
//        }
//        
//        if !savedGoalIDsData.isEmpty,
//           let decoded = try? JSONDecoder().decode(Set<UUID>.self, from: savedGoalIDsData) {
//            selectedGoalIDs = decoded
//        }
//        
//        if !savedGoalDetailsData.isEmpty,
//           let decoded = try? JSONDecoder().decode([GoalDetailQuestion].self, from: savedGoalDetailsData) {
//            goalDetails = decoded
//        }
//    }
//    
//    private func setupAutoSave() {
//        // Save step changes
//        $currentStep
//            .removeDuplicates()
//            .sink { [weak self] step in
//                self?.savedStepRaw = step.rawValue
//            }
//            .store(in: &cancellables)
//        
//        // Save simple data
//        $firstName
//            .removeDuplicates()
//            .debounce(for: 0.5, scheduler: RunLoop.main)
//            .sink { [weak self] value in
//                self?.savedFirstName = value
//            }
//            .store(in: &cancellables)
//        
//        $lastName
//            .removeDuplicates()
//            .debounce(for: 0.5, scheduler: RunLoop.main)
//            .sink { [weak self] value in
//                self?.savedLastName = value
//            }
//            .store(in: &cancellables)
//        
//        $isOnboardingInProgress
//            .removeDuplicates()
//            .sink { [weak self] value in
//                self?.savedIsInProgress = value
//            }
//            .store(in: &cancellables)
//        
//        // Save complex data
//        $healthProfile
//            .debounce(for: 0.5, scheduler: RunLoop.main)
//            .sink { [weak self] profile in
//                if let encoded = try? JSONEncoder().encode(profile) {
//                    self?.savedHealthProfileData = encoded
//                }
//            }
//            .store(in: &cancellables)
//        
//        $selectedGoalIDs
//            .removeDuplicates()
//            .sink { [weak self] ids in
//                if let encoded = try? JSONEncoder().encode(ids) {
//                    self?.savedGoalIDsData = encoded
//                }
//            }
//            .store(in: &cancellables)
//        
//        $goalDetails
//            .debounce(for: 0.5, scheduler: RunLoop.main)
//            .sink { [weak self] details in
//                if let encoded = try? JSONEncoder().encode(details) {
//                    self?.savedGoalDetailsData = encoded
//                }
//            }
//            .store(in: &cancellables)
//    }
//    
//    // MARK: - Navigation
//    func goForward() {
//        guard currentStep.rawValue < Step.allCases.count - 1 else { return }
//        let next = Step(rawValue: currentStep.rawValue + 1) ?? currentStep
//        
//        // When transitioning to goal details, prepare questions
//        if currentStep == .goalSelection && next == .goalDetails {
//            prepareGoalDetailQuestions()
//        }
//        
//        currentStep = next
//        isOnboardingInProgress = true
//    }
//    
//    func goBack() {
//        guard currentStep.rawValue > 0 else { return }
//        currentStep = Step(rawValue: currentStep.rawValue - 1) ?? currentStep
//    }
//    
//    func canGoForward() -> Bool {
//        switch currentStep {
//        case .nameEntry:
//            return !firstName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
//                   !lastName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
//        case .healthProfile:
//            return healthProfile.isValid
//        case .goalSelection:
//            return !selectedGoalIDs.isEmpty
//        case .goalDetails:
//            return true // Optional step
//        }
//    }
//    
//    // MARK: - Helper Methods
//    private func prepareGoalDetailQuestions() {
//        goalDetails = selectedGoalIDs.compactMap { id in
//            guard let goal = Goal.all.first(where: { $0.id == id }) else { return nil }
//            
//            let question: String
//            let suggestions: [String]
//            
//            switch goal.title {
//            case "Lose weight":
//                question = "How much weight would you like to lose?"
//                suggestions = ["5-10 lbs", "10-20 lbs", "20+ lbs", "Not sure yet"]
//            case "Build muscle":
//                question = "What's your muscle-building goal?"
//                suggestions = ["Gain lean muscle", "Bulk up significantly", "Tone and define", "Not sure yet"]
//            case "Get more flexible":
//                question = "What flexibility goals do you have?"
//                suggestions = ["Touch my toes", "Do the splits", "Improve overall mobility", "Not sure yet"]
//            case "Get stronger":
//                question = "What strength goals do you have?"
//                suggestions = ["Increase lifts", "Bodyweight exercises", "Functional strength", "Not sure yet"]
//            case "Eat healthier":
//                question = "What nutrition changes are you looking for?"
//                suggestions = ["Eat more vegetables", "Cut processed foods", "Balance macros", "Not sure yet"]
//            case "Regulate energy":
//                question = "What energy improvements do you want?"
//                suggestions = ["More consistent energy", "Less afternoon crashes", "Better morning energy", "Not sure yet"]
//            case "Sleep better":
//                question = "What sleep improvements do you need?"
//                suggestions = ["Fall asleep faster", "Stay asleep longer", "Wake up refreshed", "Not sure yet"]
//            case "Manage stress":
//                question = "How would you like to manage stress?"
//                suggestions = ["Daily meditation", "Breathing exercises", "Better work-life balance", "Not sure yet"]
//            case "Drink more water":
//                question = "What's your hydration goal?"
//                suggestions = ["8 glasses daily", "Half my body weight in oz", "Just drink more", "Not sure yet"]
//            default:
//                question = "What are your specific targets for \(goal.title)?"
//                suggestions = ["Not sure", "Need ideas", "I have specific targets"]
//            }
//            
//            return GoalDetailQuestion(
//                goalId: id,
//                goalTitle: goal.title,
//                questionText: question,
//                suggestedResponses: suggestions
//            )
//        }
//    }
//    
//    // MARK: - Data Preparation
//    func buildPayload() -> [String: Any] {
//        var payload: [String: Any] = [:]
//        
//        // Basic info
//        payload["first_name"] = firstName.trimmingCharacters(in: .whitespacesAndNewlines)
//        payload["last_name"] = lastName.trimmingCharacters(in: .whitespacesAndNewlines)
//        
//        // Health profile
//        if let height = healthProfile.height {
//            let totalInches = Int(round(height * 39.3701))
//            payload["height"] = Double(totalInches)
//        }
//        
//        if let weight = healthProfile.weight {
//            let weightPounds = Double(Int(round(weight * 2.20462)))
//            payload["weight"] = weightPounds
//        }
//        
//        if let birthday = healthProfile.dateOfBirth {
//            let formatter = DateFormatter()
//            formatter.dateFormat = "yyyy-MM-dd"
//            payload["birthday"] = formatter.string(from: birthday)
//        }
//        
//        if let sex = healthProfile.biologicalSex {
//            let sexCode: String = {
//                switch sex {
//                case .male: return "M"
//                case .female: return "F"
//                default: return "O"
//                }
//            }()
//            payload["sex"] = sexCode
//        }
//        
//        // Goals
//        let goalKeys = selectedGoalIDs.compactMap { id -> String? in
//            guard let goal = Goal.all.first(where: { $0.id == id }) else { return nil }
//            return backendKey(for: goal.title)
//        }
//        
//        if !goalKeys.isEmpty {
//            payload["goals_raw"] = goalKeys
//        }
//        
//        // Goal details
//        let detailPayloads = goalDetails.compactMap { detail -> [String: Any]? in
//            guard !detail.responseText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
//                  let key = backendKey(for: detail.goalTitle) else { return nil }
//            
//            return [
//                "goal_categories": [key],
//                "text": detail.responseText
//            ]
//        }
//        
//        if !detailPayloads.isEmpty {
//            payload["goal_details"] = detailPayloads
//        }
//        
//        return payload
//    }
//    
//    private func backendKey(for title: String) -> String? {
//        let map: [String: String] = [
//            "Lose weight": "lose_weight",
//            "Build muscle": "build_muscle",
//            "Get more flexible": "get_more_flexible",
//            "Get stronger": "get_stronger",
//            "Eat healthier": "eat_healthier",
//            "Regulate energy": "regulate_energy",
//            "Sleep better": "sleep_better",
//            "Manage stress": "manage_stress",
//            "Drink more water": "drink_more_water"
//        ]
//        return map[title]
//    }
//    
//    // MARK: - Reset
//    func resetOnboarding() {
//        // Clear all data
//        currentStep = .nameEntry
//        firstName = ""
//        lastName = ""
//        healthProfile = HealthProfile()
//        selectedGoalIDs = []
//        goalDetails = []
//        isOnboardingInProgress = false
//        
//        // Clear persistence
//        savedStepRaw = 0
//        savedFirstName = ""
//        savedLastName = ""
//        savedIsInProgress = false
//        savedHealthProfileData = Data()
//        savedGoalIDsData = Data()
//        savedGoalDetailsData = Data()
//    }
//}
//
//// MARK: - Supporting Types
//struct HealthProfile: Codable {
//    var age: Int?
//    var dateOfBirth: Date?
//    var biologicalSex: HKBiologicalSex?
//    var height: Double? // in meters
//    var weight: Double? // in kg
//    
//    var isValid: Bool {
//        return dateOfBirth != nil && height != nil && weight != nil
//    }
//}
//
//struct GoalDetailQuestion: Identifiable, Codable {
//    let id = UUID()
//    let goalId: UUID
//    let goalTitle: String
//    let questionText: String
//    let suggestedResponses: [String]
//    var responseText: String = ""
//}
//
//// MARK: - HKBiologicalSex + Codable
//extension HKBiologicalSex: Codable {
//    public init(from decoder: Decoder) throws {
//        let container = try decoder.singleValueContainer()
//        let rawValue = try container.decode(Int.self)
//        self = HKBiologicalSex(rawValue: rawValue) ?? .notSet
//    }
//    
//    public func encode(to encoder: Encoder) throws {
//        var container = encoder.singleValueContainer()
//        try container.encode(self.rawValue)
//    }
//} 
