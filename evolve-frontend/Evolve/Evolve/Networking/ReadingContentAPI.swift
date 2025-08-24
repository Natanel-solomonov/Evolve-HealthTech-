import Foundation

// Assuming ReadingContentModel Codable struct is defined elsewhere and matches ReadingContentSerializer.
// struct ReadingContentModel: Codable, Identifiable { ... }

// Assuming ContentCardModel Codable struct is defined elsewhere and matches ContentCardSerializer.
// struct ContentCardModel: Codable, Identifiable { ... }

// NetworkError is expected from AuthenticationManager.swift

class ReadingContentAPI {

    private let httpClient: AuthenticatedHTTPClient

    init(httpClient: AuthenticatedHTTPClient) {
        self.httpClient = httpClient
    }

    func fetchReadingContents(completion: @escaping (Result<[ReadingContentModel], NetworkError>) -> Void) {
        let endpoint = "/reading-contents/"
        Task {
            do {
                // Backend ReadingContentViewSet GET (list) is IsAuthenticated
                let contents: [ReadingContentModel] = try await httpClient.request(endpoint: endpoint, method: "GET", requiresAuth: true)
                completion(.success(contents))
            } catch {
                completion(.failure(error as? NetworkError ?? .custom(message: "Unknown error fetching reading contents")))
            }
        }
    }
    
    // Placeholder for fetching a single reading content item by its ID (UUID if backend uses UUID PKs for ReadingContent)
    // func fetchReadingContent(id: String, completion: @escaping (Result<ReadingContentModel, NetworkError>) -> Void) {
    //     let endpoint = "/reading-contents/\\(id)/"
    //     Task {
    //         do {
    //             let content: ReadingContentModel = try await httpClient.request(endpoint: endpoint, method: "GET", requiresAuth: true)
    //             completion(.success(content))
    //         } catch {
    //             completion(.failure(error as? NetworkError ?? .custom(message: "Unknown error fetching reading content item")))
    //         }
    //     }
    // }

    func fetchContentCards(completion: @escaping (Result<[ContentCardModel], NetworkError>) -> Void) {
        let endpoint = "/content-cards/"
        Task {
            do {
                // Backend ContentCardViewSet GET (list) is IsAuthenticated
                let cards: [ContentCardModel] = try await httpClient.request(endpoint: endpoint, method: "GET", requiresAuth: true)
                completion(.success(cards))
            } catch {
                completion(.failure(error as? NetworkError ?? .custom(message: "Unknown error fetching content cards")))
            }
        }
    }
    
    // Placeholder for fetching a single content card item by its ID (Int if backend uses Int PKs for ContentCard)
    // func fetchContentCard(id: Int, completion: @escaping (Result<ContentCardModel, NetworkError>) -> Void) {
    //     let endpoint = "/content-cards/\\(id)/"
    //     Task {
    //         do {
    //             let card: ContentCardModel = try await httpClient.request(endpoint: endpoint, method: "GET", requiresAuth: true)
    //             completion(.success(card))
    //         } catch {
    //             completion(.failure(error as? NetworkError ?? .custom(message: "Unknown error fetching content card item")))
    //         }
    //     }
    // }
}
