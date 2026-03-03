//
//  PerformanceHelpers.swift
//  FIRECalc
//
//  Helper functions and extensions for performance optimization
//

import Foundation
import SwiftUI

// MARK: - Chart Data Optimization

/// Downsamples large datasets for efficient chart rendering
/// Reduces memory usage and improves frame rate for charts with 100+ data points
struct ChartDataOptimizer {
    
    /// Downsamples data points while preserving shape
    /// - Parameters:
    ///   - data: Original data array
    ///   - maxPoints: Maximum number of points to return
    /// - Returns: Optimized array with reduced point count
    static func downsample<T>(_ data: [T], maxPoints: Int = 200) -> [T] {
        guard data.count > maxPoints else { return data }
        
        let stride = data.count / maxPoints
        return data.enumerated()
            .filter { $0.offset % stride == 0 }
            .map { $0.element }
    }
    
    /// Downsamples with preserved indices for keyed data
    static func downsampleWithIndices<T>(_ data: [T], maxPoints: Int = 200) -> [(index: Int, value: T)] {
        guard data.count > maxPoints else {
            return data.enumerated().map { (index: $0.offset, value: $0.element) }
        }
        
        let stride = data.count / maxPoints
        return data.enumerated()
            .filter { $0.offset % stride == 0 }
            .map { (index: $0.offset, value: $0.element) }
    }
}

// MARK: - Debounced Value

/// Provides debounced updates to reduce excessive recomputation
@MainActor
class DebouncedValue<T>: ObservableObject {
    @Published private(set) var value: T
    private var task: Task<Void, Never>?
    
    init(initialValue: T) {
        self.value = initialValue
    }
    
    func update(_ newValue: T, delay: Duration = .milliseconds(500)) {
        task?.cancel()
        task = Task {
            try? await Task.sleep(for: delay)
            guard !Task.isCancelled else { return }
            value = newValue
        }
    }
    
    func updateImmediately(_ newValue: T) {
        task?.cancel()
        value = newValue
    }
}

// MARK: - Currency Formatter Cache

/// Singleton formatter cache to avoid recreating formatters
enum FormatterCache {
    static let currency: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.maximumFractionDigits = 2
        return formatter
    }()
    
    static let decimal: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = ","
        formatter.maximumFractionDigits = 2
        return formatter
    }()
    
    static let percent: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .percent
        formatter.maximumFractionDigits = 2
        return formatter
    }()
}

// MARK: - Async Image Cache

/// Simple memory cache for asset icons/images
actor ImageCache {
    static let shared = ImageCache()
    private var cache: [String: Data] = [:]
    
    func image(for key: String) -> Data? {
        cache[key]
    }
    
    func store(_ data: Data, for key: String) {
        cache[key] = data
    }
    
    func clear() {
        cache.removeAll()
    }
}

// MARK: - View Modifiers for Performance

extension View {
    /// Reduces motion for accessibility and performance
    func reducedMotionIfNeeded() -> some View {
        self.transaction { transaction in
            if UIAccessibility.isReduceMotionEnabled {
                transaction.animation = nil
            }
        }
    }
    
    /// Disables animations for large datasets
    func conditionalAnimation(threshold: Int, count: Int) -> some View {
        self.animation(count > threshold ? nil : .default, value: count)
    }
}

// MARK: - Memory Monitor (Debug Helper)

#if DEBUG
class MemoryMonitor: ObservableObject {
    @Published var usedMemoryMB: Double = 0
    private var timer: Timer?
    
    func startMonitoring() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.updateMemoryUsage()
        }
    }
    
    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
    }
    
    private func updateMemoryUsage() {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
        
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        
        if result == KERN_SUCCESS {
            usedMemoryMB = Double(info.resident_size) / 1024.0 / 1024.0
        }
    }
}
#endif

// MARK: - Background Queue Helper

/// Provides optimized background processing queues
enum BackgroundQueue {
    static let calculation = DispatchQueue(label: "com.firecalc.calculation", qos: .userInitiated)
    static let persistence = DispatchQueue(label: "com.firecalc.persistence", qos: .utility)
    static let networking = DispatchQueue(label: "com.firecalc.networking", qos: .userInitiated)
}

// MARK: - Task Priority Helper

extension Task where Success == Never, Failure == Never {
    /// Optimized sleep with priority awareness
    static func prioritySleep(seconds: Double, priority: TaskPriority = .medium) async throws {
        let nanoseconds = UInt64(seconds * 1_000_000_000)
        try await Task.sleep(nanoseconds: nanoseconds)
    }
}
