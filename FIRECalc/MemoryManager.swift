//
//  MemoryManager.swift
//  FIRECalc
//
//  Handles memory warnings and proactive memory management
//

import Foundation
import UIKit

@MainActor
class MemoryManager: ObservableObject {
    static let shared = MemoryManager()
    
    @Published var didReceiveMemoryWarning = false
    
    private init() {
        setupMemoryWarningNotification()
    }
    
    private func setupMemoryWarningNotification() {
        NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleMemoryWarning()
        }
    }
    
    private func handleMemoryWarning() {
        print("⚠️ MEMORY WARNING RECEIVED - Cleaning up...")
        didReceiveMemoryWarning = true
        
        // Clear caches
        HistoricalDataService.shared.clearCache()
        
        // Force cache cleanup
        URLCache.shared.removeAllCachedResponses()
        
        print("✅ Memory cleanup completed")
        
        // Reset warning flag after 5 seconds
        Task {
            try? await Task.sleep(for: .seconds(5))
            didReceiveMemoryWarning = false
        }
    }
    
    /// Get current memory usage in MB
    func currentMemoryUsage() -> Double {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_,
                         task_flavor_t(MACH_TASK_BASIC_INFO),
                         $0,
                         &count)
            }
        }
        
        if kerr == KERN_SUCCESS {
            return Double(info.resident_size) / 1024.0 / 1024.0 // Convert to MB
        }
        return 0
    }
    
    /// Log memory usage for debugging
    func logMemoryUsage(context: String = "") {
        let usage = currentMemoryUsage()
        let prefix = context.isEmpty ? "" : "[\(context)] "
        print("📊 \(prefix)Memory usage: \(String(format: "%.1f", usage)) MB")
    }
}
