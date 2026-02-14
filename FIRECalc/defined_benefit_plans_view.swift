//
//  DefinedBenefitPlansView.swift
//  FIRECalc
//
//  Manage pensions and Social Security benefits
//

import SwiftUI

struct DefinedBenefitPlansView: View {
    @ObservedObject var manager: DefinedBenefitManager
    @State private var showingAddPlan = false
    @State private var planToEdit: DefinedBenefitPlan? = nil
    @State private var currentAge: Int = 35
    
    var body: some View {
        List {
            // Summary Section
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Total Annual Benefits")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Text(manager.totalSimulationIncome.toCurrency())
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)

                    HStack(spacing: 16) {
                        if futurePlansTotal > 0 {
                            Label("\(activePlansTotal.toCurrency()) active now", systemImage: "checkmark.circle.fill")
                                .font(.caption)
                                .foregroundColor(.green)
                            Label("\(futurePlansTotal.toCurrency()) future", systemImage: "clock")
                                .font(.caption)
                                .foregroundColor(.orange)
                        }
                    }

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
                        Button {
                            planToEdit = plan
                        } label: {
                            DefinedBenefitRow(plan: plan, currentAge: currentAge)
                        }
                        .buttonStyle(.plain)
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
            EditDefinedBenefitView(manager: manager, currentAge: currentAge, existingPlan: nil)
        }
        .sheet(item: $planToEdit) { plan in
            EditDefinedBenefitView(manager: manager, currentAge: currentAge, existingPlan: plan)
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
    
    private var activePlansTotal: Double {
        manager.totalAnnualBenefit(at: currentAge)
    }

    private var futurePlansTotal: Double {
        manager.totalSimulationIncome - activePlansTotal
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

                if plan.inflationAdjusted {
                    Text("COLA")
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.green.opacity(0.8))
                        .clipShape(Capsule())
                } else {
                    Text("Fixed")
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.orange.opacity(0.8))
                        .clipShape(Capsule())
                }
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Edit / Add Defined Benefit View

/// Handles both adding a new plan (existingPlan == nil) and editing one
/// (existingPlan != nil). All fields are seeded from the existing plan
/// when editing so nothing is accidentally cleared.
struct EditDefinedBenefitView: View {
    @ObservedObject var manager: DefinedBenefitManager
    let currentAge: Int
    let existingPlan: DefinedBenefitPlan?
    @Environment(\.dismiss) private var dismiss

    @State private var name: String
    @State private var selectedType: DefinedBenefitPlan.PlanType
    @State private var annualBenefit: String
    @State private var startAge: String
    @State private var inflationAdjusted: Bool

    @State private var showingDeleteConfirmation = false

    init(manager: DefinedBenefitManager, currentAge: Int, existingPlan: DefinedBenefitPlan?) {
        self.manager = manager
        self.currentAge = currentAge
        self.existingPlan = existingPlan

        _name              = State(initialValue: existingPlan?.name ?? "")
        _selectedType      = State(initialValue: existingPlan?.type ?? .pension)
        _annualBenefit     = State(initialValue: existingPlan.map { String($0.annualBenefit) } ?? "")
        _startAge          = State(initialValue: existingPlan.map { String($0.startAge) } ?? "")
        _inflationAdjusted = State(initialValue: existingPlan?.inflationAdjusted ?? false)
    }

    private var isEditing: Bool { existingPlan != nil }

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
                        // Only auto-set COLA when adding a new plan — don't
                        // override an existing user preference when editing.
                        if !isEditing {
                            inflationAdjusted = newValue.defaultInflationAdjusted
                        }
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

                Section("Start Age") {
                    TextField("Start Age", text: $startAge)
                        .keyboardType(.numberPad)

                    if let age = Int(startAge) {
                        if age > currentAge {
                            Text("Starts in \(age - currentAge) years")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        } else {
                            Text("Currently receiving")
                                .font(.caption)
                                .foregroundColor(.green)
                        }
                    }
                }

                Section("Options") {
                    Toggle("Inflation Adjusted (COLA)", isOn: $inflationAdjusted)

                    Text(inflationAdjusted
                         ? "This benefit grows with inflation — its real purchasing power stays constant over time (e.g. Social Security)."
                         : "This benefit pays a fixed dollar amount — its real purchasing power erodes with inflation over time (e.g. most pensions).")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                // Delete button — only shown when editing an existing plan
                if isEditing {
                    Section {
                        Button(role: .destructive) {
                            showingDeleteConfirmation = true
                        } label: {
                            HStack {
                                Spacer()
                                Text("Delete Benefit")
                                Spacer()
                            }
                        }
                    }
                }
            }
            .navigationTitle(isEditing ? "Edit Benefit" : "Add Benefit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isEditing ? "Save" : "Add") {
                        commitPlan()
                    }
                    .disabled(!isValid)
                }
            }
            .confirmationDialog(
                "Delete \(existingPlan?.name ?? "this benefit")?",
                isPresented: $showingDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button("Delete", role: .destructive) {
                    if let plan = existingPlan {
                        manager.deletePlan(plan)
                    }
                    dismiss()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This cannot be undone.")
            }
        }
    }

    // MARK: - Helpers

    private var isValid: Bool {
        !name.isEmpty &&
        Double(annualBenefit) != nil &&
        Int(startAge) != nil
    }

    private func commitPlan() {
        let plan = DefinedBenefitPlan(
            id: existingPlan?.id ?? UUID(),
            name: name,
            type: selectedType,
            annualBenefit: Double(annualBenefit) ?? 0,
            startAge: Int(startAge) ?? 65,
            inflationAdjusted: inflationAdjusted
        )

        if isEditing {
            manager.updatePlan(plan)
        } else {
            manager.addPlan(plan)
        }
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
        DefinedBenefitPlansView(manager: DefinedBenefitManager())
    }
}
