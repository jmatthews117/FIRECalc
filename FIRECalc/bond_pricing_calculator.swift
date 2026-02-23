//
//  bond_pricing_calculator.swift
//  FICalc
//
//  NEW FILE - Advanced bond pricing calculator
//

import SwiftUI

struct BondPricingCalculatorView: View {
    @Environment(\.dismiss) private var dismiss
    
    @State private var faceValue: String = "1000"
    @State private var couponRate: String = "5.0"
    @State private var yieldToMaturity: String = "4.5"
    @State private var yearsToMaturity: String = "10"
    @State private var paymentsPerYear: Double = 2
    @State private var purchasePrice: String = ""
    
    @State private var calculatedPrice: Double?
    @State private var currentYield: Double?
    @State private var duration: Double?
    
    var body: some View {
        NavigationView {
            Form {
                Section("Bond Details") {
                    HStack {
                        Text("Face Value")
                        Spacer()
                        TextField("$1000", text: $faceValue)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                    
                    HStack {
                        Text("Coupon Rate (%)")
                        Spacer()
                        TextField("5.0", text: $couponRate)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                    
                    HStack {
                        Text("Yield to Maturity (%)")
                        Spacer()
                        TextField("4.5", text: $yieldToMaturity)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                    
                    HStack {
                        Text("Years to Maturity")
                        Spacer()
                        TextField("10", text: $yearsToMaturity)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                    
                    Picker("Payment Frequency", selection: $paymentsPerYear) {
                        Text("Annual").tag(1.0)
                        Text("Semi-Annual").tag(2.0)
                        Text("Quarterly").tag(4.0)
                    }
                    .pickerStyle(.segmented)
                }
                
                Section("Purchase Price (Optional)") {
                    HStack {
                        Text("Amount Paid")
                        Spacer()
                        TextField("Optional", text: $purchasePrice)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                }
                
                Section {
                    Button(action: calculate) {
                        HStack {
                            Spacer()
                            Text("Calculate Fair Value")
                                .fontWeight(.semibold)
                            Spacer()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }
                
                if let price = calculatedPrice {
                    Section("Fair Market Value") {
                        HStack {
                            Text("Theoretical Price")
                            Spacer()
                            Text(price.toCurrency())
                                .font(.title3)
                                .fontWeight(.bold)
                                .foregroundColor(.blue)
                        }
                        
                        if let purchased = Double(purchasePrice), purchased > 0 {
                            let diff = price - purchased
                            let diffPercent = (diff / purchased) * 100
                            
                            Divider()
                            
                            HStack {
                                Text("vs Purchase Price")
                                Spacer()
                                VStack(alignment: .trailing) {
                                    Text(diff.toCurrency())
                                        .fontWeight(.semibold)
                                        .foregroundColor(diff >= 0 ? .green : .red)
                                    Text(String(format: "%.2f%%", diffPercent))
                                        .font(.caption)
                                        .foregroundColor(diff >= 0 ? .green : .red)
                                }
                            }
                            
                            if price > purchased {
                                Text("✓ Trading at a premium (above par)")
                                    .font(.caption)
                                    .foregroundColor(.green)
                            } else if price < purchased {
                                Text("⚠️ Trading at a discount (below par)")
                                    .font(.caption)
                                    .foregroundColor(.red)
                            } else {
                                Text("= Trading at par")
                                    .font(.caption)
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                    
                    Section("Bond Metrics") {
                        if let cy = currentYield {
                            HStack {
                                Text("Current Yield")
                                Spacer()
                                Text(String(format: "%.2f%%", cy))
                                    .foregroundColor(.green)
                            }
                        }
                        
                        if let dur = duration {
                            HStack {
                                Text("Duration")
                                Spacer()
                                Text(String(format: "%.2f years", dur))
                                    .foregroundColor(.orange)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Bond Pricing Calculator")
            .navigationBarTitleDisplayMode(.inline)
            .keyboardDoneButton()
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
    
    private func calculate() {
        guard let face = Double(faceValue),
              let coupon = Double(couponRate),
              let ytm = Double(yieldToMaturity),
              let years = Double(yearsToMaturity) else {
            return
        }
        
        let totalPeriods = years * paymentsPerYear
        let couponPayment = (face * (coupon / 100)) / paymentsPerYear
        let ytmPerPeriod = (ytm / 100) / paymentsPerYear
        
        // PV of coupon payments
        var pvCoupons: Double = 0
        for period in 1...Int(totalPeriods) {
            pvCoupons += couponPayment / pow(1 + ytmPerPeriod, Double(period))
        }
        
        // PV of face value
        let pvFace = face / pow(1 + ytmPerPeriod, totalPeriods)
        
        calculatedPrice = pvCoupons + pvFace
        
        // Current yield
        if let price = calculatedPrice {
            currentYield = ((face * (coupon / 100)) / price) * 100
        }
        
        // Duration (Macaulay)
        var weightedCF: Double = 0
        for period in 1...Int(totalPeriods) {
            let pv = couponPayment / pow(1 + ytmPerPeriod, Double(period))
            weightedCF += pv * (Double(period) / paymentsPerYear)
        }
        weightedCF += pvFace * years
        
        if let price = calculatedPrice {
            duration = weightedCF / price
        }
    }
}

#Preview {
    BondPricingCalculatorView()
}
