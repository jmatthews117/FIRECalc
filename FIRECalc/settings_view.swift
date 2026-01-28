//
//  SettingsView.swift
//  FIRECalc
//
//  App settings and configuration
//

import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    
    @State private var defaultRuns: Double = 10000
    @State private var defaultTimeHorizon: Double = 30
    @State private var defaultInflation: Double = 0.02
    @State private var useHistoricalBootstrap: Bool = true
    @State private var autoRefreshPrices: Bool = false
    @State private var showingResetConfirmation = false
    @State private var showingExportSheet = false
    
    private let persistence = PersistenceService.shared
    
    var body: some View {
        NavigationView {
            Form {
                // Live Price Info
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            
                            Text("Yahoo Finance Integrated")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                        }
                        
                        Text("Live stock prices from Yahoo Finance")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text("No API key required! Get real-time prices for all stocks, ETFs, crypto, and more.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.top, 4)
                    }
                } header: {
                    Text("Live Price Updates")
                }
                
                // Simulation Defaults
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Default Simulation Runs")
                            Spacer()
                            Text("\(Int(defaultRuns))")
                                .foregroundColor(.secondary)
                        }
                        Slider(value: $defaultRuns, in: 1000...50000, step: 1000)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Default Time Horizon")
                            Spacer()
                            Text("\(Int(defaultTimeHorizon)) years")
                                .foregroundColor(.secondary)
                        }
                        Slider(value: $defaultTimeHorizon, in: 5...50, step: 1)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Default Inflation Rate")
                            Spacer()
                            Text(String(format: "%.1f%%", defaultInflation * 100))
                                .foregroundColor(.secondary)
                        }
                        Slider(value: $defaultInflation, in: 0...0.10, step: 0.005)
                    }
                    
                    Toggle("Use Historical Bootstrap", isOn: $useHistoricalBootstrap)
                    
                    Toggle("Auto-Refresh Prices", isOn: $autoRefreshPrices)
                } header: {
                    Text("Simulation Defaults")
                } footer: {
                    Text("These settings will be used as defaults when running new simulations")
                }
                
                // Data Management
                Section {
                    Button(action: { showingExportSheet = true }) {
                        Label("Export Portfolio", systemImage: "square.and.arrow.up")
                    }
                    
                    Button(role: .destructive, action: { showingResetConfirmation = true }) {
                        Label("Reset All Data", systemImage: "trash")
                    }
                } header: {
                    Text("Data Management")
                }
                
                // App Info
                Section {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("\(AppConstants.appVersion) (\(AppConstants.buildNumber))")
                            .foregroundColor(.secondary)
                    }
                    
                    Link(destination: URL(string: "https://finance.yahoo.com")!) {
                        HStack {
                            Text("Yahoo Finance")
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .font(.caption)
                        }
                    }
                } header: {
                    Text("About")
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        saveSettings()
                        dismiss()
                    }
                }
            }
            .onAppear {
                loadSettings()
            }
            .confirmationDialog("Reset All Data", isPresented: $showingResetConfirmation) {
                Button("Reset Everything", role: .destructive) {
                    resetAllData()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will delete all portfolios, simulations, and settings. This cannot be undone.")
            }
            .sheet(isPresented: $showingExportSheet) {
                ExportView()
            }
        }
    }
    
    // MARK: - Functions
    
    private func loadSettings() {
        let settings = persistence.loadSettings()
        defaultRuns = Double(settings.defaultSimulationRuns)
        defaultTimeHorizon = Double(settings.defaultTimeHorizon)
        defaultInflation = settings.defaultInflationRate
        useHistoricalBootstrap = settings.useHistoricalBootstrap
        autoRefreshPrices = settings.autoRefreshPrices
    }
    
    private func saveSettings() {
        persistence.saveSettings(
            defaultRuns: Int(defaultRuns),
            defaultTimeHorizon: Int(defaultTimeHorizon),
            defaultInflation: defaultInflation,
            useBootstrap: useHistoricalBootstrap,
            autoRefresh: autoRefreshPrices
        )
    }
    
    private func resetAllData() {
        try? persistence.deletePortfolio()
        if let bundleID = Bundle.main.bundleIdentifier {
            UserDefaults.standard.removePersistentDomain(forName: bundleID)
        }
        
        // Reset to defaults
        defaultRuns = 10000
        defaultTimeHorizon = 30
        defaultInflation = 0.02
        useHistoricalBootstrap = true
        autoRefreshPrices = false
    }
}

// MARK: - Export View

struct ExportView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var exportData: String = "Preparing export..."
    
    var body: some View {
        NavigationView {
            ScrollView {
                Text(exportData)
                    .font(.system(.caption, design: .monospaced))
                    .padding()
            }
            .navigationTitle("Export Portfolio")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    ShareLink(item: exportData) {
                        Label("Share", systemImage: "square.and.arrow.up")
                    }
                }
            }
            .onAppear {
                prepareExport()
            }
        }
    }
    
    private func prepareExport() {
        do {
            if let portfolio = try PersistenceService.shared.loadPortfolio() {
                let data = try PersistenceService.shared.exportPortfolioAsJSON(portfolio)
                exportData = String(data: data, encoding: .utf8) ?? "Export failed"
            } else {
                exportData = "No portfolio to export"
            }
        } catch {
            exportData = "Export failed: \(error.localizedDescription)"
        }
    }
}

#Preview {
    SettingsView()
}
