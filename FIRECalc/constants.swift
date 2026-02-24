//
//  Constants.swift
//  FIRECalc
//
//  App-wide constants and configuration
//

import Foundation
import SwiftUI

enum AppConstants {
    
    // MARK: - App Information
    static let appName = "FIRECalc"
    static let appVersion = "1.0"
    static let buildNumber = "1"
    
    // MARK: - Simulation Defaults
    enum Simulation {
        static let defaultRuns = 10000
        static let minRuns = 100
        static let maxRuns = 100000
        
        static let defaultTimeHorizon = 30
        static let minTimeHorizon = 1
        static let maxTimeHorizon = 50
        
        static let defaultInflationRate = 0.02
        static let minInflationRate = -0.05
        static let maxInflationRate = 0.15
        
        static let quickSimulationRuns = 1000  // For fast preview
        static let detailedSimulationRuns = 10000
    }
    
    // MARK: - Price Data API
    enum API {
        static let priceDataBaseURL = "https://query1.finance.yahoo.com/v8/finance/chart/"
        static let refreshInterval: TimeInterval = 3600  // 1 hour in seconds
        static let cacheExpiration: TimeInterval = 300   // 5 minutes
    }
    
    // MARK: - User Defaults Keys
    enum UserDefaultsKeys {
        static let lastSyncDate = "last_sync_date"
        static let hasCompletedOnboarding = "has_completed_onboarding"
        static let preferredCurrency = "preferred_currency"
        static let defaultSimulationRuns = "default_simulation_runs"
        static let defaultTimeHorizon = "default_time_horizon"
        static let defaultInflationRate = "default_inflation_rate"
        static let useHistoricalBootstrap = "use_historical_bootstrap"
        static let autoRefreshPrices = "auto_refresh_prices"
        static let priceRefreshInterval = "price_refresh_interval"

        // Retirement planning — kept in sync with @AppStorage keys in DashboardTabView
        static let currentAge = "current_age"
        static let annualSavings = "annual_savings"
        static let expectedAnnualSpend = "expected_annual_spend"
        static let withdrawalPercentage = "withdrawal_percentage"
        static let retirementTarget = "retirement_target"
        static let expectedReturn = "expected_return"
        static let inflationRate = "inflation_rate"
    }
    
    // MARK: - File Storage
    enum Storage {
        static let portfolioFileName = "portfolios.json"
        static let profileFileName = "user_profile.json"
        static let simulationHistoryFileName = "simulation_history.json"
        static let performanceSnapshotsFileName = "performance_snapshots.json"
    }
    
    // MARK: - Formatting
    enum Format {
        static let currencyCode = "USD"
        static let currencySymbol = "$"
        
        static let percentFormatter: NumberFormatter = {
            let formatter = NumberFormatter()
            formatter.numberStyle = .percent
            formatter.minimumFractionDigits = 1
            formatter.maximumFractionDigits = 2
            return formatter
        }()
        
        static let currencyFormatter: NumberFormatter = {
            let formatter = NumberFormatter()
            formatter.numberStyle = .currency
            formatter.currencyCode = currencyCode
            formatter.maximumFractionDigits = 0
            return formatter
        }()
        
        static let preciseCurrencyFormatter: NumberFormatter = {
            let formatter = NumberFormatter()
            formatter.numberStyle = .currency
            formatter.currencyCode = currencyCode
            formatter.maximumFractionDigits = 2
            return formatter
        }()
        
        static let decimalFormatter: NumberFormatter = {
            let formatter = NumberFormatter()
            formatter.numberStyle = .decimal
            formatter.minimumFractionDigits = 0
            formatter.maximumFractionDigits = 2
            return formatter
        }()
    }
    
    // MARK: - UI Configuration
    enum UI {
        static let cornerRadius: CGFloat = 12
        static let shadowRadius: CGFloat = 4
        static let cardPadding: CGFloat = 16
        static let sectionSpacing: CGFloat = 20
        
        static let animationDuration: Double = 0.3
        static let chartAnimationDuration: Double = 0.8
        
        static let minimumTouchTarget: CGFloat = 44
    }
    
    // MARK: - Color Theme
    enum Colors {
        // Success/Growth colors
        static let success = Color.green
        static let successLight = Color.green.opacity(0.2)
        
        // Warning colors
        static let warning = Color.orange
        static let warningLight = Color.orange.opacity(0.2)
        
        // Danger/Risk colors
        static let danger = Color.red
        static let dangerLight = Color.red.opacity(0.2)
        
        // Neutral colors
        static let primary = Color.blue
        static let secondary = Color.gray
        static let accent = Color.purple
        
        // Chart colors
        static let chartColors: [Color] = [
            .blue, .green, .purple, .orange, .yellow, .pink, .cyan, .brown
        ]
        
        /// Returns the canonical traffic-light colour for a Monte Carlo success rate.
        static func successRateColor(for rate: Double) -> Color {
            if rate >= 0.9 { return success }
            if rate >= 0.75 { return warning }
            return danger
        }
    }
    
    // MARK: - Simulation Interpretation
    enum SimulationInterpretation {
        /// Human-readable verdict for a Monte Carlo success rate.
        static func summary(for rate: Double) -> String {
            switch rate {
            case 0.95...: return "Excellent! Very high confidence your retirement plan will succeed."
            case 0.85...: return "Good. Strong likelihood of success with some risk of shortfall."
            case 0.75...: return "Moderate. Consider increasing savings or reducing withdrawal rate."
            default:      return "Concerning. High risk of running out of money. Review your plan."
            }
        }
    }
    
    // MARK: - Validation Rules
    enum Validation {
        static let minPortfolioValue: Double = 1.0
        static let maxPortfolioValue: Double = 1_000_000_000.0  // 1 billion
        
        static let minAge: Int = 18
        static let maxAge: Int = 120
        
        static let minWithdrawalRate: Double = 0.01  // 1%
        static let maxWithdrawalRate: Double = 0.20  // 20%
        
        static let minAssetQuantity: Double = 0.0001
        static let maxAssetQuantity: Double = 1_000_000_000.0
    }
    
    // MARK: - Feature Flags
    enum Features {
        static let enableTaxCalculations = false  // Future feature
        static let enableSocialSecurity = true
        static let enablePensionIncome = true
        static let enableCustomAssetClasses = false  // Future feature
        static let enablePortfolioSharing = false  // Future feature
        static let enableBacktesting = true
    }
    
    // MARK: - Error Messages
    enum ErrorMessages {
        static let generic = "An unexpected error occurred. Please try again."
        static let networkError = "Unable to connect to the internet. Please check your connection."
        static let apiKeyMissing = "IEX Cloud API key is required for live price updates. Add one in Settings."
        static let rateLimitExceeded = "API rate limit exceeded. Please try again later."
        static let invalidPortfolio = "Portfolio must contain at least one asset."
        static let simulationFailed = "Simulation failed to complete. Please check your parameters."
    }
    
    // MARK: - Success Messages
    enum SuccessMessages {
        static let portfolioSaved = "Portfolio saved successfully"
        static let simulationComplete = "Simulation completed successfully"
        static let pricesUpdated = "Prices updated successfully"
        static let settingsSaved = "Settings saved"
    }
    
    // MARK: - Onboarding
    enum Onboarding {
        static let welcomeTitle = "Welcome to FIRECalc"
        static let welcomeMessage = "Plan your path to Financial Independence and Early Retirement"
        
        static let steps = [
            "Create your portfolio with different asset classes",
            "Run Monte Carlo simulations to project retirement outcomes",
            "Choose from multiple withdrawal strategies",
            "Track your progress over time"
        ]
    }
}

// MARK: - Helper Extensions

extension Double {
    func toCurrency() -> String {
        AppConstants.Format.currencyFormatter.string(from: NSNumber(value: self)) ?? "$0"
    }
    
    func toPreciseCurrency() -> String {
        AppConstants.Format.preciseCurrencyFormatter.string(from: NSNumber(value: self)) ?? "$0.00"
    }
    
    func toPercent() -> String {
        AppConstants.Format.percentFormatter.string(from: NSNumber(value: self)) ?? "0%"
    }
    
    func toDecimal() -> String {
        AppConstants.Format.decimalFormatter.string(from: NSNumber(value: self)) ?? "0"
    }

    /// Returns `self` if non-zero, otherwise returns `default`.
    func nonZeroOrDefault(_ default: Double) -> Double {
        self == 0 ? `default` : self
    }
}

extension Date {
    /// Medium date + short time, e.g. "Jan 1, 2025, 3:00 PM".
    /// Named `mediumFormatted()` to avoid shadowing the system `formatted()` API.
    func mediumFormatted() -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: self)
    }
    
    func shortFormatted() -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        return formatter.string(from: self)
    }
}
// MARK: - Keyboard Dismiss Helper

extension View {
    /// Adds a **Done** button above the software keyboard that dismisses it.
    /// Apply this once to a `Form` or `ScrollView` that contains text fields.
    func keyboardDoneButton() -> some View {
        toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") {
                    UIApplication.shared.sendAction(
                        #selector(UIResponder.resignFirstResponder),
                        to: nil, from: nil, for: nil
                    )
                }
                .fontWeight(.semibold)
            }
        }
    }
}

