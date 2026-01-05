import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    
    // Services injected from App
    let marketService: MarketDataProvider
    let riskMonitor: RiskMonitorActor? // Kept for reference if needed
    
    // ViewModels
    @State private var chartViewModel: MarketChartViewModel
    
    init(marketService: MarketDataProvider = MockMarketService(), riskMonitor: RiskMonitorActor? = nil) {
        self.marketService = marketService
        self.riskMonitor = riskMonitor
        // Initialize VM with shared service
        _chartViewModel = State(initialValue: MarketChartViewModel(marketService: marketService))
    }
    
    @Query private var accounts: [Account]
    
    // Legal Compliance
    @AppStorage("hasAcceptedDisclaimer") private var hasAcceptedDisclaimer = false
    
    var body: some View {
        TabView {
            // Tab 1: Command Center
            NavigationStack {
                VStack(spacing: 0) {
                    // 1. Header & Net Worth
                    VStack(spacing: 8) {
                        Text("FAKE NET WORTH")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .tracking(2)
                        
                        if let account = accounts.first {
                            Text(account.currentBalance, format: .currency(code: "USD"))
                                .font(.system(size: 36, weight: .bold, design: .rounded))
                                .foregroundStyle(Color.green)
                                .contentTransition(.numericText())
                        } else {
                            Text("$0.00")
                                .onAppear {
                                    BankManager.shared.ensureAccountExists(modelContext: modelContext)
                                }
                        }
                    }
                    .padding(.top)
                    
                    // 2. Chart
                    MarketChartView(viewModel: chartViewModel)
                        .frame(maxHeight: 300)
                        .padding(.vertical)
                    
                    // 3. Positions
                    LivePositionsCard(currentPrice: chartViewModel.currentPrice)
                    
                    Spacer()
                    
                    // 4. Console
                    TradeConsoleView(
                        currentPrice: chartViewModel.currentPrice,
                        activeSignal: chartViewModel.activeSignal
                    )
                }
                .navigationTitle("Command Center")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                         Button(action: {
                             chartViewModel.toggleSimulation()
                         }) {
                             Image(systemName: chartViewModel.isRunning ? "pause.fill" : "play.fill")
                                 .foregroundStyle(chartViewModel.isRunning ? .red : .orange)
                         }
                    }
                }
            }
            .tabItem {
                Label("Trade", systemImage: "chart.bar.xaxis")
            }
            
            // Tab 2: Performance (The Mirror)
            NavigationStack {
                PerformanceDashboard()
            }
            .tabItem {
                Label("Performance", systemImage: "timer")
            }
        }
        .fullScreenCover(isPresented: Binding(
            get: { !hasAcceptedDisclaimer },
            set: { _ in }
        )) {
            DisclaimerView(hasAccepted: $hasAcceptedDisclaimer)
        }
    }
}

#Preview {
    ContentView(marketService: MockMarketService())
        .modelContainer(for: [Account.self, Position.self], inMemory: true)
}
