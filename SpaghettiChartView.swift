import SwiftUI

struct SpaghettiChartView: View {
    struct PathSeries: Identifiable {
        let id: Int
        let values: [Double] // balances over years (index 0 = start)
    }
    
    let series: [PathSeries]
    let showAxes: Bool
    let lineColor: Color
    let lineOpacity: Double
    let lineWidth: CGFloat
    let maxPathsToDraw: Int
    let yLabel: String
    let xLabel: String
    /// When non-nil, a horizontal black reference line is drawn at this y-value.
    let initialPortfolioValue: Double?
    
    init(series: [PathSeries],
         showAxes: Bool = true,
         lineColor: Color = .blue,
         lineOpacity: Double = 0.15,
         lineWidth: CGFloat = 1,
         maxPathsToDraw: Int = 500,
         yLabel: String = "Balance",
         xLabel: String = "Years",
         initialPortfolioValue: Double? = nil) {
        self.series = series
        self.showAxes = showAxes
        self.lineColor = lineColor
        self.lineOpacity = lineOpacity
        self.lineWidth = lineWidth
        self.maxPathsToDraw = maxPathsToDraw
        self.yLabel = yLabel
        self.xLabel = xLabel
        self.initialPortfolioValue = initialPortfolioValue
    }
    
    var body: some View {
        GeometryReader { geo in
            ZStack {
                if showAxes {
                    axes(in: geo.size)
                }
                Canvas { context, size in
                    let inset: CGFloat = showAxes ? 32 : 8
                    let plotRect = CGRect(x: inset, y: 8, width: size.width - inset - 8, height: size.height - inset - 8)
                    
                    guard plotRect.width > 0, plotRect.height > 0 else { return }
                    
                    let clamped = Array(series.prefix(maxPathsToDraw))
                    guard let domainCount = clamped.first?.values.count, domainCount > 1 else { return }
                    
                    // Compute global min/max for y scaling
                    var minY = Double.greatestFiniteMagnitude
                    var maxY = -Double.greatestFiniteMagnitude
                    for s in clamped {
                        if let localMin = s.values.min(), let localMax = s.values.max() {
                            minY = min(minY, localMin)
                            maxY = max(maxY, localMax)
                        }
                    }
                    if minY == Double.greatestFiniteMagnitude || maxY == -Double.greatestFiniteMagnitude {
                        return
                    }
                    if maxY == minY { maxY += 1 } // avoid divide by zero
                    
                    // Draw each path
                    for s in clamped {
                        var path = Path()
                        for (i, v) in s.values.enumerated() {
                            let t = Double(i) / Double(domainCount - 1)
                            let x = plotRect.minX + CGFloat(t) * plotRect.width
                            let yNorm = (v - minY) / (maxY - minY)
                            let y = plotRect.maxY - CGFloat(yNorm) * plotRect.height
                            if i == 0 {
                                path.move(to: CGPoint(x: x, y: y))
                            } else {
                                path.addLine(to: CGPoint(x: x, y: y))
                            }
                        }
                        let color = (s.values.contains { $0 <= 0 }) ? Color.red : lineColor
                        context.stroke(path, with: .color(color.opacity(lineOpacity)), lineWidth: lineWidth)
                    }
                    
                    // Draw initial portfolio value reference line on top of all paths
                    if let initialValue = initialPortfolioValue,
                       initialValue >= minY, initialValue <= maxY {
                        let yNorm = (initialValue - minY) / (maxY - minY)
                        let y = plotRect.maxY - CGFloat(yNorm) * plotRect.height
                        var refPath = Path()
                        refPath.move(to: CGPoint(x: plotRect.minX, y: y))
                        refPath.addLine(to: CGPoint(x: plotRect.maxX, y: y))
                        context.stroke(
                            refPath,
                            with: .color(.black),
                            style: StrokeStyle(lineWidth: 1.5, dash: [6, 4])
                        )
                    }
                }
            }
        }
        .frame(minHeight: 200)
    }
    
    @ViewBuilder
    private func axes(in size: CGSize) -> some View {
        let inset: CGFloat = 32
        let plotRect = CGRect(x: inset, y: 8, width: size.width - inset - 8, height: size.height - inset - 8)

        let clamped = Array(series.prefix(maxPathsToDraw))
        let domainCount = clamped.first?.values.count ?? 0
        var minY = Double.greatestFiniteMagnitude
        var maxY = -Double.greatestFiniteMagnitude
        for s in clamped {
            if let lo = s.values.min(), let hi = s.values.max() {
                minY = min(minY, lo)
                maxY = max(maxY, hi)
            }
        }
        if minY == Double.greatestFiniteMagnitude || maxY == -Double.greatestFiniteMagnitude {
            minY = 0
            maxY = 1
        }
        if maxY == minY { maxY += 1 }

        func fmt(_ v: Double) -> String {
            if v >= 1_000_000 {
                return String(format: "$%.1fM", v / 1_000_000)
            } else if v >= 1000 {
                return String(format: "$%.0fK", v / 1000)
            } else if v >= 0 {
                return String(format: "$%.0f", v)
            } else if v <= -1_000_000 {
                return String(format: "-$%.1fM", abs(v) / 1_000_000)
            } else if v <= -1000 {
                return String(format: "-$%.0fK", abs(v) / 1000)
            } else {
                return String(format: "-$%.0f", abs(v))
            }
        }

        return ZStack(alignment: .bottomLeading) {
            // Axes lines
            Path { p in
                // y-axis
                p.move(to: CGPoint(x: plotRect.minX, y: plotRect.minY))
                p.addLine(to: CGPoint(x: plotRect.minX, y: plotRect.maxY))
                // x-axis
                p.move(to: CGPoint(x: plotRect.minX, y: plotRect.maxY))
                p.addLine(to: CGPoint(x: plotRect.maxX, y: plotRect.maxY))
            }
            .stroke(Color.secondary.opacity(0.5), lineWidth: 1)
            
            // Y-axis ticks and labels
            ForEach(0...4, id: \.self) { i in
                let t = Double(i) / 4.0
                let val = minY + (maxY - minY) * t
                let y = plotRect.maxY - CGFloat((val - minY) / (maxY - minY)) * plotRect.height
                
                Path { p in
                    p.move(to: CGPoint(x: plotRect.minX - 4, y: y))
                    p.addLine(to: CGPoint(x: plotRect.minX, y: y))
                }
                .stroke(Color.secondary.opacity(0.5), lineWidth: 1)
                
                Text(fmt(val))
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .frame(width: inset - 8, alignment: .trailing)
                    .position(x: plotRect.minX - (inset - 8) / 2, y: y)
            }
            
            // X-axis ticks and labels
            if domainCount > 0 {
                ForEach(0...4, id: \.self) { i in
                    let t = Double(i) / 4.0
                    let x = plotRect.minX + CGFloat(t) * plotRect.width
                    let labelVal = Int(round(t * Double(max(domainCount - 1, 0))))
                    
                    Path { p in
                        p.move(to: CGPoint(x: x, y: plotRect.maxY))
                        p.addLine(to: CGPoint(x: x, y: plotRect.maxY + 4))
                    }
                    .stroke(Color.secondary.opacity(0.5), lineWidth: 1)
                    
                    Text("\(labelVal)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .position(x: x, y: plotRect.maxY + 14)
                }
            }
            
            // Y-axis label: left of the y-axis, vertically centered, rotated -90°
            Text(yLabel)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .fixedSize(horizontal: true, vertical: false)
                .rotationEffect(.degrees(-90))
                .position(x: plotRect.minX - inset + (inset * 0.0), y: plotRect.midY)
            
            // X-axis label below the plot area centered
            Text(xLabel)
                .font(.caption)
                .foregroundColor(.secondary)
                .position(x: plotRect.midX, y: plotRect.maxY + 32)
        }
    }
}

#Preview {
    // Simple preview with random walk paths
    let paths: [SpaghettiChartView.PathSeries] = (0..<200).map { idx in
        var values: [Double] = []
        var v = 100.0
        for _ in 0..<60 {
            v *= (1 + Double.random(in: -0.1...0.1))
            values.append(v)
        }
        return .init(id: idx, values: values)
    }
    SpaghettiChartView(series: paths, lineOpacity: 0.08, maxPathsToDraw: 200)
        .padding()
}
