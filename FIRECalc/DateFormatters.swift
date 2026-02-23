//
//  DateFormatters.swift
//  FIRECalc
//
//  Shared date formatters for performance optimization
//  Creating DateFormatter instances is expensive - reuse these instead
//

import Foundation

/// Shared date formatters - these are thread-safe and significantly faster than creating new instances
enum DateFormatters {
    /// Short date format (e.g., "1/15/24")
    static let short: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .none
        return formatter
    }()
    
    /// Medium date format (e.g., "Jan 15, 2024")
    static let medium: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()
    
    /// Long date format (e.g., "January 15, 2024")
    static let long: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.timeStyle = .none
        return formatter
    }()
    
    /// Short date and time (e.g., "1/15/24, 3:30 PM")
    static let shortDateTime: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter
    }()
    
    /// Medium date and time (e.g., "Jan 15, 2024 at 3:30 PM")
    static let mediumDateTime: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()
    
    /// Relative date formatter (e.g., "2 hours ago", "Yesterday")
    static let relative: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter
    }()
}

// MARK: - Note on Date Extensions
//
// Date formatting extensions (shortFormatted, mediumFormatted, etc.) 
// already exist in constants.swift - no need to duplicate them here.
// 
// To use these shared formatters directly without extensions:
//   DateFormatters.short.string(from: date)
//   DateFormatters.medium.string(from: date)

