import SwiftUI
import SwiftData
import Combine

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
    
    // Legal Compliance (Mission 16)
    @AppStorage("hasAcceptedRisk") private var hasAcceptedRisk = false
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false // Mission 17
    
    @AppStorage("isRealisticSlippageEnabled") private var isRealisticSlippageEnabled = false
    
    @State private var showDisclaimer = false
    @State private var showOnboarding = false
    @State private var showBacktest = false
    
    @State private var showDepositSheet = false
    
    // Mission 16: Macro State
    @State private var macroData: MacroData?
    @State private var currentRegime: MarketRegime = .neutral
    private let macroService = MacroService()
    
    // Mission 19: Navigation State
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // Tab 1: Home (Mission 24)
            PortfolioSummaryView(selectedTab: $selectedTab, marketService: marketService)
                .tabItem {
                    Label("Home", systemImage: "house.fill")
                }
                .tag(0)
            
            // Tab 2: Command Center
            NavigationStack {
                VStack(spacing: 0) {
                    // Mission 16: Macro Status Bar
                    if let data = macroData {
                        MacroStatusBar(macroData: data, regime: currentRegime, events: chartViewModel.economicEvents)
                            .transition(.move(edge: .top))
                    }
                    
                    // 1. Header & Net Worth
                    VStack(spacing: 8) {
                        HStack {
                            Spacer()
                            Text("FAKE NET WORTH")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .tracking(2)
                            
                            // Mission 18: Deposit Button
                            Button(action: { showDepositSheet.toggle() }) {
                                Image(systemName: "plus.circle.fill")
                                    .foregroundStyle(.blue)
                                    .font(.system(size: 20))
                            }
                            Spacer()
                        }
                        
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
                        activeSignal: chartViewModel.activeSignal,
                        selectedSymbol: chartViewModel.selectedSymbol,
                        vwap: chartViewModel.vwap,
                        vwapDistance: chartViewModel.vwapDistance,
                        isConsolidating: chartViewModel.isConsolidating
                    )
                }
                .navigationTitle("Command Center")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    // Mission 11: Asset & Simulation Menu
                    ToolbarItem(placement: .topBarLeading) {
                        Menu {
                            Section("Asset") {
                                Button("Bitcoin (BTC)") { chartViewModel.changeSymbol(to: "BTC") }
                                Button("Ethereum (ETH)") { chartViewModel.changeSymbol(to: "ETH") }
                                Button("Solana (SOL)") { chartViewModel.changeSymbol(to: "SOL") }
                                Button("S&P 500 (SPY)") { chartViewModel.changeSymbol(to: "SPY") }
                            }
                            
                            // Mission 20: Moved Simulation & Feedback to Settings Tab
                        } label: {
                            HStack(spacing: 4) {
                                Text(chartViewModel.selectedSymbol)
                                    .font(.headline)
                                Image(systemName: "chevron.down.circle.fill")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .foregroundStyle(.primary)
                        }
                    }
                    
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
            .sheet(isPresented: $showBacktest) {
                BacktestConsoleView(symbol: chartViewModel.selectedSymbol)
            }
            .sheet(isPresented: $showDepositSheet) {
                DepositSheet()
            }
            // Initiation Logic
            .onAppear {
                // 1. Compliance Gate
                if !hasAcceptedRisk {
                    showDisclaimer = true
                } else if !hasCompletedOnboarding {
                    // 2. Onboarding Gate (only if disclaimer signed)
                    showOnboarding = true
                }
                
                // 3. Kickstart Services
                Task {
                    let data = await macroService.fetchMacroData()
                    let regime = await macroService.determineRegime(data: data)
                    withAnimation {
                        self.macroData = data
                        self.currentRegime = regime
                    }
                    await chartViewModel.updateRegime(regime)
                    await chartViewModel.fetchEconomicEvents()
                }
            }
            .onChange(of: hasAcceptedRisk) { oldValue, newValue in
                if newValue && !hasCompletedOnboarding {
                    showOnboarding = true
                }
            }
            
            .tag(1) // Trade Tab
            
            // Tab 3: Markets (Mission 19)
            MarketsListView(selectedTab: $selectedTab, selectedSymbol: $chartViewModel.selectedSymbol)
                .tabItem {
                    Label("Markets", systemImage: "square.grid.2x2")
                }
                .tag(2)
            
            // Tab 4: Performance (The Mirror)
            NavigationStack {
                PerformanceDashboard()
            }
            .tabItem {
                Label("Performance", systemImage: "timer")
            }
            .tag(3)
            
            // Tab 5: Settings (Mission 20)
            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape.fill")
                }
                .tag(4)
        }
        .fullScreenCover(isPresented: $showDisclaimer) {
            DisclaimerView(isPresented: $showDisclaimer)
        }
        .fullScreenCover(isPresented: $showOnboarding) {
            OnboardingView(isPresented: Binding(
                get: { showOnboarding },
                set: { newValue in
                    if !newValue { hasCompletedOnboarding = true }
                    showOnboarding = newValue
                }
            ))
        }
    }
}

// Mission 16: UI Component (Moved here for build safety)


// Mission 16 & 32: UI Component
struct MacroStatusBar: View {
    let macroData: MacroData
    let regime: MarketRegime
    // Mission 32: Next Event Countdown
    var events: [EconomicEvent] = []
    
    @State private var timeRemaining: String = ""
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    var body: some View {
        HStack {
            // Regime Badge
            HStack(spacing: 6) {
                Circle()
                    .fill(regimeColor)
                    .frame(width: 8, height: 8)
                Text(regime.rawValue)
                    .font(.caption.bold())
                    .foregroundStyle(regimeColor)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(regimeColor.opacity(0.1))
            .cornerRadius(8)
            
            Spacer()
            
            // Mission 32: Next Event Countdown
            if let nextEvent = getNextEvent() {
                 HStack(spacing: 4) {
                     Image(systemName: "timer")
                         .foregroundStyle(.orange)
                     Text(nextEvent.title)
                         .fontWeight(.semibold)
                     Text(timeRemaining)
                         .monospacedDigit()
                 }
                 .font(.caption)
                 .foregroundStyle(.primary)
                 .onReceive(timer) { _ in
                     updateCountdown(to: nextEvent.date)
                 }
            } else if macroData.isYieldCurveInverted {
                // Fallback to Yield Curve Warning if no imminent event
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill")
                    Text("Inverted Yield Curve")
                }
                .font(.caption)
                .foregroundStyle(.orange)
            }
            
            Spacer()
            
            // Fed Meeting
            HStack(spacing: 4) {
                Image(systemName: "calendar")
                Text("FOMC: \(macroData.nextFedMeeting, format: .dateTime.month().day())")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Material.regular)
    }
    
    var regimeColor: Color {
        switch regime {
        case .riskOn: return .green
        case .riskOff: return .red
        case .neutral: return .secondary
        }
    }
    
    func getNextEvent() -> EconomicEvent? {
        let now = Date()
        // Find first future event
        return events.sorted(by: { $0.date < $1.date })
            .first(where: { $0.date > now })
    }
    
    func updateCountdown(to date: Date) {
        let diff = date.timeIntervalSince(Date())
        if diff > 0 {
            let formatter = DateComponentsFormatter()
            formatter.allowedUnits = [.hour, .minute, .second]
            formatter.unitsStyle = .positional
            timeRemaining = formatter.string(from: diff) ?? "00:00"
        } else {
            timeRemaining = "NOW"
        }
    }
}

#Preview {
    ContentView(marketService: MockMarketService())
        .modelContainer(for: [Account.self, Position.self], inMemory: true)
}
