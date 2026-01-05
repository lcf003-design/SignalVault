import SwiftUI
import Charts
import SwiftData

struct PerformanceDashboard: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel = PerformanceViewModel()
    @State private var showMirror = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // 1. Alpha Alert
                    if !viewModel.weeklyAlphaMessage.isEmpty {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.yellow)
                            Text(viewModel.weeklyAlphaMessage)
                                .font(.subheadline)
                                .fontWeight(.medium)
                        }
                        .padding()
                        .background(Color.yellow.opacity(0.1))
                        .cornerRadius(12)
                        .padding(.horizontal)
                    }
                    
                    // 2. The Equity Curve
                    VStack(alignment: .leading) {
                        HStack {
                            Text("Equity Curve")
                                .font(.headline)
                            Spacer()
                            Toggle("The Mirror", isOn: $showMirror)
                                .toggleStyle(SwitchToggleStyle(tint: .purple))
                        }
                        .padding(.horizontal)
                        
                        Chart {
                            // User Line
                            ForEach(viewModel.equityCurve) { point in
                                LineMark(
                                    x: .value("Date", point.date),
                                    y: .value("Equity", point.value)
                                )
                                .foregroundStyle(.blue)
                                .interpolationMethod(.catmullRom)
                            }
                            .symbol(by: .value("Type", "User"))
                            
                            // AI Line (The Mirror)
                            if showMirror {
                                ForEach(viewModel.aiEquityCurve) { point in
                                    LineMark(
                                        x: .value("Date", point.date),
                                        y: .value("Equity", point.value)
                                    )
                                    .foregroundStyle(.purple)
                                    .lineStyle(StrokeStyle(lineWidth: 2, dash: [5, 5]))
                                }
                                .symbol(by: .value("Type", "AI"))
                            }
                        }
                        .frame(height: 250)
                        .padding()
                        .background(Color(uiColor: .secondarySystemBackground))
                        .cornerRadius(16)
                    }
                    .padding(.horizontal)
                    
                    // 3. KPI Grid
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                        KPICard(title: "Win Rate", value: String(format: "%.1f%%", viewModel.winRate), icon: "trophy.fill", color: .green)
                        KPICard(title: "Profit Factor", value: String(format: "%.2f", viewModel.profitFactor), icon: "chart.bar.fill", color: .blue)
                        KPICard(title: "Max Drawdown", value: String(format: "-%.1f%%", viewModel.maxDrawdown), icon: "arrow.down.right.circle.fill", color: .red)
                        KPICard(title: "Signals Missed", value: "\(viewModel.aiEquityCurve.count)", icon: "eye.slash.fill", color: .purple)
                    }
                    .padding(.horizontal)
                    
                    // 4. Mission 23: Social Leaderboard
                    LeaderboardView()
                }
                .padding(.top)
            }
            .navigationTitle("Performance")
            .onAppear {
                viewModel.setContext(modelContext)
                viewModel.calculateMetrics()
            }
        }
    }
}

struct KPICard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                Spacer()
            }
            
            Text(value)
                .font(.system(size: 24))
                .fontWeight(.bold)
                .fontDesign(.rounded)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(uiColor: .secondarySystemBackground))
        .cornerRadius(12)
    }
}
