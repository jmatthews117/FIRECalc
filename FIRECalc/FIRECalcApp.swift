//
//  FIRECalcApp.swift
//  FIRECalc
//
//  Created by James Matthews on 1/25/26.
//

import SwiftUI

@main
struct FIRECalcApp: App {
    @StateObject private var appState = AppState()
    
    var body: some Scene {
        WindowGroup {
            ZStack {
                if appState.isLoading {
                    LaunchScreenView()
                        .transition(.opacity)
                } else {
                    ContentView()
                        .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.5), value: appState.isLoading)
        }
    }
}
// MARK: - App State Manager

@MainActor
class AppState: ObservableObject {
    @Published var isLoading = true
    
    init() {
        // Simulate app initialization tasks
        Task {
            // Add minimum display time for better UX
            let minimumDisplayTime: TimeInterval = 1.5
            let startTime = Date()
            
            // Perform any initialization tasks here
            await performInitialization()
            
            // Ensure minimum display time
            let elapsed = Date().timeIntervalSince(startTime)
            if elapsed < minimumDisplayTime {
                try? await Task.sleep(nanoseconds: UInt64((minimumDisplayTime - elapsed) * 1_000_000_000))
            }
            
            isLoading = false
        }
    }
    
    private func performInitialization() async {
        // Add any initialization tasks here, such as:
        // - Loading user defaults
        // - Checking for updates
        // - Preloading data
        // - Setting up services
        
        // For now, just simulate some work
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
    }
}

