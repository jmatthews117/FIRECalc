//
//  LaunchScreenView.swift
//  FIRECalc
//
//  Launch screen displayed while app initializes
//

import SwiftUI

struct LaunchScreenView: View {
    @State private var isAnimating = false
    @State private var opacity = 0.0
    @State private var scale = 0.8
    
    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                gradient: Gradient(colors: [
                    Color.blue.opacity(0.6),
                    Color.purple.opacity(0.6)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 32) {
                Spacer()
                
                // App icon/logo area
                ZStack {
                    // Outer glow circle
                    Circle()
                        .fill(
                            RadialGradient(
                                gradient: Gradient(colors: [
                                    Color.white.opacity(0.3),
                                    Color.white.opacity(0.0)
                                ]),
                                center: .center,
                                startRadius: 30,
                                endRadius: 80
                            )
                        )
                        .frame(width: 160, height: 160)
                        .scaleEffect(isAnimating ? 1.1 : 0.9)
                        .opacity(isAnimating ? 0.6 : 0.3)
                    
                    // Icon background
                    Circle()
                        .fill(Color.white)
                        .frame(width: 120, height: 120)
                        .shadow(color: .black.opacity(0.2), radius: 20, x: 0, y: 10)
                    
                    // FIRE flame icon
                    VStack(spacing: 4) {
                        Image(systemName: "flame.fill")
                            .font(.system(size: 50, weight: .semibold))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.orange, .red],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                        
                        Image(systemName: "chart.line.uptrend.xyaxis")
                            .font(.system(size: 24, weight: .medium))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.blue, .purple],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .offset(y: -8)
                    }
                }
                .scaleEffect(scale)
                .opacity(opacity)
                
                // App name
                VStack(spacing: 8) {
                    Text("FIRECalc")
                        .font(.system(size: 40, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    
                    Text("Financial Independence Calculator")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.9))
                }
                .opacity(opacity)
                
                Spacer()
                
                // Loading indicator
                VStack(spacing: 16) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(1.2)
                    
                    Text("Loading your portfolio...")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.8))
                }
                .opacity(opacity)
                .padding(.bottom, 50)
            }
        }
        .onAppear {
            // Animate entrance
            withAnimation(.easeOut(duration: 0.8)) {
                opacity = 1.0
                scale = 1.0
            }
            
            // Pulsing animation
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                isAnimating = true
            }
        }
    }
}

#Preview {
    LaunchScreenView()
}
