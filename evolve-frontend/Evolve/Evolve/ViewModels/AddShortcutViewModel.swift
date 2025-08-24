import Foundation
import SwiftUI
import Combine

@MainActor
class AddShortcutViewModel: ObservableObject {
    @Published var availableShortcuts: [Shortcut] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    // Using a Set for efficient lookup of selected shortcut IDs
    @Published var selectedShortcutIds: Set<UUID>
    
    private let apiService: ShortcutAPIService
    private var cancellables = Set<AnyCancellable>()

    init(httpClient: AuthenticatedHTTPClient, currentUserShortcuts: [UserShortcut]) {
        self.apiService = ShortcutAPIService(httpClient: httpClient)
        // Initialize the set of selected IDs from the user's current shortcuts
        self.selectedShortcutIds = Set(currentUserShortcuts.map { $0.shortcut.id })
    }

    func fetchAvailableShortcuts() {
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                self.availableShortcuts = try await apiService.getAvailable()
            } catch {
                self.errorMessage = "Failed to load shortcuts. Please try again."
                print("Error fetching shortcuts: \(error)")
            }
            self.isLoading = false
        }
    }
    
    func addShortcut(shortcut: Shortcut) {
        guard !selectedShortcutIds.contains(shortcut.id) else { return }
        
        // Optimistically update the UI
        selectedShortcutIds.insert(shortcut.id)
        
        Task {
            do {
                _ = try await apiService.add(shortcutId: shortcut.id)
            } catch {
                // If the API call fails, revert the optimistic update
                selectedShortcutIds.remove(shortcut.id)
                errorMessage = "Failed to add shortcut. Please try again."
            }
        }
    }

    func removeShortcut(userShortcut: UserShortcut) {
        let shortcutId = userShortcut.shortcut.id
        guard selectedShortcutIds.contains(shortcutId) else { return }
        
        // Optimistically update the UI
        selectedShortcutIds.remove(shortcutId)
        
        Task {
            do {
                try await apiService.delete(userShortcutId: userShortcut.id)
            } catch {
                // Revert on failure
                selectedShortcutIds.insert(shortcutId)
                errorMessage = "Failed to remove shortcut. Please try again."
            }
        }
    }
} 