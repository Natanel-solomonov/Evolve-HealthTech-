import Foundation
import Combine
import SwiftUI

@MainActor
class ActivityViewModel: ObservableObject {
    @Published var activities: [Activity] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    private let activityAPI: ActivityAPI
    private let authenticationManager: AuthenticationManager

    init(authenticationManager: AuthenticationManager) {
        self.authenticationManager = authenticationManager
        self.activityAPI = ActivityAPI(httpClient: authenticationManager.httpClient)
    }
    
    func fetchActivities() {
        isLoading = true
        errorMessage = nil
        
        activityAPI.fetchActivities { [weak self] result in
            DispatchQueue.main.async {
                self?.isLoading = false
                switch result {
                case .success(let activities):
                    self?.activities = activities
                case .failure(let error):
                    self?.errorMessage = "Failed to fetch activities: \(error.localizedDescription)"
                    print("Error fetching activities: \(error.localizedDescription)")
                }
            }
        }
    }
}
