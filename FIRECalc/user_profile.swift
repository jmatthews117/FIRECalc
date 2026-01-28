//
//  UserProfile.swift
//  FIRECalc
//
//  User profile for saving multiple scenarios and tracking performance
//

import Foundation

struct UserProfile: Identifiable, Codable {
    let id: UUID
    var name: String
    var createdDate: Date
    
    // User information
    var currentAge: Int?
    var targetRetirementAge: Int?
    var lifeExpectancy: Int?
    
    // Portfolios (can have multiple scenarios)
    var portfolios: [Portfolio]
    var activePortfolioId: UUID?
    
    // Simulation history
    var simulationHistory: [SimulationResult]
    
    // Performance tracking
    var performanceSnapshots: [PerformanceSnapshot]
    
    // Settings
    var preferences: UserPreferences
    
    init(
        id: UUID = UUID(),
        name: String = "Default Profile",
        createdDate: Date = Date(),
        currentAge: Int? = nil,
        targetRetirementAge: Int? = nil,
        lifeExpectancy: Int? = nil,
        portfolios: [Portfolio] = [],
        activePortfolioId: UUID? = nil,
        simulationHistory: [SimulationResult] = [],
        performanceSnapshots: [PerformanceSnapshot] = [],
        preferences: UserPreferences = UserPreferences()
    ) {
        self.id = id
        self.name = name
        self.createdDate = createdDate
        self.currentAge = currentAge
        self.targetRetirementAge = targetRetirementAge
        self.lifeExpectancy = lifeExpectancy
        self.portfolios = portfolios
        self.activePortfolioId = activePortfolioId
        self.simulationHistory = simulationHistory
        self.performanceSnapshots = performanceSnapshots
        self.preferences = preferences
    }
    
    // MARK: - Computed Properties
    
    var activePortfolio: Portfolio? {
        guard let activeId = activePortfolioId else { return portfolios.first }
        return portfolios.first { $0.id == activeId }
    }
    
    var yearsToRetirement: Int? {
        guard let current = currentAge, let target = targetRetirementAge else { return nil }
        return max(0, target - current)
    }
    
    var retirementTimeHorizon: Int? {
        guard let retirement = targetRetirementAge, let life = lifeExpectancy else { return nil }
        return max(0, life - retirement)
    }
    
    var latestSimulation: SimulationResult? {
        simulationHistory.max { $0.runDate < $1.runDate }
    }
    
    var latestSnapshot: PerformanceSnapshot? {
        performanceSnapshots.max { $0.date < $1.date }
    }
    
    // MARK: - Portfolio Management
    
    mutating func addPortfolio(_ portfolio: Portfolio) {
        portfolios.append(portfolio)
        if activePortfolioId == nil {
            activePortfolioId = portfolio.id
        }
    }
    
    mutating func updatePortfolio(_ portfolio: Portfolio) {
        if let index = portfolios.firstIndex(where: { $0.id == portfolio.id }) {
            portfolios[index] = portfolio
        }
    }
    
    mutating func deletePortfolio(_ portfolio: Portfolio) {
        portfolios.removeAll { $0.id == portfolio.id }
        if activePortfolioId == portfolio.id {
            activePortfolioId = portfolios.first?.id
        }
    }
    
    mutating func setActivePortfolio(_ portfolioId: UUID) {
        if portfolios.contains(where: { $0.id == portfolioId }) {
            activePortfolioId = portfolioId
        }
    }
    
    // MARK: - Simulation Management
    
    mutating func addSimulation(_ result: SimulationResult) {
        simulationHistory.append(result)
        
        // Keep only last 50 simulations to manage storage
        if simulationHistory.count > 50 {
            simulationHistory = Array(simulationHistory.suffix(50))
        }
    }
    
    // MARK: - Performance Tracking
    
    mutating func takeSnapshot() {
        guard let portfolio = activePortfolio else { return }
        
        let snapshot = PerformanceSnapshot(
            portfolioId: portfolio.id,
            totalValue: portfolio.totalValue,
            allocation: portfolio.assetAllocation,
            assets: portfolio.assets
        )
        
        performanceSnapshots.append(snapshot)
    }
    
    func performanceOverTime() -> [PerformanceDataPoint] {
        performanceSnapshots.map { snapshot in
            PerformanceDataPoint(
                date: snapshot.date,
                value: snapshot.totalValue
            )
        }
    }
    
    func returnsVsProjection() -> ComparisonData? {
        guard let latest = latestSnapshot,
              let firstSnapshot = performanceSnapshots.first,
              let simulation = latestSimulation else { return nil }
        
        let actualReturn = (latest.totalValue - firstSnapshot.totalValue) / firstSnapshot.totalValue
        let timeElapsed = Calendar.current.dateComponents([.year], from: firstSnapshot.date, to: latest.date).year ?? 0
        
        // Find projected value at this point in time
        let projectedValue = simulation.yearlyBalances.first { $0.year == timeElapsed }?.medianBalance
        
        return ComparisonData(
            actualValue: latest.totalValue,
            projectedValue: projectedValue ?? 0,
            actualReturn: actualReturn,
            timeElapsed: timeElapsed
        )
    }
}

// MARK: - User Preferences

struct UserPreferences: Codable {
    var defaultSimulationRuns: Int
    var defaultTimeHorizon: Int
    var defaultInflationRate: Double
    var useHistoricalBootstrap: Bool
    var iexApiKey: String?
    var autoRefreshPrices: Bool
    var priceRefreshInterval: TimeInterval  // in seconds
    
    init(
        defaultSimulationRuns: Int = 10000,
        defaultTimeHorizon: Int = 30,
        defaultInflationRate: Double = 0.02,
        useHistoricalBootstrap: Bool = true,
        iexApiKey: String? = nil,
        autoRefreshPrices: Bool = false,
        priceRefreshInterval: TimeInterval = 3600  // 1 hour
    ) {
        self.defaultSimulationRuns = defaultSimulationRuns
        self.defaultTimeHorizon = defaultTimeHorizon
        self.defaultInflationRate = defaultInflationRate
        self.useHistoricalBootstrap = useHistoricalBootstrap
        self.iexApiKey = iexApiKey
        self.autoRefreshPrices = autoRefreshPrices
        self.priceRefreshInterval = priceRefreshInterval
    }
}

// MARK: - Performance Tracking Models

struct PerformanceSnapshot: Codable, Identifiable {
    let id: UUID
    let date: Date
    let portfolioId: UUID
    let totalValue: Double
    let allocation: [AssetClass: Double]
    let assets: [Asset]
    
    init(
        id: UUID = UUID(),
        date: Date = Date(),
        portfolioId: UUID,
        totalValue: Double,
        allocation: [AssetClass: Double],
        assets: [Asset]
    ) {
        self.id = id
        self.date = date
        self.portfolioId = portfolioId
        self.totalValue = totalValue
        self.allocation = allocation
        self.assets = assets
    }
}

struct PerformanceDataPoint: Identifiable {
    let id = UUID()
    let date: Date
    let value: Double
}

struct ComparisonData {
    let actualValue: Double
    let projectedValue: Double
    let actualReturn: Double
    let timeElapsed: Int
    
    var variance: Double {
        actualValue - projectedValue
    }
    
    var variancePercentage: Double {
        guard projectedValue > 0 else { return 0 }
        return (actualValue - projectedValue) / projectedValue
    }
}

// MARK: - Sample Profile

extension UserProfile {
    static let sample = UserProfile(
        name: "John's FIRE Plan",
        currentAge: 35,
        targetRetirementAge: 50,
        lifeExpectancy: 90,
        portfolios: [Portfolio.sample],
        activePortfolioId: Portfolio.sample.id,
        simulationHistory: [SimulationResult.sample],
        preferences: UserPreferences()
    )
}
