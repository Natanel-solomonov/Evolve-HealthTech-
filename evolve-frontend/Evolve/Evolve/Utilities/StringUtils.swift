import Foundation

// Note: This file uses models from Nutrition.swift, FoodProduct.swift
// The import is handled through the module structure in Xcode

// MARK: - Fuzzy String Matching Utilities
struct StringMatcher {
    
    /// Calculates the Levenshtein distance between two strings
    static func levenshteinDistance(_ str1: String, _ str2: String) -> Int {
        let str1Array = Array(str1.lowercased())
        let str2Array = Array(str2.lowercased())
        let str1Count = str1Array.count
        let str2Count = str2Array.count
        
        var matrix = Array(repeating: Array(repeating: 0, count: str2Count + 1), count: str1Count + 1)
        
        for i in 0...str1Count {
            matrix[i][0] = i
        }
        
        for j in 0...str2Count {
            matrix[0][j] = j
        }
        
        for i in 1...str1Count {
            for j in 1...str2Count {
                let cost = str1Array[i-1] == str2Array[j-1] ? 0 : 1
                matrix[i][j] = min(
                    matrix[i-1][j] + 1,      // deletion
                    matrix[i][j-1] + 1,      // insertion
                    matrix[i-1][j-1] + cost  // substitution
                )
            }
        }
        
        return matrix[str1Count][str2Count]
    }
    
    /// Calculates similarity ratio between two strings (0.0 to 1.0, where 1.0 is exact match)
    static func similarityRatio(_ str1: String, _ str2: String) -> Double {
        let maxLength = max(str1.count, str2.count)
        if maxLength == 0 { return 1.0 }
        
        let distance = levenshteinDistance(str1, str2)
        return 1.0 - (Double(distance) / Double(maxLength))
    }
    
    /// Normalizes a product name for better matching
    static func normalizeProductName(_ name: String) -> String {
        return name
            .lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: #"[^\w\s]"#, with: "", options: .regularExpression) // Remove special characters
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression) // Normalize whitespace
            .trimmingCharacters(in: .whitespaces)
    }
    
    /// Extracts key brand/product tokens for matching
    static func extractKeyTokens(_ name: String) -> [String] {
        let normalized = normalizeProductName(name)
        let tokens = normalized.components(separatedBy: " ")
        
        // Filter out common words that don't help with matching
        let stopWords = Set(["the", "and", "or", "of", "a", "an", "in", "on", "at", "to", "for", "with", "by"])
        return tokens.filter { !stopWords.contains($0) && $0.count > 1 }
    }
    
    /// Advanced similarity matching using multiple techniques
    static func advancedSimilarity(_ str1: String, _ str2: String) -> Double {
        let normalized1 = normalizeProductName(str1)
        let normalized2 = normalizeProductName(str2)
        
        // Exact match after normalization
        if normalized1 == normalized2 {
            return 1.0
        }
        
        // Check if one contains the other
        if normalized1.contains(normalized2) || normalized2.contains(normalized1) {
            return 0.9
        }
        
        // Token-based matching
        let tokens1 = Set(extractKeyTokens(str1))
        let tokens2 = Set(extractKeyTokens(str2))
        
        if !tokens1.isEmpty && !tokens2.isEmpty {
            let intersection = tokens1.intersection(tokens2)
            let union = tokens1.union(tokens2)
            let jaccardSimilarity = Double(intersection.count) / Double(union.count)
            
            if jaccardSimilarity > 0.5 {
                return jaccardSimilarity * 0.8 + similarityRatio(normalized1, normalized2) * 0.2
            }
        }
        
        // Fallback to Levenshtein similarity
        return similarityRatio(normalized1, normalized2)
    }
}

// MARK: - Product Mapping Service
class ProductMappingService: ObservableObject {
    static let shared = ProductMappingService()
    
    private var alcoholProductsCache: [AlcoholicBeverage] = []
    private var caffeineProductsCache: [CaffeineProduct] = []
    private var mappingCache: [String: String] = [:]
    
    private init() {}
    
    /// Updates the cached alcohol products
    func updateAlcoholProducts(_ products: [AlcoholicBeverage]) {
        self.alcoholProductsCache = products
    }
    
    /// Updates the cached caffeine products
    func updateCaffeineProducts(_ products: [CaffeineProduct]) {
        self.caffeineProductsCache = products
    }
    
    /// Finds the best matching alcohol product for a given food product name
    func findBestAlcoholMatch(for foodProductName: String, threshold: Double = 0.6) -> AlcoholicBeverage? {
        // Check cache first
        let cacheKey = "alcohol_\(foodProductName.lowercased())"
        if let cachedId = mappingCache[cacheKey],
           let cached = alcoholProductsCache.first(where: { $0.id == cachedId }) {
            return cached
        }
        
        var bestMatch: AlcoholicBeverage?
        var bestScore: Double = threshold
        
        for alcoholProduct in alcoholProductsCache {
            // Check against product name
            let nameScore = StringMatcher.advancedSimilarity(foodProductName, alcoholProduct.name)
            
            // Check against brand + name combination
            let brandNameScore: Double
            if let brand = alcoholProduct.brand {
                let fullName = "\(brand) \(alcoholProduct.name)"
                brandNameScore = StringMatcher.advancedSimilarity(foodProductName, fullName)
            } else {
                brandNameScore = 0.0
            }
            
            let finalScore = max(nameScore, brandNameScore)
            
            if finalScore > bestScore {
                bestScore = finalScore
                bestMatch = alcoholProduct
            }
        }
        
        // Cache the result if found
        if let match = bestMatch {
            mappingCache[cacheKey] = match.id
        }
        
        return bestMatch
    }
    
    /// Finds the best matching caffeine product for a given food product name
    func findBestCaffeineMatch(for foodProductName: String, threshold: Double = 0.6) -> CaffeineProduct? {
        // Check cache first
        let cacheKey = "caffeine_\(foodProductName.lowercased())"
        if let cachedId = mappingCache[cacheKey],
           let cached = caffeineProductsCache.first(where: { $0.id == cachedId }) {
            return cached
        }
        
        var bestMatch: CaffeineProduct?
        var bestScore: Double = threshold
        
        for caffeineProduct in caffeineProductsCache {
            // Check against product name
            let nameScore = StringMatcher.advancedSimilarity(foodProductName, caffeineProduct.name)
            
            // Check against brand + name combination
            let brandNameScore: Double
            if let brand = caffeineProduct.brand {
                let fullName = "\(brand) \(caffeineProduct.name)"
                brandNameScore = StringMatcher.advancedSimilarity(foodProductName, fullName)
            } else {
                brandNameScore = 0.0
            }
            
            // Check against display name
            let displayNameScore = StringMatcher.advancedSimilarity(foodProductName, caffeineProduct.displayName)
            
            let finalScore = max(nameScore, brandNameScore, displayNameScore)
            
            if finalScore > bestScore {
                bestScore = finalScore
                bestMatch = caffeineProduct
            }
        }
        
        // Cache the result if found
        if let match = bestMatch {
            mappingCache[cacheKey] = match.id
        }
        
        return bestMatch
    }
    
    /// Attempts to map a food product to either alcohol or caffeine product
    func mapFoodProduct(_ foodProduct: FoodProduct) -> MappedProductResult? {
        guard let productName = foodProduct.productName else { return nil }
        
        // Try alcohol mapping first
        if let alcoholMatch = findBestAlcoholMatch(for: productName) {
            return .alcohol(alcoholMatch)
        }
        
        // Try caffeine mapping
        if let caffeineMatch = findBestCaffeineMatch(for: productName) {
            return .caffeine(caffeineMatch)
        }
        
        return nil
    }
    
    /// Clears the mapping cache
    func clearCache() {
        mappingCache.removeAll()
    }
}

// MARK: - Mapped Product Result
enum MappedProductResult {
    case alcohol(AlcoholicBeverage)
    case caffeine(CaffeineProduct)
}

// MARK: - Enhanced Barcode Product Result
enum EnhancedBarcodeProductResult {
    case food(FoodProduct)
    case alcohol(AlcoholicBeverage)
    case caffeine(CaffeineProduct)
    case mappedAlcohol(FoodProduct, AlcoholicBeverage) // Original food + mapped alcohol
    case mappedCaffeine(FoodProduct, CaffeineProduct) // Original food + mapped caffeine
} 