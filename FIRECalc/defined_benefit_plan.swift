//
//  DefinedBenefitPlan.swift
//  FIRECalc
//
//  Support for pensions and Social Security in retirement planning
//

import Foundation

// MARK: - Defined Benefit Plan

struct DefinedBenefitPlan: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var type: PlanType
    var annualBenefit: Double
    var startAge: Int
    var inflationAdjusted: Bool

    init(
        id: UUID = UUID(),
        name: String,
        type: PlanType,
        annualBenefit: Double,
        startAge: Int,
        inflationAdjusted: Bool = false
    ) {
        self.id = id
        self.name = name
        self.type = type
        self.annualBenefit = annualBenefit
        self.startAge = startAge
        self.inflationAdjusted = inflationAdjusted
    }
    
    enum PlanType: String, Codable, CaseIterable, Identifiable {
        case socialSecurity = "Social Security"
        case pension = "Pension"
        case annuity = "Annuity"
        case other = "Other"
        
        var id: String { rawValue }
        
        var iconName: String {
            switch self {
            case .socialSecurity: return "building.columns"
            case .pension: return "briefcase.fill"
            case .annuity: return "dollarsign.circle"
            case .other: return "doc.text"
            }
        }
        
        var defaultInflationAdjusted: Bool {
            switch self {
            case .socialSecurity: return true
            case .pension: return false
            case .annuity: return false
            case .other: return false
            }
        }
    }
    
    // MARK: - Benefit Calculation

    /// Real (inflation-adjusted) annual value of this benefit at a given year
    /// into retirement. COLA plans hold their purchasing power; non-COLA plans
    /// erode at the simulation inflation rate.
    func realBenefit(yearsIntoRetirement: Int, inflationRate: Double) -> Double {
        if inflationAdjusted {
            // Real value stays constant — COLA exactly matches inflation.
            return annualBenefit
        } else {
            // Fixed nominal: real purchasing power erodes each year.
            return annualBenefit / pow(1 + inflationRate, Double(yearsIntoRetirement - 1))
        }
    }

    func presentValue(currentAge: Int, discountRate: Double = 0.03, lifeExpectancy: Int = 90) -> Double {
        var pv: Double = 0
        for age in currentAge...lifeExpectancy {
            if age >= startAge {
                let yearsFromNow = age - currentAge
                let discountedBenefit = annualBenefit / pow(1 + discountRate, Double(yearsFromNow))
                pv += discountedBenefit
            }
        }
        return pv
    }
}

// MARK: - Social Security Estimator

struct SocialSecurityEstimator {
    
    /// Estimate Social Security benefit based on average indexed monthly earnings
    /// This is a simplified version - actual SS calculation is complex
    static func estimateBenefit(
        averageAnnualIncome: Double,
        birthYear: Int,
        claimAge: Int = 67
    ) -> Double {
        
        // 2024 bend points (these change annually)
        let bendPoint1 = 1_174.0
        let bendPoint2 = 7_078.0
        
        // Calculate Average Indexed Monthly Earnings (AIME)
        let aime = min(averageAnnualIncome / 12, 14_000) // Cap at max taxable
        
        // Calculate Primary Insurance Amount (PIA) using bend points
        var pia: Double = 0
        
        if aime <= bendPoint1 {
            pia = aime * 0.90
        } else if aime <= bendPoint2 {
            pia = (bendPoint1 * 0.90) + ((aime - bendPoint1) * 0.32)
        } else {
            pia = (bendPoint1 * 0.90) + ((bendPoint2 - bendPoint1) * 0.32) + ((aime - bendPoint2) * 0.15)
        }
        
        // Adjust for claiming age
        let fullRetirementAge = fullRetirementAge(for: birthYear)
        let adjustmentFactor = claimingAdjustment(claimAge: claimAge, fullRetirementAge: fullRetirementAge)
        
        let monthlyBenefit = pia * adjustmentFactor
        return monthlyBenefit * 12 // Annual benefit
    }
    
    /// Full Retirement Age based on birth year
    static func fullRetirementAge(for birthYear: Int) -> Int {
        if birthYear <= 1937 {
            return 65
        } else if birthYear <= 1942 {
            return 66
        } else if birthYear <= 1954 {
            return 66
        } else if birthYear <= 1959 {
            return 66
        } else {
            return 67
        }
    }
    
    /// Adjustment factor for claiming before/after FRA
    static func claimingAdjustment(claimAge: Int, fullRetirementAge: Int) -> Double {
        if claimAge == fullRetirementAge {
            return 1.0
        } else if claimAge < fullRetirementAge {
            // Reduction for early claiming (roughly 5-6% per year)
            let yearsDifference = fullRetirementAge - claimAge
            return max(0.70, 1.0 - Double(yearsDifference) * 0.067)
        } else {
            // Increase for delayed claiming (8% per year)
            let yearsDifference = claimAge - fullRetirementAge
            return min(1.32, 1.0 + Double(yearsDifference) * 0.08)
        }
    }
}

// MARK: - Enhanced Simulation Parameters with Defined Benefits

extension SimulationParameters {
    /// Total fixed income offset per year — single channel via withdrawalConfig.
    var totalFixedIncome: Double {
        withdrawalConfig.fixedIncome ?? 0
    }
}

// MARK: - Defined Benefit Manager

class DefinedBenefitManager: ObservableObject {
    @Published var plans: [DefinedBenefitPlan] = []

    private let persistence = PersistenceService.shared

    init() {
        plans = persistence.loadDefinedBenefitPlans()
    }

    func addPlan(_ plan: DefinedBenefitPlan) {
        plans.append(plan)
        savePlans()
    }

    func updatePlan(_ plan: DefinedBenefitPlan) {
        if let index = plans.firstIndex(where: { $0.id == plan.id }) {
            plans[index] = plan
            savePlans()
        }
    }

    func deletePlan(_ plan: DefinedBenefitPlan) {
        plans.removeAll { $0.id == plan.id }
        savePlans()
    }

    // MARK: - Aggregates

    /// Total annual income from plans that have already started at `age`.
    func totalAnnualBenefit(at age: Int) -> Double {
        plans
            .filter { age >= $0.startAge }
            .reduce(0) { $0 + $1.annualBenefit }
    }

    /// Sum of all plan benefits regardless of start age — used for simulation
    /// planning where "retirement has started" and all income is assumed active.
    var totalSimulationIncome: Double {
        plans.reduce(0) { $0 + $1.annualBenefit }
    }

    /// Pre-computed income buckets ready to stamp into a WithdrawalConfiguration.
    /// COLA plans → fixedIncomeReal (constant real value).
    /// Non-COLA plans → fixedIncomeNominal (erodes with inflation).
    var simulationIncomeBuckets: (real: Double, nominal: Double) {
        var real = 0.0
        var nominal = 0.0
        for plan in plans {
            if plan.inflationAdjusted {
                real += plan.annualBenefit
            } else {
                nominal += plan.annualBenefit
            }
        }
        return (real, nominal)
    }

    func totalPresentValue(currentAge: Int, lifeExpectancy: Int = 90) -> Double {
        plans.reduce(0) { $0 + $1.presentValue(currentAge: currentAge, lifeExpectancy: lifeExpectancy) }
    }

    // MARK: - Persistence

    private func savePlans() {
        persistence.saveDefinedBenefitPlans(plans)
    }

    /// Kept for backward-compatibility; init() now calls the persisted version directly.
    func loadPlans() {
        plans = persistence.loadDefinedBenefitPlans()
    }
}

// MARK: - Sample Plans

extension DefinedBenefitPlan {
    static let sampleSocialSecurity = DefinedBenefitPlan(
        name: "Social Security",
        type: .socialSecurity,
        annualBenefit: 24_000,
        startAge: 67,
        inflationAdjusted: true
    )

    static let samplePension = DefinedBenefitPlan(
        name: "Company Pension",
        type: .pension,
        annualBenefit: 18_000,
        startAge: 65,
        inflationAdjusted: false
    )

    static let samples: [DefinedBenefitPlan] = [
        sampleSocialSecurity,
        samplePension
    ]
}
