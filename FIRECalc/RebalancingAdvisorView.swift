//
//  RebalancingAdvisorView.swift
//  FIRECalc
//
//  Shows current allocation vs. user-defined targets and calculates
//  exactly how much to buy / sell per asset class to rebalance.
//

import SwiftUI

// MARK: - Target Allocation Entry

private struct TargetEntry: Identifiable {
    let id: AssetClass
    var targetPercent: Double   // 0–100
}

// MARK: - Main View

struct RebalancingAdvisorView: View {
    @ObservedObject var portfolioVM: PortfolioViewModel

    // Target allocations keyed by AssetClass, stored as 0–100 percentages
    @State private var targets: [TargetEntry] = []
    @State private var isDirty = false

    private var portfolio: Portfolio { portfolioVM.portfolio }
    private var totalValue: Double { portfolioVM.totalValue }

    // Asset classes that actually appear in the portfolio
    private var presentClasses: [AssetClass] {
        let classes = Set(portfolio.assets.map(\.assetClass))
        return AssetClass.allCases.filter { classes.contains($0) }
    }

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                if !portfolioVM.hasAssets {
                    emptyStateView
                } else {
                    portfolioValueCard
                    targetAllocationCard
                    if totalTargetPercent > 0 {
                        rebalancingActionsCard
                    }
                }
            }
            .padding()
        }
        .navigationTitle("Rebalancing Advisor")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear(perform: buildDefaultTargets)
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "slider.horizontal.3")
                .font(.system(size: 50))
                .foregroundColor(.secondary)
            Text("No assets in portfolio")
                .font(.headline)
            Text("Add assets to your portfolio first, then come back to set target allocations.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 60)
    }

    // MARK: - Portfolio Value Card

    private var portfolioValueCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "briefcase.fill")
                    .foregroundColor(.blue)
                    .font(.title2)
                Text("Total Portfolio Value")
                    .font(.headline)
            }
            Text(totalValue.toCurrency())
                .font(.system(size: 34, weight: .bold, design: .rounded))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(AppConstants.UI.cornerRadius)
        .shadow(radius: AppConstants.UI.shadowRadius)
    }

    // MARK: - Target Allocation Card

    private var targetAllocationCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Image(systemName: "slider.horizontal.3")
                    .foregroundColor(.purple)
                    .font(.title2)
                Text("Target Allocations")
                    .font(.headline)
                Spacer()
                // Running total badge
                Text(String(format: "%.0f%% / 100%%", totalTargetPercent))
                    .font(.caption)
                    .fontWeight(.semibold)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(totalTargetBadgeColor.opacity(0.15))
                    .foregroundColor(totalTargetBadgeColor)
                    .cornerRadius(8)
            }

            Text("Set your desired allocation for each asset class. The advisor will show what to buy or sell.")
                .font(.caption)
                .foregroundColor(.secondary)

            ForEach($targets) { $entry in
                targetRow(entry: $entry)
            }

            if totalTargetPercent != 100 && totalTargetPercent > 0 {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundColor(.orange)
                    Text("Targets must add up to exactly 100%.")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(AppConstants.UI.cornerRadius)
        .shadow(radius: AppConstants.UI.shadowRadius)
    }

    private func targetRow(entry: Binding<TargetEntry>) -> some View {
        let assetClass = entry.wrappedValue.id
        let currentValue = portfolio.totalValue(for: assetClass)
        let currentPct = totalValue > 0 ? currentValue / totalValue * 100 : 0

        return VStack(spacing: 6) {
            HStack {
                Image(systemName: assetClass.iconName)
                    .frame(width: 22)
                    .foregroundColor(assetClass.color)
                Text(assetClass.rawValue)
                    .font(.subheadline)
                Spacer()
                Text(String(format: "Target: %.0f%%", entry.wrappedValue.targetPercent))
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
            }

            HStack(spacing: 8) {
                // Current allocation mini-bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color.secondary.opacity(0.15))
                        RoundedRectangle(cornerRadius: 3)
                            .fill(assetClass.color.opacity(0.5))
                            .frame(width: geo.size.width * min(1, currentPct / 100))
                    }
                }
                .frame(height: 6)

                Text(String(format: "Now: %.0f%%", currentPct))
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .frame(width: 60, alignment: .trailing)
            }

            Slider(value: entry.targetPercent, in: 0...100, step: 1)
                .tint(assetClass.color)
        }
        .padding(.vertical, 4)
    }

    // MARK: - Rebalancing Actions Card

    private var rebalancingActionsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Image(systemName: "arrow.left.arrow.right.circle.fill")
                    .foregroundColor(.green)
                    .font(.title2)
                Text("Recommended Actions")
                    .font(.headline)
            }

            if totalTargetPercent != 100 {
                Text("Adjust targets to total exactly 100% to see recommendations.")
                    .font(.caption)
                    .foregroundColor(.orange)
            } else {
                let actions = rebalancingActions
                if actions.isEmpty {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("Your portfolio is already on target — no trades needed!")
                            .font(.subheadline)
                            .foregroundColor(.green)
                    }
                } else {
                    ForEach(actions, id: \.assetClass.id) { action in
                        actionRow(action: action)
                        if action.assetClass != actions.last?.assetClass {
                            Divider()
                        }
                    }

                    Divider()

                    // Drift summary
                    HStack {
                        Image(systemName: "info.circle")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("Amounts are approximate. Actual trades may vary by price at time of execution.")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(AppConstants.UI.cornerRadius)
        .shadow(radius: AppConstants.UI.shadowRadius)
    }

    private func actionRow(action: RebalanceAction) -> some View {
        HStack(alignment: .top, spacing: 12) {
            // Direction indicator
            ZStack {
                Circle()
                    .fill(action.isBuy ? Color.green.opacity(0.15) : Color.red.opacity(0.15))
                    .frame(width: 36, height: 36)
                Image(systemName: action.isBuy ? "arrow.up.circle.fill" : "arrow.down.circle.fill")
                    .foregroundColor(action.isBuy ? .green : .red)
                    .font(.title3)
            }

            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text(action.isBuy ? "BUY" : "SELL")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(action.isBuy ? .green : .red)
                    Text(action.assetClass.rawValue)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                }

                Text(action.amount.toCurrency())
                    .font(.title3)
                    .fontWeight(.bold)

                HStack(spacing: 6) {
                    Text(String(format: "%.1f%%", action.currentPercent))
                        .foregroundColor(.secondary)
                    Image(systemName: "arrow.right")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text(String(format: "%.0f%%", action.targetPercent))
                        .foregroundColor(.primary)
                }
                .font(.caption)

                let drift = action.currentPercent - action.targetPercent
                Text(String(format: "%+.1f%% drift", drift))
                    .font(.caption2)
                    .foregroundColor(abs(drift) > 5 ? .orange : .secondary)
            }

            Spacer()
        }
        .padding(.vertical, 4)
    }

    // MARK: - Helpers

    private var totalTargetPercent: Double {
        targets.reduce(0) { $0 + $1.targetPercent }
    }

    private var totalTargetBadgeColor: Color {
        let total = totalTargetPercent
        if total == 100 { return .green }
        if total > 100 { return .red }
        return .orange
    }

    /// Build one target entry per asset class currently in the portfolio,
    /// seeded with the current actual allocation so sliders start at reality.
    private func buildDefaultTargets() {
        guard targets.isEmpty else { return }
        targets = presentClasses.map { ac in
            let currentPct = totalValue > 0
                ? portfolio.totalValue(for: ac) / totalValue * 100
                : 0
            return TargetEntry(id: ac, targetPercent: currentPct.rounded())
        }
        // Normalise rounding so they sum to exactly 100
        let diff = 100 - targets.reduce(0) { $0 + $1.targetPercent }
        if diff != 0, let idx = targets.indices.first {
            targets[idx].targetPercent += diff
        }
    }

    struct RebalanceAction {
        let assetClass: AssetClass
        let currentPercent: Double
        let targetPercent: Double
        let amount: Double      // absolute dollar change needed
        let isBuy: Bool
    }

    private var rebalancingActions: [RebalanceAction] {
        guard totalTargetPercent == 100 else { return [] }

        return targets.compactMap { entry in
            let currentValue = portfolio.totalValue(for: entry.id)
            let currentPct = totalValue > 0 ? currentValue / totalValue * 100 : 0
            let targetValue = totalValue * entry.targetPercent / 100
            let delta = targetValue - currentValue

            // Only surface actions where the drift is meaningful (>$1 and >0.5%)
            guard abs(delta) > 1, abs(currentPct - entry.targetPercent) >= 0.5 else { return nil }

            return RebalanceAction(
                assetClass: entry.id,
                currentPercent: currentPct,
                targetPercent: entry.targetPercent,
                amount: abs(delta),
                isBuy: delta > 0
            )
        }
        .sorted { $0.amount > $1.amount } // largest trades first
    }
}

#Preview {
    NavigationView {
        RebalancingAdvisorView(portfolioVM: PortfolioViewModel())
    }
}
