import Foundation
import HealthKit
import Combine

/// HealthKit manager that handles permissions and data fetching for health metrics
/// Provides real-time access to user's health data including steps, heart rate, and other metrics
@MainActor
class HealthKitManager: ObservableObject {
    
    // MARK: - Published Properties
    
    /// Current step count for today
    @Published var stepCount: Int = 0
    
    /// Step goal (can be customized by user, defaults to 10,000)
    @Published var stepGoal: Int = 10000
    
    /// Authorization status for HealthKit
    @Published var isAuthorized: Bool = false
    
    /// Loading state for health data requests
    @Published var isLoading: Bool = false
    
    // MARK: - Private Properties
    
    /// HealthKit store instance
    private let healthStore = HKHealthStore()
    
    /// Cancellables for Combine subscriptions
    private var cancellables = Set<AnyCancellable>()
    
    /// Background queue for HealthKit operations
    private let healthQueue = DispatchQueue(label: "healthkit.queue", qos: .utility)
    
    // MARK: - Computed Properties
    
    /// Types of health data we want to read
    private var healthTypesToRead: Set<HKObjectType> {
        guard let stepType = HKObjectType.quantityType(forIdentifier: .stepCount) else {
            return []
        }
        return [stepType]
    }
    
    // MARK: - Initialization
    
    init() {
        loadSavedStepGoal()
        setupHealthKit()
    }
    
    // MARK: - Setup Methods
    
    /// Initial setup for HealthKit integration
    private func setupHealthKit() {
        guard HKHealthStore.isHealthDataAvailable() else {
            print("HealthKit is not available on this device")
            return
        }
        
        requestHealthKitPermissions()
    }
    
    // MARK: - Permission Methods
    
    /// Request permissions for HealthKit data access
    func requestHealthKitPermissions() {
        guard HKHealthStore.isHealthDataAvailable() else {
            print("HealthKit is not available on this device")
            return
        }
        
        healthStore.requestAuthorization(toShare: nil, read: healthTypesToRead) { [weak self] success, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("HealthKit authorization failed: \(error.localizedDescription)")
                    self?.isAuthorized = false
                } else {
                    print("HealthKit authorization: \(success ? "granted" : "denied")")
                    self?.isAuthorized = success
                    
                    if success {
                        self?.fetchTodaysSteps()
                        self?.setupStepCountObserver()
                    }
                }
            }
        }
    }
    
    // MARK: - Data Fetching Methods
    
    /// Fetch today's step count from HealthKit
    func fetchTodaysSteps() {
        guard isAuthorized else {
            print("HealthKit not authorized")
            return
        }
        
        guard let stepCountType = HKQuantityType.quantityType(forIdentifier: .stepCount) else {
            print("Step count type not available")
            return
        }
        
        Task { @MainActor in
            isLoading = true
        }
        
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? Date()
        
        let predicate = HKQuery.predicateForSamples(
            withStart: startOfDay,
            end: endOfDay,
            options: .strictStartDate
        )
        
        let query = HKStatisticsQuery(
            quantityType: stepCountType,
            quantitySamplePredicate: predicate,
            options: .cumulativeSum
        ) { [weak self] _, result, error in
            DispatchQueue.main.async {
                self?.isLoading = false
                
                if let error = error {
                    print("Error fetching step count: \(error.localizedDescription)")
                    return
                }
                
                guard let result = result,
                      let sum = result.sumQuantity() else {
                    print("No step data available")
                    self?.stepCount = 0
                    return
                }
                
                let steps = Int(sum.doubleValue(for: HKUnit.count()))
                self?.stepCount = steps
                print("Fetched steps: \(steps)")
            }
        }
        
        healthStore.execute(query)
    }
    
    // MARK: - Real-time Monitoring
    
    /// Set up observer to monitor step count changes in real-time
    private func setupStepCountObserver() {
        guard let stepCountType = HKQuantityType.quantityType(forIdentifier: .stepCount) else {
            return
        }
        
        let query = HKObserverQuery(sampleType: stepCountType, predicate: nil) { [weak self] _, _, error in
            if let error = error {
                print("Observer query error: \(error.localizedDescription)")
                return
            }
            
            // Fetch updated step count when changes are detected
            Task { @MainActor in
                self?.fetchTodaysSteps()
            }
        }
        
        healthStore.execute(query)
        healthStore.enableBackgroundDelivery(for: stepCountType, frequency: .immediate) { success, error in
            if let error = error {
                print("Background delivery setup error: \(error.localizedDescription)")
            } else {
                print("Background delivery setup: \(success ? "successful" : "failed")")
            }
        }
    }
    
    // MARK: - Utility Methods
    
    /// Check current authorization status for step data
    func checkAuthorizationStatus() -> HKAuthorizationStatus {
        guard let stepCountType = HKQuantityType.quantityType(forIdentifier: .stepCount) else {
            return .notDetermined
        }
        return healthStore.authorizationStatus(for: stepCountType)
    }
    
    /// Manual refresh of step data
    func refreshStepData() {
        guard isAuthorized else {
            requestHealthKitPermissions()
            return
        }
        fetchTodaysSteps()
    }
    
    /// Update step goal (persisted locally)
    func updateStepGoal(_ newGoal: Int) {
        stepGoal = max(1000, min(50000, newGoal)) // Reasonable bounds
        UserDefaults.standard.set(stepGoal, forKey: "user_step_goal")
    }
    
    /// Load saved step goal from UserDefaults
    private func loadSavedStepGoal() {
        let savedGoal = UserDefaults.standard.integer(forKey: "user_step_goal")
        if savedGoal > 0 {
            stepGoal = savedGoal
        }
    }
}

// MARK: - HealthKit Status Extension

extension HealthKitManager {
    /// Human-readable authorization status
    var authorizationStatusDescription: String {
        switch checkAuthorizationStatus() {
        case .notDetermined:
            return "Not determined"
        case .sharingDenied:
            return "Access denied"
        case .sharingAuthorized:
            return "Authorized"
        @unknown default:
            return "Unknown"
        }
    }
    
    /// Whether we can request permissions (not denied)
    var canRequestPermissions: Bool {
        checkAuthorizationStatus() != .sharingDenied
    }
} 