import Foundation

class CacheManager {
    static let shared = CacheManager()
    private let fileManager = FileManager.default
    private let cacheDirectory: URL

    private init() {
        // Get the caches directory URL
        if let cachesDir = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first {
            self.cacheDirectory = cachesDir.appendingPathComponent("AppCache")
        } else {
            // Fallback or error handling if cachesDirectory is not found
            // For simplicity, we'll use a temporary directory, but in a real app, robust error handling is needed.
            self.cacheDirectory = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("AppCache")
            print("CacheManager: Warning - Caches directory not found. Using temporary directory.")
        }
        
        // Create the custom cache directory if it doesn't exist
        createDirectoryIfNeeded(at: self.cacheDirectory)
    }

    private func createDirectoryIfNeeded(at url: URL) {
        if !fileManager.fileExists(atPath: url.path) {
            do {
                try fileManager.createDirectory(at: url, withIntermediateDirectories: true, attributes: nil)
                print("CacheManager: Created cache directory at \(url.path)")
            } catch {
                print("CacheManager: Error creating cache directory at \(url.path): \(error)")
            }
        }
    }

    private func filePath(for key: String) -> URL {
        // Use a simple sanitization for the key to make it a valid filename
        let sanitizedKey = key.components(separatedBy: CharacterSet.alphanumerics.inverted).joined()
        return cacheDirectory.appendingPathComponent(sanitizedKey + ".json")
    }

    // Save a Codable object to a file
    func save<T: Codable>(object: T, to key: String) {
        let url = filePath(for: key)
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted // Optional: for easier debugging of cache files

        DispatchQueue.global(qos: .background).async {
            do {
                let data = try encoder.encode(object)
                try data.write(to: url, options: [.atomicWrite])
                print("CacheManager: Successfully saved data for key '\(key)' to \(url.path)")
            } catch {
                print("CacheManager: Error saving data for key '\(key)' to \(url.path): \(error)")
            }
        }
    }

    // Load a Codable object from a file
    func load<T: Codable>(from key: String, as type: T.Type) -> T? {
        let url = filePath(for: key)
        
        // Check if file exists before attempting to load (synchronous check for simplicity here)
        // For a fully async approach, this check might also be async.
        guard fileManager.fileExists(atPath: url.path) else {
            print("CacheManager: No cache file found for key '\(key)' at \(url.path)")
            return nil
        }

        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            // Ensure date decoding strategy matches what might be needed for your models
            // For now, assuming default or that models handle their own date strings.
            // If your models use Date types and specific formats, configure decoder here.
            // e.g., decoder.dateDecodingStrategy = ...
            let object = try decoder.decode(type, from: data)
            print("CacheManager: Successfully loaded data for key '\(key)' from \(url.path)")
            return object
        } catch {
            print("CacheManager: Error loading or decoding data for key '\(key)' from \(url.path): \(error)")
            // Optionally, delete the corrupted cache file
            // try? fileManager.removeItem(at: url)
            return nil
        }
    }

    // Public method to check if a cache file exists for a key
    func fileExists(for key: String) -> Bool {
        let url = filePath(for: key)
        return fileManager.fileExists(atPath: url.path)
    }
    
    // Function to clear a specific cache entry
    func clearCache(for key: String) {
        let url = filePath(for: key)
        DispatchQueue.global(qos: .background).async {
            do {
                if self.fileManager.fileExists(atPath: url.path) {
                    try self.fileManager.removeItem(at: url)
                    print("CacheManager: Cleared cache for key '\(key)' at \(url.path)")
                }
            } catch {
                print("CacheManager: Error clearing cache for key '\(key)': \(error)")
            }
        }
    }

    // Function to clear all AppCache
    func clearAllAppCache() {
        DispatchQueue.global(qos: .background).async {
            do {
                let contents = try self.fileManager.contentsOfDirectory(at: self.cacheDirectory, includingPropertiesForKeys: nil, options: [])
                for fileURL in contents {
                    try self.fileManager.removeItem(at: fileURL)
                }
                print("CacheManager: Cleared all app cache at \(self.cacheDirectory.path)")
            } catch {
                print("CacheManager: Error clearing all app cache: \(error)")
            }
        }
    }
}
