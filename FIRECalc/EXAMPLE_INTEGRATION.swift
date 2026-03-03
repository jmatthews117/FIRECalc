//
//  EXAMPLE_INTEGRATION.swift
//  FIRECalc
//
//  Example code showing how to integrate MarketstackTestService
//  Copy these patterns into your actual code
//

import SwiftUI

// MARK: - Example 1: Simple Price Fetch

func exampleSimpleFetch() async {
    do {
        let service = MarketstackTestService.shared
        let quote = try await service.fetchQuote(ticker: "AAPL")
        print("AAPL Price: $\(quote.latestPrice)")
    } catch {
        print("Error: \(error)")
    }
}

// MARK: - Example 2: Update Portfolio Prices

func exampleUpdatePortfolio(portfolio: Portfolio) async -> Portfolio {
    do {
        let service = MarketstackTestService.shared
        let updatedPortfolio = try await service.updatePortfolioPrices(portfolio: portfolio)
        
        // Show how many API calls were used
        let callCount = await service.getCallCount()
        print("Portfolio updated using \(callCount) API calls")
        
        return updatedPortfolio
    } catch {
        print("Error updating portfolio: \(error)")
        return portfolio
    }
}

// MARK: - Example 3: View Model with Service Integration

@MainActor
class PortfolioPriceViewModel: ObservableObject {
    @Published var portfolio: Portfolio
    @Published var isUpdating = false
    @Published var lastUpdateTime: Date?
    @Published var errorMessage: String?
    @Published var apiCallsUsed: Int = 0
    
    // Toggle between services for testing
    private var useMarketstackTest = true
    
    init(portfolio: Portfolio) {
        self.portfolio = portfolio
    }
    
    func refreshPrices() async {
        isUpdating = true
        errorMessage = nil
        
        do {
            if useMarketstackTest {
                // Use Marketstack test service
                let service = MarketstackTestService.shared
                portfolio = try await service.updatePortfolioPrices(portfolio: portfolio)
                apiCallsUsed = await service.getCallCount()
                print("🧪 TEST MODE: Updated portfolio (mock data)")
            } else {
                // Use Yahoo Finance
                let service = YahooFinanceService.shared
                portfolio = try await service.updatePortfolioPrices(portfolio: portfolio)
                print("📡 LIVE: Updated portfolio (Yahoo Finance)")
            }
            
            lastUpdateTime = Date()
        } catch {
            errorMessage = error.localizedDescription
            print("❌ Error: \(error)")
        }
        
        isUpdating = false
    }
    
    func toggleTestMode() {
        useMarketstackTest.toggle()
        print("🔄 Switched to \(useMarketstackTest ? "TEST" : "LIVE") mode")
    }
}

// MARK: - Example 4: SwiftUI View with Service

struct PortfolioWithPricesView: View {
    @StateObject private var viewModel: PortfolioPriceViewModel
    
    init(portfolio: Portfolio) {
        _viewModel = StateObject(wrappedValue: PortfolioPriceViewModel(portfolio: portfolio))
    }
    
    var body: some View {
        NavigationView {
            VStack {
                // Test mode indicator
                if true {  // Set to viewModel.useMarketstackTest if you add that property
                    HStack {
                        Image(systemName: "flask.fill")
                        Text("TEST MODE - Mock Data")
                            .font(.caption)
                    }
                    .foregroundColor(.orange)
                    .padding(8)
                    .background(Color.orange.opacity(0.2))
                    .cornerRadius(8)
                }
                
                List {
                    Section {
                        HStack {
                            Text("Total Value")
                                .font(.headline)
                            Spacer()
                            Text("$\(viewModel.portfolio.totalValue, specifier: "%.2f")")
                                .font(.title3)
                                .bold()
                        }
                        
                        if let lastUpdate = viewModel.lastUpdateTime {
                            HStack {
                                Text("Last Updated")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text(lastUpdate, style: .relative)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        HStack {
                            Text("API Calls Used")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                            Text("\(viewModel.apiCallsUsed)")
                                .font(.caption)
                                .foregroundColor(.blue)
                        }
                    }
                    
                    Section("Assets") {
                        ForEach(viewModel.portfolio.assets) { asset in
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(asset.name)
                                        .font(.headline)
                                    if let ticker = asset.ticker {
                                        Text(ticker)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                
                                Spacer()
                                
                                Text("$\(asset.totalValue, specifier: "%.2f")")
                                    .font(.body)
                            }
                        }
                    }
                    
                    if let error = viewModel.errorMessage {
                        Section {
                            Text(error)
                                .foregroundColor(.red)
                                .font(.caption)
                        }
                    }
                }
                .refreshable {
                    await viewModel.refreshPrices()
                }
            }
            .navigationTitle("Portfolio")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        Task {
                            await viewModel.refreshPrices()
                        }
                    } label: {
                        if viewModel.isUpdating {
                            ProgressView()
                        } else {
                            Image(systemName: "arrow.clockwise")
                        }
                    }
                    .disabled(viewModel.isUpdating)
                }
            }
        }
    }
}

// MARK: - Example 5: Batch Fetching for Efficiency

func exampleBatchFetch() async {
    let tickers = ["AAPL", "MSFT", "GOOGL", "TSLA", "SPY"]
    
    do {
        let service = MarketstackTestService.shared
        
        // ❌ INEFFICIENT: 5 API calls
        // for ticker in tickers {
        //     let quote = try await service.fetchQuote(ticker: ticker)
        //     print("\(ticker): $\(quote.latestPrice)")
        // }
        
        // ✅ EFFICIENT: 1 API call
        let quotes = try await service.fetchBatchQuotes(tickers: tickers)
        for (ticker, quote) in quotes {
            print("\(ticker): $\(quote.latestPrice)")
        }
        
        let callCount = await service.getCallCount()
        print("Used \(callCount) API call(s) for \(tickers.count) tickers")
        
    } catch {
        print("Error: \(error)")
    }
}

// MARK: - Example 6: Service Abstraction Protocol

/// Protocol that both Yahoo and Marketstack services can conform to
/// NOTE: This is commented out because actors cannot conform to protocols with async requirements
/// in the same way. For a real implementation, you'd use a wrapper class or different architecture.

/*
protocol PriceServiceProtocol {
    func fetchQuote(ticker: String) async throws -> YFStockQuote
    func fetchCryptoQuote(symbol: String) async throws -> YFCryptoQuote
    func fetchBatchQuotes(tickers: [String]) async throws -> [String: YFStockQuote]
    func updatePortfolioPrices(portfolio: Portfolio) async throws -> Portfolio
}

// Then extend your services to conform:
// extension YahooFinanceService: PriceServiceProtocol {}
// extension MarketstackTestService: PriceServiceProtocol {}
*/

// Alternative approach using a simple enum:
enum PriceServiceType {
    case yahoo
    case marketstackTest
    
    func fetchQuote(ticker: String) async throws -> YFStockQuote {
        switch self {
        case .yahoo:
            return try await YahooFinanceService.shared.fetchQuote(ticker: ticker)
        case .marketstackTest:
            return try await MarketstackTestService.shared.fetchQuote(ticker: ticker)
        }
    }
    
    func updatePortfolioPrices(portfolio: Portfolio) async throws -> Portfolio {
        switch self {
        case .yahoo:
            return try await YahooFinanceService.shared.updatePortfolioPrices(portfolio: portfolio)
        case .marketstackTest:
            return try await MarketstackTestService.shared.updatePortfolioPrices(portfolio: portfolio)
        }
    }
}

// Use it like this:
class PriceServiceManager {
    static let shared = PriceServiceManager()
    
    private var currentService: PriceServiceType = .marketstackTest
    
    func switchToYahoo() {
        currentService = .yahoo
        print("🔄 Switched to Yahoo Finance")
    }
    
    func switchToMarketstackTest() {
        currentService = .marketstackTest
        print("🔄 Switched to Marketstack (TEST)")
    }
    
    func fetchQuote(ticker: String) async throws -> YFStockQuote {
        return try await currentService.fetchQuote(ticker: ticker)
    }
    
    func updatePortfolio(_ portfolio: Portfolio) async throws -> Portfolio {
        return try await currentService.updatePortfolioPrices(portfolio: portfolio)
    }
}

// MARK: - Example 7: SwiftUI Settings View

struct PriceServiceSettingsView: View {
    @AppStorage("priceService") private var selectedService = "yahoo"
    @State private var apiCallCount = 0
    
    var body: some View {
        Form {
            Section("Price Data Source") {
                Picker("Service", selection: $selectedService) {
                    Text("Yahoo Finance (Free)").tag("yahoo")
                    Text("Marketstack Test (Mock)").tag("marketstack-test")
                    Text("Marketstack Live (API Key Required)").tag("marketstack-live")
                }
                .pickerStyle(.segmented)
                
                if selectedService == "marketstack-test" {
                    HStack {
                        Image(systemName: "flask.fill")
                            .foregroundColor(.orange)
                        Text("Test mode uses mock data")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            if selectedService.contains("marketstack") {
                Section("Usage Statistics") {
                    HStack {
                        Text("API Calls (This Session)")
                        Spacer()
                        Text("\(apiCallCount)")
                            .foregroundColor(.blue)
                    }
                    
                    Button("Reset Counter") {
                        Task {
                            await MarketstackTestService.shared.resetCallCounter()
                            apiCallCount = 0
                        }
                    }
                }
            }
            
            Section("About") {
                Link("Marketstack Pricing", 
                     destination: URL(string: "https://marketstack.com/product")!)
                Link("API Documentation", 
                     destination: URL(string: "https://marketstack.com/documentation")!)
            }
        }
        .navigationTitle("Price Service")
        .task {
            updateCallCount()
        }
    }
    
    private func updateCallCount() {
        Task {
            apiCallCount = await MarketstackTestService.shared.getCallCount()
        }
    }
}

// MARK: - Example 8: Simple Test in Preview

#Preview("Portfolio with Marketstack Test") {
    let testPortfolio = Portfolio(
        name: "Test Portfolio",
        assets: [
            Asset(name: "Apple", assetClass: .stocks, ticker: "AAPL", quantity: 10, unitValue: 180),
            Asset(name: "Microsoft", assetClass: .stocks, ticker: "MSFT", quantity: 5, unitValue: 415),
            Asset(name: "Bitcoin", assetClass: .crypto, ticker: "BTC", quantity: 0.5, unitValue: 68000)
        ]
    )
    
    PortfolioWithPricesView(portfolio: testPortfolio)
}

// MARK: - Notes

/*
 HOW TO USE THESE EXAMPLES:
 
 1. Copy the patterns you need into your actual code
 2. Start with the simple fetch example to verify it works
 3. Use the ViewModel pattern for your UI
 4. Consider implementing the protocol abstraction for easy service switching
 5. Monitor API call count to estimate real usage
 
 TESTING CHECKLIST:
 
 ✅ Run MarketstackTestView to verify basic functionality
 ✅ Test portfolio updates with your actual portfolio
 ✅ Check API call counter after each operation
 ✅ Try batch fetching vs individual fetches
 ✅ Verify error handling works
 ✅ Test with different asset types (stocks, crypto, ETFs)
 
 WHEN TO MOVE TO PHASE 2:
 
 - You've confirmed the test service works correctly
 - You understand your API usage patterns
 - You've decided on free vs paid Marketstack tier
 - You have your API key ready
 - You've implemented caching strategy (if needed)
 */
