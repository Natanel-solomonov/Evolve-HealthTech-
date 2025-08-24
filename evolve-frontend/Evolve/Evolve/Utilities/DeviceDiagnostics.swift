import Foundation
import UIKit

class DeviceDiagnostics {
    static let shared = DeviceDiagnostics()
    
    private init() {}
    
    func logDeviceInfo() {
        let device = UIDevice.current
        let systemVersion = device.systemVersion
        let model = device.model
        let name = device.name
        
        print("=== Device Diagnostics ===")
        print("Device Model: \(model)")
        print("Device Name: \(name)")
        print("iOS Version: \(systemVersion)")
        
        let isSimulator = ProcessInfo.processInfo.environment["SIMULATOR_DEVICE_NAME"] != nil
        if isSimulator {
            print("Environment: iOS Simulator")
        } else {
            print("Environment: Physical Device")
        }
        
        // Check available memory
        let memoryInfo = getMemoryInfo()
        print("Available Memory: \(memoryInfo.available) MB")
        print("Total Memory: \(memoryInfo.total) MB")
        
        // Check network reachability
        checkNetworkReachability()
        
        print("=== End Device Diagnostics ===")
    }
    
    private func getMemoryInfo() -> (available: Int, total: Int) {
        var pagesize: vm_size_t = 0
        
        host_page_size(mach_host_self(), &pagesize)
        
        var vmStats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.size / MemoryLayout<integer_t>.size)
        
        let result = withUnsafeMutablePointer(to: &vmStats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }
        
        if result == KERN_SUCCESS {
            let available = Int(vmStats.free_count) * Int(pagesize) / 1024 / 1024
            let total = Int(vmStats.active_count + vmStats.inactive_count + vmStats.wire_count + vmStats.free_count) * Int(pagesize) / 1024 / 1024
            return (available, total)
        }
        
        return (0, 0)
    }
    
    private func checkNetworkReachability() {
        // Simple network check
        guard let url = URL(string: "https://www.apple.com") else {
            print("Network: Invalid test URL")
            return
        }
        
        let task = URLSession.shared.dataTask(with: url) { _, response, error in
            if let error = error {
                print("Network: Error - \(error.localizedDescription)")
            } else if let httpResponse = response as? HTTPURLResponse {
                print("Network: Status \(httpResponse.statusCode) - Reachable")
            } else {
                print("Network: Unknown response")
            }
        }
        task.resume()
    }
    
    func checkKeychainAccess() {
        print("=== Keychain Access Test ===")
        
        let testKey = "device_diagnostic_test"
        let testData = "test_value".data(using: .utf8)!
        
        do {
            try KeychainHelper.standard.saveData(testData, forKey: testKey)
            print("Keychain: Write test - SUCCESS")
            
            let retrievedData = try KeychainHelper.standard.loadData(forKey: testKey)
            if let retrievedString = String(data: retrievedData ?? Data(), encoding: .utf8) {
                print("Keychain: Read test - SUCCESS (\(retrievedString))")
            } else {
                print("Keychain: Read test - FAILED (data conversion)")
            }
            
            try KeychainHelper.standard.deleteData(forKey: testKey)
            print("Keychain: Delete test - SUCCESS")
            
        } catch {
            print("Keychain: Test FAILED - \(error.localizedDescription)")
        }
        
        print("=== End Keychain Test ===")
    }
} 