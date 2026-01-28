//
//  DefinedBenefitPlansView.swift
//  FIRECalc
//
//  Manage pensions and Social Security benefits
//

import SwiftUI

struct DefinedBenefitPlansView: View {
    @StateObject private var manager = DefinedBenefitManager()
    @State private var showingAddPlan = false
    @State private var currentAge: Int = 35
    
    var body: some View {
        List {
            // Summary Section
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Total Annual Benefits")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Text(totalCurrentBenefits.toCurrency())
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                    
                    Text("Present Value: \(manager.totalPresentValue(currentAge: currentAge).toCurrency())")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 8)
            }
            
            // Plans List
            Section("Your Benefits") {
                if manager.plans.isEmpty {
                    emptyState
                } else {
                    ForEach(manager.plans) { plan in
                        DefinedBenefitRow(plan: plan, currentAge: currentAge)
                    }
                    .onDelete(perform: deletePlans)
                }
            }
            
            // Social Security Calculator
            Section {
                NavigationLink(destination: SocialSecurityCalculatorView()) {
                    HStack {
                        Image(systemName: "building.columns")
                            .foregroundColor(.blue)
                        Text("Estimate Social Security")
                    }
                }
            }
        }
        .navigationTitle("Defined Benefits")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { showingAddPlan = true }) {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showingAddPlan) {
            AddDefinedBenefitView(manager: manager, currentAge: currentAge)
        }
        .onAppear {
            manager.loadPlans()
        }
    }
    
    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "building.columns")
                .font(.system(size: 40))
                .foregroundColor(.gray)
            
            Text("No defined benefits yet")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Text("Add pensions, Social Security, or annuities")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
    }
    
    private var totalCurrentBenefits: Double {
        manager.totalAnnualBenefit(at: currentAge)
    }
    
    private func deletePlans(at offsets: IndexSet) {
        for index in offsets {
            manager.deletePlan(manager.plans[index])
        }
    }
}

// MARK: - Defined Benefit Row

struct DefinedBenefitRow: View {
    let plan: DefinedBenefitPlan
    let currentAge: Int
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: plan.type.iconName)
                    .foregroundColor(.blue)
                    .frame(width: 30)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(plan.name)
                        .font(.headline)
                    
                    HStack(spacing: 4) {
                        Text(plan.type.rawValue)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        if plan.inflationAdjusted {
                            Text("• COLA")
                                .font(.caption)
                                .foregroundColor(.green)
                        }
                    }
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text(plan.annualBenefit.toCurrency())
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text("per year")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            HStack {
                if currentAge < plan.startAge {
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.caption)
                        Text("Starts at age \(plan.startAge) (\(plan.startAge - currentAge) years)")
                            .font(.caption)
                    }
                    .foregroundColor(.orange)
                } else {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.caption)
                        Text("Currently receiving")
                            .font(.caption)
                    }
                    .foregroundColor(.green)
                }
                
                Spacer()
                
                if let survivor = plan.survivorBenefit {
                    Text("\(Int(survivor * 100))% survivor")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Add Defined Benefit View

struct AddDefinedBenefitView: View {
    @ObservedObject var manager: DefinedBenefitManager
    let currentAge: Int
    @Environment(\.dismiss) private var dismiss
    
    @State private var name: String = ""
    @State private var selectedType: DefinedBenefitPlan.PlanType = .pension
    @State private var annualBenefit: String = ""
    @State private var startAge: String = ""
    @State private var inflationAdjusted: Bool = false
    @State private var hasSurvivorBenefit: Bool = false
    @State private var survivorPercentage: Double = 50
    @State private var notes: String = ""
    
    var body: some View {
        NavigationView {
            Form {
                Section("Benefit Details") {
                    TextField("Name", text: $name)
                    
                    Picker("Type", selection: $selectedType) {
                        ForEach(DefinedBenefitPlan.PlanType.allCases) { type in
                            HStack {
                                Image(systemName: type.iconName)
                                Text(type.rawValue)
                            }
                            .tag(type)
                        }
                    }
                    .onChange(of: selectedType) { _, newValue in
                        inflationAdjusted = newValue.defaultInflationAdjusted
                    }
                }
                
                Section("Annual Benefit") {
                    TextField("Annual Amount", text: $annualBenefit)
                        .keyboardType(.decimalPad)
                    
                    if let amount = Double(annualBenefit) {
                        HStack {
                            Text("Monthly")
                                .foregroundColor(.secondary)
                            Spacer()
                            Text((amount / 12).toCurrency())
                                .foregroundColor(.blue)
                        }
                        .font(.caption)
                    }
                }
                
                Section("Start Date") {
                    TextField("Start Age", text: $startAge)
                        .keyboardType(.numberPad)
                    
                    if let age = Int(startAge), age > currentAge {
                        Text("Starts in \(age - currentAge) years")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Section("Options") {
                    Toggle("Inflation Adjusted (COLA)", isOn: $inflationAdjusted)
                    
                    Toggle("Survivor Benefit", isOn: $hasSurvivorBenefit)
                    
                    if hasSurvivorBenefit {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Survivor Percentage")
                                Spacer()
                                Text("\(Int(survivorPercentage))%")
                                    .foregroundColor(.secondary)
                            }
                            
                            Slider(value: $survivorPercentage, in: 0...100, step: 5)
                        }
                    }
                }
                
                Section("Notes") {
                    TextEditor(text: $notes)
                        .frame(height: 100)
                }
            }
            .navigationTitle("Add Benefit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        addPlan()
                    }
                    .disabled(!isValid)
                }
            }
        }
    }
    
    private var isValid: Bool {
        !name.isEmpty &&
        !annualBenefit.isEmpty &&
        !startAge.isEmpty &&
        Double(annualBenefit) != nil &&
        Int(startAge) != nil
    }
    
    private func addPlan() {
        let plan = DefinedBenefitPlan(
            name: name,
            type: selectedType,
            annualBenefit: Double(annualBenefit) ?? 0,
            startAge: Int(startAge) ?? 65,
            inflationAdjusted: inflationAdjusted,
            survivorBenefit: hasSurvivorBenefit ? (survivorPercentage / 100) : nil,
            notes: notes.isEmpty ? nil : notes
        )
        
        manager.addPlan(plan)
        dismiss()
    }
}

// MARK: - Social Security Calculator View

struct SocialSecurityCalculatorView: View {
    @State private var averageIncome: String = ""
    @State private var birthYear: String = ""
    @State private var claimAge: Double = 67
    @State private var estimatedBenefit: Double?
    
    var body: some View {
        Form {
            Section("Your Information") {
                TextField("Average Annual Income", text: $averageIncome)
                    .keyboardType(.decimalPad)
                
                TextField("Birth Year", text: $birthYear)
                    .keyboardType(.numberPad)
                
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Claim Age")
                        Spacer()
                        Text("\(Int(claimAge))")
                            .foregroundColor(.secondary)
                    }
                    
                    Slider(value: $claimAge, in: 62...70, step: 1)
                    
                    Text(claimAgeGuidance)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Section {
                Button("Calculate Benefit") {
                    calculateBenefit()
                }
                .disabled(!isValid)
            }
            
            if let benefit = estimatedBenefit {
                Section("Estimated Benefit") {
                    HStack {
                        Text("Annual Benefit")
                        Spacer()
                        Text(benefit.toCurrency())
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundColor(.blue)
                    }
                    
                    HStack {
                        Text("Monthly Benefit")
                        Spacer()
                        Text((benefit / 12).toCurrency())
                            .foregroundColor(.secondary)
                    }
                    
                    Text("This is an estimate. Actual benefits may vary based on your complete earnings history.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Section {
                Link("Visit SSA.gov for Official Estimate", destination: URL(string: "https://www.ssa.gov/myaccount/")!)
                    .font(.caption)
            }
        }
        .navigationTitle("Social Security")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private var isValid: Bool {
        !averageIncome.isEmpty &&
        !birthYear.isEmpty &&
        Double(averageIncome) != nil &&
        Int(birthYear) != nil
    }
    
    private var claimAgeGuidance: String {
        let year = Int(birthYear) ?? 1960
        let fra = SocialSecurityEstimator.fullRetirementAge(for: year)
        let age = Int(claimAge)
        
        if age < fra {
            return "Early claiming - reduced benefit"
        } else if age == fra {
            return "Full retirement age - full benefit"
        } else {
            return "Delayed claiming - increased benefit (\(Int((Double(age - fra) * 8)))% boost)"
        }
    }
    
    private func calculateBenefit() {
        guard let income = Double(averageIncome),
              let year = Int(birthYear) else { return }
        
        estimatedBenefit = SocialSecurityEstimator.estimateBenefit(
            averageAnnualIncome: income,
            birthYear: year,
            claimAge: Int(claimAge)
        )
    }
}

#Preview {
    NavigationView {
        DefinedBenefitPlansView()
    }
}
