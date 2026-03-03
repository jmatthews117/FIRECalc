//
//  PriceServiceToggle.swift
//  FIRECalc
//
//  Simple toggle to switch between Yahoo Finance and Marketstack Test Service
//  Add this to your settings or debug menu
//

import SwiftUI

struct PriceServiceToggle: View {
    @State private var useTestService: Bool = AlternativePriceService.useMarketstackTest
    @State private var apiCallCount: Int = 0
    
    var body: some View {
        VStack(spacing: 20) {
            // Service Toggle
            VStack(spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Price Data Source")
                            .font(.headline)
                        Text(useTestService ? "Using mock test data" : "Using live Yahoo Finance data")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Toggle("", isOn: $useTestService)
                        .labelsHidden()
                        .onChange(of: useTestService) { _, newValue in
                            AlternativePriceService.useMarketstackTest = newValue
                            if newValue {
                                print("🧪 Switched to Marketstack TEST mode (mock data)")
                            } else {
                                print("📡 Switched to Yahoo Finance (live data)")
                            }
                            updateCallCount()
                        }
                }
                
                // Visual indicator
                HStack {
                    Image(systemName: useTestService ? "flask.fill" : "wifi")
                        .foregroundColor(useTestService ? .orange : .green)
                    
                    Text(useTestService ? "TEST MODE" : "LIVE DATA")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(useTestService ? .orange : .green)
                    
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(useTestService ? Color.orange.opacity(0.1) : Color.green.opacity(0.1))
                .cornerRadius(8)
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
            
            // API Call Counter (only shown in test mode)
            if useTestService {
                VStack(spacing: 12) {
                    HStack {
                        Image(systemName: "chart.bar.fill")
                            .foregroundColor(.blue)
                        Text("Mock API Calls This Session")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Text("\(apiCallCount)")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.blue)
                    }
                    
                    HStack {
                        Button("Reset Counter") {
                            resetCounter()
                        }
                        .buttonStyle(.bordered)
                        .font(.caption)
                        
                        Spacer()
                        
                        Button("View Test UI") {
                            // This would navigate to MarketstackTestView
                            // Implementation depends on your navigation setup
                        }
                        .buttonStyle(.borderedProminent)
                        .font(.caption)
                    }
                }
                .padding()
                .background(Color.blue.opacity(0.1))
                .cornerRadius(12)
            }
            
            // Info text
            VStack(alignment: .leading, spacing: 8) {
                Label("About Test Mode", systemImage: "info.circle")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                if useTestService {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("• Returns hardcoded mock prices")
                        Text("• No real API calls or network usage")
                        Text("• Perfect for testing Phase 1 integration")
                        Text("• Tracks API call count for estimation")
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                } else {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("• Fetches live prices from Yahoo Finance")
                        Text("• Real-time market data")
                        Text("• Free and unlimited")
                        Text("• No API key required")
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
            
            Spacer()
        }
        .padding()
        .navigationTitle("Price Service")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            updateCallCount()
        }
    }
    
    private func updateCallCount() {
        Task {
            apiCallCount = await MarketstackTestService.shared.getCallCount()
        }
    }
    
    private func resetCounter() {
        Task {
            await MarketstackTestService.shared.resetCallCounter()
            updateCallCount()
        }
    }
}

// MARK: - Compact Version for Settings

struct PriceServiceToggleCompact: View {
    @State private var useTestService: Bool = AlternativePriceService.useMarketstackTest
    
    var body: some View {
        Toggle(isOn: $useTestService) {
            HStack {
                Image(systemName: useTestService ? "flask.fill" : "wifi")
                    .foregroundColor(useTestService ? .orange : .green)
                
                VStack(alignment: .leading) {
                    Text("Test Mode")
                        .font(.body)
                    Text(useTestService ? "Mock data" : "Live data")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .onChange(of: useTestService) { _, newValue in
            AlternativePriceService.useMarketstackTest = newValue
            print(newValue ? "🧪 TEST MODE" : "📡 LIVE MODE")
        }
    }
}

#Preview("Full") {
    NavigationView {
        PriceServiceToggle()
    }
}

#Preview("Compact") {
    Form {
        Section("Price Service") {
            PriceServiceToggleCompact()
        }
    }
}
