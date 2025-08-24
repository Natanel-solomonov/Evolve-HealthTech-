import Foundation
import Security

// Define a more specific error type for Keychain operations if desired,
// or extend NetworkError if it's suitably generic.
// For now, using existing NetworkError cases or simple NSError.

class KeychainHelper {
    static let standard = KeychainHelper()
    private init() {}

    private func serviceIdentifier(for key: String) -> String {
        // Using bundle identifier makes the service unique to your app
        return (Bundle.main.bundleIdentifier ?? "com.example.EvolveApp") + "." + key
    }

    func saveData(_ data: Data, forKey key: String) throws {
        let service = serviceIdentifier(for: key)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key, // Using key as account
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly // Recommended accessibility
        ]

        // Delete any existing item first to ensure update behavior
        SecItemDelete(query as CFDictionary) // Ignore error if item not found

        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            print("KeychainHelper: Failed to save data for key '\(key)'. Status: \(status)")
            
            // For certain errors on physical devices, we might want to be more lenient
            if status == errSecNotAvailable || status == errSecInteractionNotAllowed {
                print("KeychainHelper: Keychain not available or interaction not allowed. This might be normal on physical devices during certain states.")
                // Don't throw for these cases, just log and continue
                return
            }
            
            throw NSError(domain: NSOSStatusErrorDomain, code: Int(status), userInfo: [NSLocalizedDescriptionKey: "Failed to save data to Keychain: \(status)"])
        }
        print("KeychainHelper: Successfully saved data for key '\(key)'")
    }

    func loadData(forKey key: String) throws -> Data? {
        let service = serviceIdentifier(for: key)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: kCFBooleanTrue!,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var dataTypeRef: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &dataTypeRef)

        if status == errSecSuccess {
            print("KeychainHelper: Successfully loaded data for key '\(key)'")
            return dataTypeRef as? Data
        } else if status == errSecItemNotFound {
            print("KeychainHelper: No data found in Keychain for key '\(key)'")
            return nil
        } else {
            print("KeychainHelper: Failed to load data for key '\(key)'. Status: \(status)")
            // For certain keychain errors, we might want to be more lenient
            if status == errSecNotAvailable || status == errSecInteractionNotAllowed {
                print("KeychainHelper: Keychain not available or interaction not allowed. This might be normal during app launch.")
                return nil
            }
            throw NSError(domain: NSOSStatusErrorDomain, code: Int(status), userInfo: [NSLocalizedDescriptionKey: "Failed to load data from Keychain: \(status)"])
        }
    }

    func deleteData(forKey key: String) throws {
        let service = serviceIdentifier(for: key)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]

        let status = SecItemDelete(query as CFDictionary)
        if status != errSecSuccess && status != errSecItemNotFound {
            print("KeychainHelper: Failed to delete data for key '\(key)'. Status: \(status)")
            throw NSError(domain: NSOSStatusErrorDomain, code: Int(status), userInfo: [NSLocalizedDescriptionKey: "Failed to delete data from Keychain: \(status)"])
        }
        print("KeychainHelper: Successfully deleted data for key '\(key)' (or it was not found)")
    }

    // Convenience methods for strings
    func saveString(_ string: String, forKey key: String) throws {
        guard let data = string.data(using: .utf8) else {
            // Consider using a custom KeychainError or a more specific NetworkError case
            throw NetworkError.encodingError("Could not convert string to data for Keychain saving for key '\(key)'.")
        }
        try saveData(data, forKey: key)
    }

    func loadString(forKey key: String) throws -> String? {
        guard let data = try loadData(forKey: key) else { return nil }
        guard let string = String(data: data, encoding: .utf8) else {
            print("KeychainHelper: Warning - Could not convert loaded Keychain data to String for key '\(key)'. Data might be corrupted or not a UTF-8 string.")
            // Consider using a custom KeychainError or a more specific NetworkError case
            throw NetworkError.decodingError("Could not convert Keychain data to String for key '\(key)'.")
        }
        return string
    }
}

// Assuming NetworkError is defined elsewhere (e.g., in AuthenticationManager.swift)
// If not, you might need to define it or a similar error enum here.
// enum KeychainError: Error {
//     case encodingError(String)
//     case decodingError(String)
//     case underlyingError(NSError)
// } 