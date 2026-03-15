//
//  WelcomeDisclaimerView.swift
//  FIRECalc
//
//  First-launch disclaimer and terms acknowledgment
//

import SwiftUI

struct WelcomeDisclaimerView: View {
    @Binding var isPresented: Bool
    @AppStorage("hasAcknowledgedDisclaimer") private var hasAcknowledged = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                // App Icon/Logo
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.system(size: 70))
                    .foregroundStyle(.blue.gradient)
                    .padding(.top, 40)
                
                // Welcome Header
                VStack(spacing: 8) {
                    Text("Welcome to FICalc")
                        .font(.largeTitle.bold())
                    
                    Text("Your Financial Independence Calculator")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                // Disclaimer Cards
                VStack(spacing: 16) {
                    DisclaimerCard(
                        icon: "lightbulb.fill",
                        iconColor: .blue,
                        title: "Educational Tool",
                        text: "FICalc helps you explore financial scenarios and plan for retirement using historical data and Monte Carlo simulations"
                    )
                    
                    DisclaimerCard(
                        icon: "exclamationmark.triangle.fill",
                        iconColor: .orange,
                        title: "Not Financial Advice",
                        text: "This app does NOT provide financial, investment, or tax advice. Always consult qualified professionals before making investment decisions"
                    )
                    
                    DisclaimerCard(
                        icon: "chart.bar.fill",
                        iconColor: .green,
                        title: "Estimates Only",
                        text: "All projections are estimates based on historical data and assumptions. Past performance does not guarantee future results"
                    )
                }
                .padding(.horizontal)
                
                // Terms and Privacy Links
                VStack(spacing: 12) {
                    Text("By continuing, you acknowledge that you have read and agree to our:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    
                    HStack(spacing: 20) {
                        if let termsURL = URL(string: AppConstants.Legal.termsOfServiceURL) {
                            Link(destination: termsURL) {
                                Label("Terms of Service", systemImage: "doc.text")
                                    .font(.caption)
                            }
                        }
                        
                        if let privacyURL = URL(string: AppConstants.Legal.privacyPolicyURL) {
                            Link(destination: privacyURL) {
                                Label("Privacy Policy", systemImage: "lock.shield")
                                    .font(.caption)
                            }
                        }
                    }
                }
                
                // Continue Button
                Button {
                    withAnimation {
                        hasAcknowledged = true
                        isPresented = false
                    }
                } label: {
                    Text("I Understand - Let's Get Started")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(
                            LinearGradient(
                                colors: [.blue, .blue.opacity(0.8)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(12)
                        .shadow(color: .blue.opacity(0.3), radius: 8, y: 4)
                }
                .padding(.horizontal)
                .padding(.top, 8)
                .padding(.bottom, 40)
            }
        }
        .background(Color(.systemGroupedBackground))
    }
}

// MARK: - Disclaimer Card Component

struct DisclaimerCard: View {
    let icon: String
    let iconColor: Color
    let title: String
    let text: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            // Icon
            Image(systemName: icon)
                .font(.system(size: 28))
                .foregroundStyle(iconColor.gradient)
                .frame(width: 44, height: 44)
                .background(iconColor.opacity(0.1))
                .clipShape(Circle())
            
            // Content
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text(text)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            Spacer()
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 4, y: 2)
    }
}

// MARK: - Preview

#Preview {
    WelcomeDisclaimerView(isPresented: .constant(true))
}
