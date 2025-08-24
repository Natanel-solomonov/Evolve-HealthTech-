import Foundation
import SwiftUI

@MainActor
class ContentViewModel: ObservableObject {
    @Published var readingContents: [ReadingContentModel] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    private let readingContentAPI: ReadingContentAPI
    private let authenticationManager: AuthenticationManager
    private let cacheKey = "cachedReadingContents" // Define a cache key

    init(authenticationManager: AuthenticationManager) {
        self.authenticationManager = authenticationManager
        self.readingContentAPI = ReadingContentAPI(httpClient: authenticationManager.httpClient)
    }

    func fetchReadingContentData() {
        // Check if user is authenticated before attempting to fetch
        guard authenticationManager.isUserLoggedIn else {
            print("ContentViewModel: User not authenticated, skipping reading content fetch.")
            return
        }
        
        let localCacheKey = self.cacheKey // Use the instance property

        // Try to load from cache first
        if let cachedContents = CacheManager.shared.load(from: localCacheKey, as: [ReadingContentModel].self) {
            print("ContentViewModel: Loaded reading contents from cache.")
            self.readingContents = cachedContents
            // isLoading remains false for cache hits, allowing silent background refresh
        } else {
            // Cache miss, so we will show loading indicator for the initial fetch
            print("ContentViewModel: No cache found for reading contents. Will fetch from network.")
            self.isLoading = true
            self.errorMessage = nil
        }

        // Temporarily disabled network fetch
        /*
        readingContentAPI.fetchReadingContents { [weak self] result in
            DispatchQueue.main.async {
                guard let strongSelf = self else { return }

                switch result {
                case .success(let contents):
                    print("ContentViewModel: Network fetch successful for reading contents.")
                    // Update UI only if data has changed or if it was an initial load (cache miss)
                    if strongSelf.readingContents != contents || !CacheManager.shared.fileExists(for: strongSelf.cacheKey) {
                        strongSelf.readingContents = contents
                    }
                    CacheManager.shared.save(object: contents, to: strongSelf.cacheKey)
                case .failure(let error):
                    print("ContentViewModel: Network fetch failed for reading contents: \(error.localizedDescription)")
                    // Only set error message if we didn't have cached data to display
                    if !CacheManager.shared.fileExists(for: strongSelf.cacheKey) {
                        strongSelf.errorMessage = "Failed to fetch reading content: \(error.localizedDescription)"
                    }
                }
                // Always set isLoading to false after the network attempt is complete, 
                // especially if it was set true on a cache miss.
                if strongSelf.isLoading { // Only set to false if it was true
                    strongSelf.isLoading = false
                }
            }
        }
        */
        
        // Set loading to false since we're not making network calls
        if self.isLoading {
            self.isLoading = false
        }
    }
}
