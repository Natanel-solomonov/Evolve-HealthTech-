import Foundation

/// Dedicated cache manager for affiliate promotions with better key handling
class AffiliatePromotionCache {
    static let shared = AffiliatePromotionCache()
    
    private let fileManager = FileManager.default
    private let cacheDirectory: URL
    private let cacheExpiryInterval: TimeInterval = 15 * 60 // 15 minutes
    
    // Date formatters for handling different ISO8601 formats
    private static let iso8601FractionalSecondsFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSSSSZ"
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter
    }()
    
    private static let iso8601StandardFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter
    }()
    
    // Custom date decoding strategy that handles multiple ISO8601 formats
    @Sendable
    private static func customDateDecodingStrategy(decoder: Decoder) throws -> Date {
        let container = try decoder.singleValueContainer()
        let dateString = try container.decode(String.self)
        
        // Try fractional seconds format first
        if let date = iso8601FractionalSecondsFormatter.date(from: dateString) {
            return date
        }
        
        // Try standard format without fractional seconds
        if let date = iso8601StandardFormatter.date(from: dateString) {
            return date
        }
        
        // Try ISO8601DateFormatter as fallback
        if let date = ISO8601DateFormatter().date(from: dateString) {
            return date
        }
        
        throw DecodingError.dataCorrupted(
            DecodingError.Context(
                codingPath: decoder.codingPath,
                debugDescription: "Invalid date format: \(dateString)"
            )
        )
    }
    
    private init() {
        // Get the caches directory URL
        if let cachesDir = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first {
            self.cacheDirectory = cachesDir.appendingPathComponent("AffiliatePromotionCache")
        } else {
            // Fallback to temporary directory
            self.cacheDirectory = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("AffiliatePromotionCache")
            print("AffiliatePromotionCache: Warning - Caches directory not found. Using temporary directory.")
        }
        
        // Create the cache directory if it doesn't exist
        createDirectoryIfNeeded(at: self.cacheDirectory)
    }
    
    private func createDirectoryIfNeeded(at url: URL) {
        if !fileManager.fileExists(atPath: url.path) {
            do {
                try fileManager.createDirectory(at: url, withIntermediateDirectories: true, attributes: nil)
                print("AffiliatePromotionCache: Created cache directory at \(url.path)")
            } catch {
                print("AffiliatePromotionCache: Error creating cache directory: \(error)")
            }
        }
    }
    
    private func cacheKey(for userId: String, activeOnly: Bool) -> String {
        return "user_\(userId)_active_\(activeOnly)"
    }
    
    private func filePath(for key: String) -> URL {
        // Use SHA256 hash to create a safe filename while preserving uniqueness
        let hashedKey = key.sha256
        return cacheDirectory.appendingPathComponent("\(hashedKey).json")
    }
    
    private func metadataFilePath(for key: String) -> URL {
        let hashedKey = key.sha256
        return cacheDirectory.appendingPathComponent("\(hashedKey)_metadata.json")
    }
    
    /// Save promotions to cache with metadata
    func save(promotions: [AffiliatePromotion], for userId: String, activeOnly: Bool) {
        let key = cacheKey(for: userId, activeOnly: activeOnly)
        let dataUrl = filePath(for: key)
        let metadataUrl = metadataFilePath(for: key)
        
        DispatchQueue.global(qos: .background).async {
            do {
                // Save promotions data
                let encoder = JSONEncoder()
                encoder.dateEncodingStrategy = .iso8601
                let promotionData = try encoder.encode(promotions)
                try promotionData.write(to: dataUrl, options: [.atomicWrite])
                
                // Save metadata
                let metadata = CacheMetadata(
                    cachedAt: Date(),
                    userId: userId,
                    activeOnly: activeOnly,
                    count: promotions.count
                )
                let metadataData = try encoder.encode(metadata)
                try metadataData.write(to: metadataUrl, options: [.atomicWrite])
                
                print("AffiliatePromotionCache: Saved \(promotions.count) promotions for user \(userId) (activeOnly: \(activeOnly))")
            } catch {
                print("AffiliatePromotionCache: Error saving data: \(error)")
            }
        }
    }
    
    /// Load promotions from cache if not expired
    func load(for userId: String, activeOnly: Bool) -> [AffiliatePromotion]? {
        let key = cacheKey(for: userId, activeOnly: activeOnly)
        let dataUrl = filePath(for: key)
        let metadataUrl = metadataFilePath(for: key)
        
        // Check if files exist
        guard fileManager.fileExists(atPath: dataUrl.path),
              fileManager.fileExists(atPath: metadataUrl.path) else {
            print("AffiliatePromotionCache: No cache found for user \(userId) (activeOnly: \(activeOnly))")
            return nil
        }
        
        do {
            // Load and check metadata
            let metadataData = try Data(contentsOf: metadataUrl)
            let metadataDecoder = JSONDecoder()
            metadataDecoder.dateDecodingStrategy = .iso8601
            let metadata = try metadataDecoder.decode(CacheMetadata.self, from: metadataData)
            
            // Check if cache is expired
            let timeSinceCache = Date().timeIntervalSince(metadata.cachedAt)
            if timeSinceCache > cacheExpiryInterval {
                print("AffiliatePromotionCache: Cache expired for user \(userId) (age: \(Int(timeSinceCache))s)")
                return nil
            }
            
            // Load promotions data with custom date strategy to match backend formats
            let promotionData = try Data(contentsOf: dataUrl)
            let promotionDecoder = JSONDecoder()
            promotionDecoder.dateDecodingStrategy = .custom(Self.customDateDecodingStrategy)
            let promotions = try promotionDecoder.decode([AffiliatePromotion].self, from: promotionData)
            
            print("AffiliatePromotionCache: Loaded \(promotions.count) cached promotions for user \(userId) (activeOnly: \(activeOnly))")
            return promotions
            
        } catch {
            print("AffiliatePromotionCache: Error loading cache: \(error)")
            // Clean up corrupted cache files
            try? fileManager.removeItem(at: dataUrl)
            try? fileManager.removeItem(at: metadataUrl)
            return nil
        }
    }
    
    /// Clear cache for specific user and active state
    func clear(for userId: String, activeOnly: Bool) {
        let key = cacheKey(for: userId, activeOnly: activeOnly)
        let dataUrl = filePath(for: key)
        let metadataUrl = metadataFilePath(for: key)
        
        DispatchQueue.global(qos: .background).async { [weak self] in
            guard let self = self else { return }
            do {
                if self.fileManager.fileExists(atPath: dataUrl.path) {
                    try self.fileManager.removeItem(at: dataUrl)
                }
                if self.fileManager.fileExists(atPath: metadataUrl.path) {
                    try self.fileManager.removeItem(at: metadataUrl)
                }
                print("AffiliatePromotionCache: Cleared cache for user \(userId) (activeOnly: \(activeOnly))")
            } catch {
                print("AffiliatePromotionCache: Error clearing cache: \(error)")
            }
        }
    }
    
    /// Clear all cache for a specific user
    func clearAll(for userId: String) {
        clear(for: userId, activeOnly: true)
        clear(for: userId, activeOnly: false)
    }
    
    /// Clear all cached data
    func clearAll() {
        DispatchQueue.global(qos: .background).async { [weak self] in
            guard let self = self else { return }
            do {
                let contents = try self.fileManager.contentsOfDirectory(at: self.cacheDirectory, includingPropertiesForKeys: nil, options: [])
                for fileURL in contents {
                    try self.fileManager.removeItem(at: fileURL)
                }
                print("AffiliatePromotionCache: Cleared all cache")
            } catch {
                print("AffiliatePromotionCache: Error clearing all cache: \(error)")
            }
        }
    }
}

// MARK: - Supporting Types

private struct CacheMetadata: Codable {
    let cachedAt: Date
    let userId: String
    let activeOnly: Bool
    let count: Int
}

import CryptoKit

// MARK: - String Extension for SHA256

private extension String {
    var sha256: String {
        let data = Data(self.utf8)
        let digest = SHA256.hash(data: data)
        return digest.compactMap { String(format: "%02x", $0) }.joined()
    }
} 