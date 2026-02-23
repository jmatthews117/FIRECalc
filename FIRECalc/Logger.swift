//
//  Logger.swift
//  FICalc
//
//  Conditional logging for performance optimization
//  In production, only errors are logged to reduce overhead
//

import Foundation
import os.log

/// Log levels in order of severity
enum LogLevel: Int, Comparable {
    case debug = 0
    case info = 1
    case warning = 2
    case error = 3
    
    static func < (lhs: LogLevel, rhs: LogLevel) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
    
    var emoji: String {
        switch self {
        case .debug: return "🔍"
        case .info: return "ℹ️"
        case .warning: return "⚠️"
        case .error: return "❌"
        }
    }
}

/// Efficient logger that respects build configuration
enum AppLogger {
    /// Current log level - debug in DEBUG builds, error in production
    static var minimumLevel: LogLevel = {
        #if DEBUG
        return .debug
        #else
        return .error
        #endif
    }()
    
    /// Log a message at the specified level
    /// Messages below minimumLevel are completely elided (no performance cost)
    ///
    /// Example:
    /// ```
    /// AppLogger.log("Fetching prices for \(assets.count) assets", level: .info)
    /// AppLogger.debug("Asset details: \(asset)")
    /// AppLogger.error("Failed to load: \(error)")
    /// ```
    static func log(
        _ message: @autoclosure () -> String,
        level: LogLevel = .info,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        guard level >= minimumLevel else { return }
        
        let filename = (file as NSString).lastPathComponent
        let prefix = "[\(filename):\(line)] \(level.emoji)"
        
        #if DEBUG
        print("\(prefix) \(message())")
        #else
        // In production, use os_log for better performance
        if level >= .error {
            os_log("%{public}s %{public}s", log: .default, type: .error, prefix, message())
        }
        #endif
    }
    
    /// Convenience method for debug logs (only in DEBUG builds)
    static func debug(_ message: @autoclosure () -> String, file: String = #file, line: Int = #line) {
        log(message(), level: .debug, file: file, line: line)
    }
    
    /// Convenience method for info logs
    static func info(_ message: @autoclosure () -> String, file: String = #file, line: Int = #line) {
        log(message(), level: .info, file: file, line: line)
    }
    
    /// Convenience method for warnings
    static func warning(_ message: @autoclosure () -> String, file: String = #file, line: Int = #line) {
        log(message(), level: .warning, file: file, line: line)
    }
    
    /// Convenience method for errors (always logged)
    static func error(_ message: @autoclosure () -> String, file: String = #file, line: Int = #line) {
        log(message(), level: .error, file: file, line: line)
    }
}

// MARK: - Performance Timing Helper

extension AppLogger {
    /// Measure and log execution time of a block
    ///
    /// Example:
    /// ```
    /// AppLogger.measure("Price refresh") {
    ///     await portfolioVM.refreshPrices()
    /// }
    /// ```
    static func measure<T>(
        _ label: String,
        level: LogLevel = .debug,
        operation: () throws -> T
    ) rethrows -> T {
        let start = CFAbsoluteTimeGetCurrent()
        let result = try operation()
        let elapsed = CFAbsoluteTimeGetCurrent() - start
        
        log("\(label) took \(String(format: "%.3f", elapsed))s", level: level)
        return result
    }
    
    /// Measure and log execution time of an async block
    static func measure<T>(
        _ label: String,
        level: LogLevel = .debug,
        operation: () async throws -> T
    ) async rethrows -> T {
        let start = CFAbsoluteTimeGetCurrent()
        let result = try await operation()
        let elapsed = CFAbsoluteTimeGetCurrent() - start
        
        log("\(label) took \(String(format: "%.3f", elapsed))s", level: level)
        return result
    }
}

// MARK: - Backwards Compatibility

/// Wrapper to gradually replace print() statements
func log(_ message: String, level: LogLevel = .info) {
    AppLogger.log(message, level: level)
}
