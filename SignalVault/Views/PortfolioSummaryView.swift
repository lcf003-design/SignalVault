import SwiftUI
import Charts
import SwiftData

struct PortfolioSummaryView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var viewModel = PortfolioViewModel()
    @Binding var selectedTab: Int // To navigate to Trade tab
    var marketService: MarketDataProvider // Mission 41
    
    
    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    
                    // 1. Hero Header (Mesh Gradient)
                    ZStack {
                        // Mesh Gradient Simulation
                        LinearGradient(colors: [.indigo, .purple, .blue], startPoint: .topLeading, endPoint: .bottomTrailing)
                            .mask(RoundedRectangle(cornerRadius: 24))
                            .overlay(
                                Circle()
                                    .fill(.blue.opacity(0.4))
                                    .frame(width: 200)
                                    .blur(radius: 50)
                                    .offset(x: -50, y: -50)
                            )
                            .overlay(
                                Circle()
                                    .fill(.purple.opacity(0.4))
                                    .frame(width: 200)
                                    .blur(radius: 50)
                                    .offset(x: 50, y: 50)
                            )
                        
                        VStack(spacing: 4) {
                            Text("TOTAL EQUITY")
                                .font(.caption2)
                                .fontWeight(.bold)
                                .foregroundStyle(.white.opacity(0.7))
                                .tracking(2)
                            
                            Text(viewModel.totalEquity, format: .currency(code: "USD"))
                                .font(.system(size: 40, weight: .heavy, design: .rounded))
                                .foregroundStyle(.white)
                                .contentTransition(.numericText()) // Mission 41: Smooth Ticking
                                .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
                        }
                        .padding(.vertical, 40)
                    }
                    .frame(height: 180)
                    .padding(.horizontal)
                    
                    // 2. Alpha Comparison Card
                    AlphaMetricCard(userPL: viewModel.totalPnL, aiPL: viewModel.aiDailyPL)
                        .padding(.horizontal)
                        
                    // 3. Alpha Ticker
                    AlphaTickerView(signals: viewModel.scannerSignals)
                    
                    // 4. Risk & Discipline Hub
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Risk & Discipline")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        HStack(spacing: 16) {
                            // Risk Meter
                            VStack(alignment: .leading) {
                                Text("VaR Score")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text("\(viewModel.riskScore)/100")
                                    .font(.title2.bold())
                                    .foregroundStyle(riskColor)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding()
                            .background(Color(uiColor: .secondarySystemBackground))
                            .cornerRadius(16)
                            
                            // Discipline Meter
                            VStack(alignment: .leading) {
                                Text("Discipline")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text("\(viewModel.disciplineRating)%")
                                    .font(.title2.bold())
                                    .foregroundStyle(viewModel.disciplineRating > 90 ? .green : .orange)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding()
                            .background(Color(uiColor: .secondarySystemBackground))
                            .cornerRadius(16)
                        }
                        .padding(.horizontal)
                    }
                    
                    // 5. Allocation (Donut Chart)
                    if !viewModel.allocationData.isEmpty {
                        VStack(alignment: .leading) {
                            Text("Allocation")
                                .font(.headline)
                                .padding(.horizontal)
                            
                            Chart(viewModel.allocationData) { segment in
                                SectorMark(
                                    angle: .value("Value", segment.value),
                                    innerRadius: .ratio(0.6),
                                    angularInset: 1.5
                                )
                                .cornerRadius(5)
                                .foregroundStyle(segment.color)
                            }
                            .frame(height: 200)
                            .padding()
                        }
                    }
                    
                    // 6. Portfolio News Pulse
                    if !viewModel.portfolioNews.isEmpty {
                        VStack(alignment: .leading) {
                            Text("Portfolio Pulse")
                                .font(.headline)
                                .padding(.horizontal)
                            
                            ForEach(viewModel.portfolioNews.prefix(3)) { news in
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text(news.source)
                                            .font(.caption2.bold())
                                            .foregroundStyle(.secondary)
                                        Text(news.headline)
                                            .font(.caption)
                                            .fontWeight(.medium)
                                            .lineLimit(2)
                                    }
                                    Spacer()
                                    Text(news.sentimentScore > 0 ? "BULL" : "BEAR")
                                        .font(.caption2.bold())
                                        .padding(4)
                                        .background(news.sentimentScore > 0 ? Color.green.opacity(0.1) : Color.red.opacity(0.1))
                                        .foregroundStyle(news.sentimentScore > 0 ? .green : .red)
                                        .cornerRadius(4)
                                }
                                .padding()
                                .background(Color(uiColor: .secondarySystemBackground))
                                .cornerRadius(12)
                                .padding(.horizontal)
                            }
                        }
                    }

                    Spacer(minLength: 50)
                }
                .navigationTitle("Command Center")
                .navigationBarHidden(true)
            }
            .task {
                viewModel.setContext(modelContext)
                viewModel.configure(marketService: marketService) // Mission 41
                await viewModel.refreshViewData()
            }
        }
    }
    
    var riskColor: Color {
        if viewModel.riskScore < 30 { return .green }
        else if viewModel.riskScore < 70 { return .yellow }
        else { return .red }
    }

    var riskDescription: String {
        if viewModel.riskScore < 30 { return "Conservative Allocation. Mostly Cash or Blue Chips." }
        else if viewModel.riskScore < 70 { return "Balanced Portfolio. Healthy Mix." }
        else { return "High Volatility detected. Significant Crypto exposure." }
    }
}



// MARK: - Mission 37: Alpha Components

struct AlphaMetricCard: View {
    let userPL: Double
    let aiPL: Double
    
    var alpha: Double { userPL - aiPL }
    
    var body: some View {
        HStack(spacing: 0) {
            // User Side
            VStack(alignment: .leading) {
                Text("USER P&L")
                    .font(.caption2.bold())
                    .foregroundStyle(.secondary)
                Text(userPL, format: .currency(code: "USD"))
                    .font(.title3.bold())
                    .foregroundStyle(userPL >= 0 ? .green : .red)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            
            Divider()
                .frame(height: 40)
            
            // AI Side
            VStack(alignment: .leading) {
                Text("AI ALPHA")
                    .font(.caption2.bold())
                    .foregroundStyle(.purple)
                Text(aiPL, format: .currency(code: "USD"))
                    .font(.title3.bold())
                    .foregroundStyle(.purple)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
        }
        .background(Color(uiColor: .tertiarySystemBackground))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(alpha >= 0 ? Color.green.opacity(0.3) : Color.purple.opacity(0.3), lineWidth: 1)
        )
        // Alpha Badge
        .overlay(
            Text(alpha >= 0 ? "BEATING AI" : "LAGGING AI")
                .font(.system(size: 8, weight: .black))
                .padding(4)
                .background(alpha >= 0 ? Color.green : Color.purple)
                .foregroundStyle(.white)
                .cornerRadius(4)
                .offset(y: -10),
            alignment: .top
        )
    }
}

struct AlphaTickerView: View {
    let signals: [ScannedAsset]
    
    var body: some View {
        VStack(alignment: .leading) {
            Text("Scanner Alpha")
                .font(.headline)
                .padding(.horizontal)
            
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 12) {
                    ForEach(signals) { signal in
                        AlphaTickerCell(signal: signal)
                    }
                }
                .padding(.horizontal)
            }
        }
    }
}

struct AlphaTickerCell: View {
    let signal: ScannedAsset
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(signal.symbol)
                    .font(.caption.bold())
                
                Spacer()
                
                Text("\(signal.kaiScore)")
                    .font(.caption2.bold())
                    .padding(2)
                    .background(.white.opacity(0.2))
                    .cornerRadius(4)
            }
            
            Text(signalTypeString(signal.signalType))
                .font(.system(size: 8, weight: .bold))
                .foregroundStyle(signalColor(signal.signalType) == .gray ? .white : .black) // Contrast
                .padding(2)
                .background(signalColor(signal.signalType))
                .cornerRadius(2)
            
            Text(signal.aiSummary)
                .font(.system(size: 8))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .padding(8)
        .frame(width: 120, height: 70)
        .background(Color(uiColor: .secondarySystemBackground))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(signal.isGlowing ? Color.purple : Color.clear, lineWidth: 1)
        )
    }
    
    private func signalTypeString(_ signal: TradeSignal) -> String {
        switch signal {
        case .strongBuy: return "STRONG BUY"
        case .strongSell: return "STRONG SELL"
        case .neutral: return "NEUTRAL"
        }
    }
    
    private func signalColor(_ signal: TradeSignal) -> Color {
        switch signal {
        case .strongBuy: return .green
        case .strongSell: return .red
        case .neutral: return .gray
        }
    }
}
