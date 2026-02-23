//
//  YahooTestView.swift
//  FICalc
//
//  TEMPORARY - Debug view to test Yahoo Finance
//  Delete this file once everything works
//

import SwiftUI

struct YahooTestView: View {
    @State private var ticker: String = "AAPL"
    @State private var price: String = ""
    @State private var isLoading: Bool = false
    @State private var logs: [String] = []
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Yahoo Finance Test")
                    .font(.title)
                    .bold()
                
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
                    Text("Price: \(price)")
                        .font(.title2)
                        .foregroundColor(.green)
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
            .navigationTitle("Debug")
        }
    }
    
    private func addLog(_ message: String) {
        logs.append(message)
        print(message)
    }
    
    private func testFetch() {
        price = ""
        logs = []
        isLoading = true
        
        addLog("🚀 Starting test for \(ticker)")
        
        Task {
            do {
                addLog("📡 Calling Yahoo Finance...")
                
                let service = YahooFinanceService.shared
                let quote = try await service.fetchQuote(ticker: ticker)
                
                await MainActor.run {
                    price = "$\(quote.latestPrice)"
                    addLog("✅ SUCCESS: $\(quote.latestPrice)")
                    addLog("   Symbol: \(quote.symbol)")
                    addLog("   Change: \(quote.change ?? 0)")
                    addLog("   Volume: \(quote.volume ?? 0)")
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    addLog("❌ ERROR: \(error.localizedDescription)")
                    price = "Error"
                    isLoading = false
                }
            }
        }
    }
}

#Preview {
    YahooTestView()
}
