import Foundation
import SwiftUI

@MainActor
class EmotionsViewModel: ObservableObject {
    @Published var feeling: String = ""
    @Published var cause: String = ""
    @Published var causes: [String] = []  // Added for multiple causes
    @Published var biggestImpact: String = ""
    @Published var impacts: [String] = []  // Added for multiple impacts
    @Published var intensity: Int = 5 // Default intensity, UI can bind to this
    
    @Published var errorMessage: String?
    @Published var isLoading: Bool = false
    @Published var logType: EmotionLogType = .current // From Models/EmotionModels.swift
    
    private let emotionAPI: EmotionAPI
    private let authenticationManager: AuthenticationManager
    
    var authToken: String? {
        authenticationManager.authToken
    }

    init(authenticationManager: AuthenticationManager) {
        self.authenticationManager = authenticationManager
        self.emotionAPI = EmotionAPI(httpClient: authenticationManager.httpClient)
    }

    func logEmotion() async -> Bool {
        isLoading = true
        errorMessage = nil
        do {
            _ = try await emotionAPI.logEmotion(
                type: logType,
                feeling: feeling,
                causes: causes.isEmpty ? [cause] : causes,  // Use causes array if available
                impacts: impacts.isEmpty ? [biggestImpact] : impacts,  // Use impacts array if available
                intensity: intensity
            )
            isLoading = false
            return true
        } catch let error as NetworkError {
            errorMessage = "Failed to log emotion: \(error.localizedDescription)"
            print("Error logging emotion (NetworkError): \(error)")
            isLoading = false
            return false
        } catch {
            errorMessage = "An unexpected error occurred: \(error.localizedDescription)"
            print("Error logging emotion: \(error)")
            isLoading = false
            return false
        }
    }
}
