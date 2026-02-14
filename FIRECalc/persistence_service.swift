//
//  PersistenceService.swift
//  FIRECalc
//
//  Handles saving and loading data locally with iCloud backup capability
//

import Foundation

class PersistenceService {
    static let shared = PersistenceService()
    
    private init() {}
    
    // MARK: - File URLs
    
    private var documentsDirectory: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
    
    private var portfolioURL: URL {
        documentsDirectory.appendingPathComponent(AppConstants.Storage.portfolioFileName)
    }
    
    private var profileURL: URL {
        documentsDirectory.appendingPathComponent(AppConstants.Storage.profileFileName)
    }
    
    private var simulationHistoryURL: URL {
        documentsDirectory.appendingPathComponent(AppConstants.Storage.simulationHistoryFileName)
    }
    
    private var snapshotsURL: URL {
        documentsDirectory.appendingPathComponent(AppConstants.Storage.performanceSnapshotsFileName)
    }
    
    // MARK: - Portfolio Persistence
    
    func savePortfolio(_ portfolio: Portfolio) throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted
        
        let data = try encoder.encode(portfolio)
        try data.write(to: portfolioURL)
        
        print("✅ Portfolio saved to: \(portfolioURL.path)")
    }
    
    func loadPortfolio() throws -> Portfolio? {
        guard FileManager.default.fileExists(atPath: portfolioURL.path) else {
            print("ℹ️ No saved portfolio found")
            return nil
        }
        
        let data = try Data(contentsOf: portfolioURL)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        let portfolio = try decoder.decode(Portfolio.self, from: data)
        print("✅ Portfolio loaded: \(portfolio.assets.count) assets")
        return portfolio
    }
    
    func deletePortfolio() throws {
        if FileManager.default.fileExists(atPath: portfolioURL.path) {
            try FileManager.default.removeItem(at: portfolioURL)
            print("✅ Portfolio deleted")
        }
    }
    
    // MARK: - User Profile Persistence
    
    func saveProfile(_ profile: UserProfile) throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted
        
        let data = try encoder.encode(profile)
        try data.write(to: profileURL)
        
        print("✅ Profile saved")
    }
    
    func loadProfile() throws -> UserProfile? {
        guard FileManager.default.fileExists(atPath: profileURL.path) else {
            print("ℹ️ No saved profile found")
            return nil
        }
        
        let data = try Data(contentsOf: profileURL)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        let profile = try decoder.decode(UserProfile.self, from: data)
        print("✅ Profile loaded")
        return profile
    }
    
    // MARK: - Simulation History
    
    func saveSimulationResult(_ result: SimulationResult) throws {
        var history = (try? loadSimulationHistory()) ?? []
        // Strip the per-run paths before persisting — they can be enormous
        // (e.g. 1 000 runs × 50 years = 50 000 Double arrays) and are only
        // needed while the results sheet is on screen, not in stored history.
        history.append(result.withoutSimulationRuns())
        
        // Keep only last 50 simulations
        if history.count > 50 {
            history = Array(history.suffix(50))
        }
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        // Don't use .prettyPrinted for history — it bloats file size significantly.
        
        let data = try encoder.encode(history)
        try data.write(to: simulationHistoryURL)
        
        print("✅ Simulation saved to history")
    }
    
    func loadSimulationHistory() throws -> [SimulationResult] {
        guard FileManager.default.fileExists(atPath: simulationHistoryURL.path) else {
            return []
        }
        
        let data = try Data(contentsOf: simulationHistoryURL)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        return try decoder.decode([SimulationResult].self, from: data)
    }
    
    // MARK: - Performance Snapshots
    
    func saveSnapshot(_ snapshot: PerformanceSnapshot) throws {
        var snapshots = (try? loadSnapshots()) ?? []
        snapshots.append(snapshot)
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted
        
        let data = try encoder.encode(snapshots)
        try data.write(to: snapshotsURL)
        
        print("✅ Performance snapshot saved")
    }
    
    func loadSnapshots() throws -> [PerformanceSnapshot] {
        guard FileManager.default.fileExists(atPath: snapshotsURL.path) else {
            return []
        }
        
        let data = try Data(contentsOf: snapshotsURL)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        return try decoder.decode([PerformanceSnapshot].self, from: data)
    }
    
    // MARK: - Export / Import
    
    func exportPortfolioAsJSON(_ portfolio: Portfolio) throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted
        
        return try encoder.encode(portfolio)
    }
    
    func importPortfolioFromJSON(_ data: Data) throws -> Portfolio {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        return try decoder.decode(Portfolio.self, from: data)
    }
    
    // MARK: - Defined Benefit Plans

    private var definedBenefitPlansURL: URL {
        documentsDirectory.appendingPathComponent("defined_benefit_plans.json")
    }

    func saveDefinedBenefitPlans(_ plans: [DefinedBenefitPlan]) {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        if let data = try? encoder.encode(plans) {
            try? data.write(to: definedBenefitPlansURL)
        }
    }

    func loadDefinedBenefitPlans() -> [DefinedBenefitPlan] {
        guard FileManager.default.fileExists(atPath: definedBenefitPlansURL.path),
              let data = try? Data(contentsOf: definedBenefitPlansURL),
              let plans = try? JSONDecoder().decode([DefinedBenefitPlan].self, from: data)
        else { return [] }
        return plans
    }

    // MARK: - Withdrawal Configuration

    private let withdrawalConfigKey = "savedWithdrawalConfiguration"

    func saveWithdrawalConfiguration(_ config: WithdrawalConfiguration) {
        let encoder = JSONEncoder()
        if let data = try? encoder.encode(config) {
            UserDefaults.standard.set(data, forKey: withdrawalConfigKey)
        }
    }

    func loadWithdrawalConfiguration() -> WithdrawalConfiguration? {
        guard let data = UserDefaults.standard.data(forKey: withdrawalConfigKey) else { return nil }
        let decoder = JSONDecoder()
        return try? decoder.decode(WithdrawalConfiguration.self, from: data)
    }

    // MARK: - UserDefaults (Settings)
    
    func saveAPIKey(_ key: String) {
        UserDefaults.standard.set(key, forKey: AppConstants.UserDefaultsKeys.apiKey)
        print("💾 API key saved (not used with Yahoo Finance)")
    }
    
    func loadAPIKey() -> String? {
        let key = UserDefaults.standard.string(forKey: AppConstants.UserDefaultsKeys.apiKey)
        return key
    }
    
    func saveSettings(
        defaultRuns: Int? = nil,
        defaultTimeHorizon: Int? = nil,
        defaultInflation: Double? = nil,
        useBootstrap: Bool? = nil,
        autoRefresh: Bool? = nil
    ) {
        if let runs = defaultRuns {
            UserDefaults.standard.set(runs, forKey: AppConstants.UserDefaultsKeys.defaultSimulationRuns)
        }
        if let horizon = defaultTimeHorizon {
            UserDefaults.standard.set(horizon, forKey: AppConstants.UserDefaultsKeys.defaultTimeHorizon)
        }
        if let inflation = defaultInflation {
            UserDefaults.standard.set(inflation, forKey: AppConstants.UserDefaultsKeys.defaultInflationRate)
        }
        if let bootstrap = useBootstrap {
            UserDefaults.standard.set(bootstrap, forKey: AppConstants.UserDefaultsKeys.useHistoricalBootstrap)
        }
        if let refresh = autoRefresh {
            UserDefaults.standard.set(refresh, forKey: AppConstants.UserDefaultsKeys.autoRefreshPrices)
        }
    }
    
    func loadSettings() -> UserPreferences {
        return UserPreferences(
            defaultSimulationRuns: UserDefaults.standard.integer(forKey: AppConstants.UserDefaultsKeys.defaultSimulationRuns) != 0 ?
                UserDefaults.standard.integer(forKey: AppConstants.UserDefaultsKeys.defaultSimulationRuns) : AppConstants.Simulation.defaultRuns,
            defaultTimeHorizon: UserDefaults.standard.integer(forKey: AppConstants.UserDefaultsKeys.defaultTimeHorizon) != 0 ?
                UserDefaults.standard.integer(forKey: AppConstants.UserDefaultsKeys.defaultTimeHorizon) : AppConstants.Simulation.defaultTimeHorizon,
            defaultInflationRate: UserDefaults.standard.double(forKey: AppConstants.UserDefaultsKeys.defaultInflationRate) != 0 ?
                UserDefaults.standard.double(forKey: AppConstants.UserDefaultsKeys.defaultInflationRate) : AppConstants.Simulation.defaultInflationRate,
            useHistoricalBootstrap: UserDefaults.standard.object(forKey: AppConstants.UserDefaultsKeys.useHistoricalBootstrap) != nil ?
                UserDefaults.standard.bool(forKey: AppConstants.UserDefaultsKeys.useHistoricalBootstrap) : true,
            iexApiKey: loadAPIKey(),
            autoRefreshPrices: UserDefaults.standard.bool(forKey: AppConstants.UserDefaultsKeys.autoRefreshPrices)
        )
    }
    
    // MARK: - iCloud Backup (Optional - requires entitlements)
    
    func enableiCloudBackup() {
        // Store key-value pairs in iCloud
        let store = NSUbiquitousKeyValueStore.default
        
        if let apiKey = loadAPIKey() {
            store.set(apiKey, forKey: "icloud_api_key")
        }
        
        store.synchronize()
    }
    
    func restoreFromiCloud() {
        let store = NSUbiquitousKeyValueStore.default
        
        if let apiKey = store.string(forKey: "icloud_api_key") {
            saveAPIKey(apiKey)
        }
        
        store.synchronize()
    }
}
