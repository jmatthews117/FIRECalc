//
//  MarketstackTestView.swift
//  FICalc
//
//  TEMPORARY - Debug view to test Marketstack integration (TEST MODE)
//  Delete this file once everything works
//

import SwiftUI

struct MarketstackTestView: View {
    @State private var ticker: String = "AAPL"
    @State private var price: String = ""
    @State private var isLoading: Bool = false
    @State private var logs: [String] = []
    @State private var apiCallCount: Int = 0
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                VStack(spacing: 8) {
                    Text("Marketstack Test")
                        .font(.title)
                        .bold()
                    
                    Text("TEST MODE - Mock Data")
                        .font(.caption)
                        .foregroundColor(.orange)
                        .padding(.horizontal)
                        .padding(.vertical, 4)
                        .background(Color.orange.opacity(0.2))
                        .cornerRadius(8)
                }
                
                // API Call Counter
                HStack {
                    Image(systemName: "chart.bar.fill")
                        .foregroundColor(.blue)
                    Text("Mock API Calls: \(apiCallCount)")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Button("Reset Counter") {
                        resetCounter()
                    }
                    .font(.caption)
                    .buttonStyle(.bordered)
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(8)
                .padding(.horizontal)
                
                HStack {
                    TextField("Ticker", text: $ticker)
                        .textFieldStyle(.roundedBorder)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                    
                    Button("Fetch") {
                        testFetch()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isLoading)
                }
                .padding()
                
                if isLoading {
                    ProgressView("Fetching...")
                }
                
                if !price.isEmpty {
                    VStack(spacing: 4) {
                        Text("Price: \(price)")
                            .font(.title2)
                            .foregroundColor(.green)
                        Text("(Mock data)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Divider()
                
                Text("Console Log:")
                    .font(.headline)
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(logs.indices, id: \.self) { index in
                            Text(logs[index])
                                .font(.system(.caption, design: .monospaced))
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .padding()
                }
                .background(Color(.systemGray6))
                .cornerRadius(8)
                .padding()
            }
            .navigationTitle("Marketstack Debug")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Clear Logs") {
                        logs = []
                    }
                    .font(.caption)
                }
            }
        }
    }
    
    private func addLog(_ message: String) {
        logs.append(message)
        print(message)
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
            addLog("🔄 API counter reset")
        }
    }
    
    private func testFetch() {
        price = ""
        logs = []
        isLoading = true
        
        addLog("🚀 Starting test for \(ticker)")
        addLog("🧪 Using TEST MODE (no real API calls)")
        
        Task {
            do {
                addLog("📡 Calling Marketstack Test Service...")
                
                let service = MarketstackTestService.shared
                let quote = try await service.fetchQuote(ticker: ticker)
                
                await MainActor.run {
                    price = "$\(String(format: "%.2f", quote.latestPrice))"
                    addLog("✅ SUCCESS: \(price)")
                    addLog("   Symbol: \(quote.symbol)")
                    if let change = quote.change {
                        addLog("   Change: $\(String(format: "%.2f", change))")
                    }
                    if let changePercent = quote.changePercent {
                        addLog("   Change %: \(String(format: "%.2f%%", changePercent * 100))")
                    }
                    if let volume = quote.volume {
                        addLog("   Volume: \(volume)")
                    }
                    isLoading = false
                    updateCallCount()
                }
            } catch {
                await MainActor.run {
                    addLog("❌ ERROR: \(error.localizedDescription)")
                    price = "Error"
                    isLoading = false
                    updateCallCount()
                }
            }
        }
    }
}

#Preview {
    MarketstackTestView()
}
