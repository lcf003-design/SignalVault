import SwiftUI
import Charts

struct BacktestConsoleView: View {
    let symbol: String
    @State private var service = BacktestService()
    @State private var result: BacktestResult?
    @State private var isRunning = false
    @State private var optimizedResults: [BacktestResult] = []
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header
                HStack {
                    VStack(alignment: .leading) {
                        Text("Strategy Audit: \(symbol)")
                            .font(.title2.bold())
                        Text("1,000 Candle Simulation • 1% SL • 3% TP")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    if isRunning {
                        ProgressView()
                    } else {
                        Button("Run Audit") {
                            runAudit()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
                .padding()
                .background(Material.thin)
                .cornerRadius(12)
                
                if let res = result {
                    // Summary Card
                    VStack(spacing: 16) {
                        HStack {
                            BacktestStatView(label: "Total Return", value: "\(String(format: "%.1f", res.totalReturnPercentage * 100))%", color: res.totalReturnPercentage > 0 ? .green : .red)
                            Spacer()
                            BacktestStatView(label: "Win Rate", value: "\(String(format: "%.1f", res.winRate * 100))%", color: .primary)
                            Spacer()
                            BacktestStatView(label: "Max Drawdown", value: "\(String(format: "%.1f", res.maxDrawdown * 100))%", color: res.maxDrawdown > 0.15 ? .red : .orange)
                        }
                        
                        Divider()
                        Text("Expectancy: $\(String(format: "%.2f", res.expectancyRatio)) per trade")
                            .font(.caption.bold())
                    }
                    .padding()
                    .background(Color(uiColor: .secondarySystemBackground))
                    .cornerRadius(12)
                    
                    // Equity Chart
                    VStack(alignment: .leading) {
                        Text("Equity Curve")
                            .font(.headline)
                        
                        if #available(iOS 16.0, *) {
                            /*
                            Chart {
                                ForEach(Array(res.equityCurve.enumerated()), id: \.offset) { index, equity in
                                    LineMark(
                                        x: .value("Trade", index),
                                        y: .value("Equity", equity)
                                    )
                                    .foregroundStyle(res.totalReturnPercentage > 0 ? .green.gradient : .red.gradient)
                                    
                                    AreaMark(
                                        x: .value("Trade", index),
                                        yStart: .value("Base", 100_000),
                                        yEnd: .value("Equity", equity)
                                    )
                                    .foregroundStyle(res.totalReturnPercentage > 0 ? .green.opacity(0.1) : .red.opacity(0.1))
                                }
                            }
                            .frame(height: 200)
                             */
                            Text("Chart temporarily disabled for build verification")
                                .frame(height: 200)
                        } else {
                            Text("Chart requires iOS 16.0+")
                                .foregroundStyle(.secondary)
                                .frame(height: 200)
                                .frame(maxWidth: .infinity)
                                .background(Color(uiColor: .tertiarySystemBackground))
                        }
                    }
                    .padding()
                    .background(Color(uiColor: .secondarySystemBackground))
                    .cornerRadius(12)
                    
                    // Optimization Results
                    if !optimizedResults.isEmpty {
                        VStack(alignment: .leading) {
                            Text("AI Optimization: Top Configs")
                                .font(.headline)
                            
                            ForEach(optimizedResults.prefix(3)) { opt in
                                HStack {
                                    Text(opt.configName)
                                        .font(.caption.monospaced())
                                    Spacer()
                                    Text("\(String(format: "%.1f", opt.totalReturnPercentage * 100))%")
                                        .foregroundStyle(opt.totalReturnPercentage > 0 ? .green : .red)
                                        .bold()
                                }
                                .padding(.vertical, 4)
                                Divider()
                            }
                        }
                        .padding()
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(.blue.opacity(0.3), lineWidth: 1)
                        )
                    }
                } else {
                    if #available(iOS 17.0, *) {
                        ContentUnavailableView("No Data", systemImage: "chart.xyaxis.line", description: Text("Run strategy audit to see historical performance."))
                    } else {
                        VStack(spacing: 12) {
                            Image(systemName: "chart.xyaxis.line")
                                .font(.system(size: 48))
                                .foregroundStyle(.secondary)
                            Text("No Data")
                                .font(.title2.bold())
                            Text("Run strategy audit to see historical performance.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, minHeight: 300)
                    }
                }
            }
            .padding()
        }
        .background(Color(uiColor: .systemGroupedBackground))
    }
    
    private func runAudit() {
        isRunning = true
        Task {
            // Run Default
            let defaultRes = await service.runBacktest(symbol: symbol)
            
            // Run Optimizer
            let topConfigs = await service.findBestSettings(symbol: symbol)
            
            await MainActor.run {
                self.result = defaultRes
                self.optimizedResults = topConfigs
                self.isRunning = false
            }
        }
    }
}

struct BacktestStatView: View {
    let label: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title3.bold())
                .foregroundStyle(color)
        }
    }
}
