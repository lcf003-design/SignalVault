import SwiftUI
import SwiftData
import Combine

struct AllocationSegment: Identifiable {
    let id = UUID()
    let sector: String
    let value: Double
    let color: Color
}

@MainActor
class PortfolioViewModel: ObservableObject {
    @Published var totalEquity: Double = 0.0
    @Published var totalPnL: Double = 0.0
    @Published var riskScore: Int = 0 // 0-100
    @Published var allocationData: [AllocationSegment] = []
    
    // Mission 37: Wealth Command Center Data
    @Published var aiDailyPL: Double = 0.0 // "AI Alpha"
    @Published var dailyAlpha: Double = 0.0 // User vs AI Difference
    @Published var scannerSignals: [ScannedAsset] = [] // Alpha Ticker items
    @Published var disciplineRating: Int = 100 // Discipline Audit
    @Published var portfolioNews: [NewsItem] = [] // Portfolio-specific news
    
    // Dependencies
    private var modelContext: ModelContext?
    private var marketService: MarketDataProvider? // Mission 41
    private let sentimentService = SentimentService()
    
    // Live Data
    private var livePrices: [String: Double] = [:]
    private var quoteTask: Task<Void, Never>?
    // MarketScannerService is an actor, we'll access it via a task
    
    init() {}
    
    func setContext(_ context: ModelContext) {
        self.modelContext = context
        calculateMetrics()
    }
    
    // Mission 41: Inject Market Service and Start Monitoring
    func configure(marketService: MarketDataProvider) {
        self.marketService = marketService
        monitorPortfolio()
    }
    
    func calculateMetrics() {
        guard let context = modelContext else { return }
        
        let accountDescriptor = FetchDescriptor<Account>()
        // Filter for OPEN positions only
        let positionDescriptor = FetchDescriptor<Position>(predicate: #Predicate { $0.isOpen })
        
        do {
            let accounts = try context.fetch(accountDescriptor)
            let positions = try context.fetch(positionDescriptor)
            
            guard let account = accounts.first else { return }
            
            // 1. Calculate Totals
            let cash = account.currentBalance
            // Use entryPrice as reliable cost basis.
            // Note: Without live market connection here, we cannot calculate real-time Equity or Unrealized P&L.
            // Future Upgrade: Inject MarketService to fetch current quotes for held assets.
            let invested = positions.reduce(0.0) { $0 + ($1.quantity * $1.entryPrice) }
            
            let totalValue = cash + invested
            
            self.totalEquity = totalValue
            self.totalPnL = self.calculateLivePnL(positions: positions) // Mission 41
            
            // 2. Allocation Logic
            var segments: [AllocationSegment] = []
            
            if cash > 0 {
                segments.append(AllocationSegment(sector: "Cash", value: cash, color: .green))
            }
            
            // Use AssetType if available, or fallback to Symbol check
            // SchemaV1.Position has 'assetType: AssetType'
            
            let cryptoValue = positions.filter { $0.assetType == .crypto }.reduce(0.0) { $0 + ($1.quantity * $1.entryPrice) }
            let stockValue = positions.filter { $0.assetType == .stock }.reduce(0.0) { $0 + ($1.quantity * $1.entryPrice) }
            let optionValue = positions.filter { $0.assetType == .option }.reduce(0.0) { $0 + ($1.quantity * $1.entryPrice) }
            
            if cryptoValue > 0 {
                segments.append(AllocationSegment(sector: "Crypto", value: cryptoValue, color: .orange))
            }
            
            if stockValue > 0 {
                segments.append(AllocationSegment(sector: "Equities", value: stockValue, color: .blue))
            }
             
            if optionValue > 0 {
                segments.append(AllocationSegment(sector: "Options", value: optionValue, color: .purple))
            }
            
            self.allocationData = segments
            
            // 3. Risk Score Logic (VaR Proxy)
            // 100% Cash = 0 Risk
            // 100% Crypto = 100 Risk
            // Mixed = Weighted Average
            
            if totalValue == 0 {
                self.riskScore = 0
            } else {
                let cashWeight = cash / totalValue
                let cryptoWeight = cryptoValue / totalValue
                let stockWeight = stockValue / totalValue
                let optionWeight = optionValue / totalValue
                
                // Weights: Cash(0), Equity(40), Crypto(90), Options(100)
                let score = (cashWeight * 0) + (stockWeight * 40) + (cryptoWeight * 90) + (optionWeight * 100)
                self.riskScore = Int(score)
            }
            
        } catch {
            print("Failed to fetch data for Portfolio: \(error)")
        }
    }
    
    // Mission 37: Fetch External Data (Scanner & News)
    func refreshViewData() async {
        // 1. Update basic metrics
        calculateMetrics()
        
        // 2. Fetch Scanner Signals (Using Mock for UI demo)
        // In real app, this would query the central MarketScannerService actor
        self.scannerSignals = [
            ScannedAsset(symbol: "NVDA", name: "NVIDIA", price: 485.20, changePercent: 2.5, kaiScore: 92, volumeStatus: .ultra, aiSummary: "Breakout", assetType: .stock, convictionScore: 0.92, signalType: .strongBuy(confidence: 0.92, price: 485.20), isGlowing: true),
            ScannedAsset(symbol: "BTC", name: "Bitcoin", price: 44200, changePercent: 1.2, kaiScore: 88, volumeStatus: .high, aiSummary: "Momentum", assetType: .crypto, convictionScore: 0.88, signalType: .strongBuy(confidence: 0.88, price: 44200), isGlowing: false),
            ScannedAsset(symbol: "AMD", name: "AMD", price: 145.00, changePercent: -0.5, kaiScore: 45, volumeStatus: .normal, aiSummary: "Weak", assetType: .stock, convictionScore: 0.45, signalType: .neutral(confidence: 0.0), isGlowing: false),
            ScannedAsset(symbol: "TSLA", name: "Tesla", price: 240.10, changePercent: 0.8, kaiScore: 78, volumeStatus: .normal, aiSummary: "Recovery", assetType: .stock, convictionScore: 0.78, signalType: .strongBuy(confidence: 0.78, price: 240.10), isGlowing: false),
            ScannedAsset(symbol: "AAPL", name: "Apple", price: 185.50, changePercent: 0.1, kaiScore: 60, volumeStatus: .low, aiSummary: "DoJi", assetType: .stock, convictionScore: 0.60, signalType: .neutral(confidence: 0.0), isGlowing: false)
        ]
        
        // 3. Simulate AI Alpha Comparison
        // Mocking a scenario where AI is outperforming slightly
        let projectedAIGains = self.totalEquity * 0.012 // +1.2%
        self.aiDailyPL = projectedAIGains
        self.dailyAlpha = self.totalPnL - self.aiDailyPL
        
        // Discipline Audit: Decrease score for manual overrides (Simulated)
        // In valid app: count distinct 'Positions' where manualOverride == true
        let overrides = 2 // Mock
        self.disciplineRating = max(0, 100 - (overrides * 5))
        
        // 4. Fetch Portfolio News
        // Get symbols from context
        if let context = modelContext {
            let descriptor = FetchDescriptor<Position>(predicate: #Predicate { $0.isOpen })
            if let positions = try? context.fetch(descriptor) {
                let symbols = positions.map { $0.symbol }
                if !symbols.isEmpty {
                     // Fetch specific news for the top 3 holdings
                     var combinedNews: [NewsItem] = []
                     for symbol in symbols.prefix(3) {
                         let news = await sentimentService.fetchSentiment(for: symbol)
                         combinedNews.append(contentsOf: news.headlines)
                     }
                     self.portfolioNews = combinedNews.sorted { $0.sentimentScore < $1.sentimentScore } // Show risks first
                } else {
                    self.portfolioNews = []
                }
            }
        }
    }
    
    // Mission 41: Live Portfolio Monitoring
    private func monitorPortfolio() {
        // Cancel existing task to prevent duplicates
        quoteTask?.cancel()
        
        // Get symbols from context
        guard let context = modelContext else { return }
        
        let descriptor = FetchDescriptor<Position>(predicate: #Predicate { $0.isOpen })
        guard let positions = try? context.fetch(descriptor) else { return }
        let symbols = Array(Set(positions.map { $0.symbol })) // Unique symbols
        
        guard !symbols.isEmpty, let service = marketService else { return }
        
        quoteTask = Task {
            do {
                // Ensure connection
                try? await service.connect()
                let stream = await service.streamQuotes(for: symbols)
                
                for await tick in stream {
                    // Update Cache
                    self.livePrices[tick.symbol] = tick.price
                    
                    // Recalculate Metrics Reactively
                    self.recalculateLiveEquity(positions: positions)
                }
            } catch {
                print("Portfolio Stream Error: \(error)")
            }
        }
    }
    
    private func recalculateLiveEquity(positions: [Position]) {
         guard let context = modelContext else { return }
         // We need Account Balance (Cash)
         let accountDescriptor = FetchDescriptor<Account>()
         guard let account = try? context.fetch(accountDescriptor).first else { return }
         
         let cash = account.currentBalance
         
         // Calculate Holdings Value using Live Prices where available
         var holdingsValue: Double = 0.0
         var totalOpenPnL: Double = 0.0
         
         for pos in positions {
             let currentPrice = livePrices[pos.symbol] ?? pos.entryPrice // Fallback to entry if no live data
             let val = pos.quantity * currentPrice
             holdingsValue += val
             
             // P&L
             let pnl = (currentPrice - pos.entryPrice) * pos.quantity
             totalOpenPnL += pnl
         }
         
         self.totalEquity = cash + holdingsValue
         self.totalPnL = totalOpenPnL
    }
    
    // Helper for initial calculation
    private func calculateLivePnL(positions: [Position]) -> Double {
        var totalOpenPnL: Double = 0.0
        for pos in positions {
            let currentPrice = livePrices[pos.symbol] ?? pos.entryPrice
            totalOpenPnL += (currentPrice - pos.entryPrice) * pos.quantity
        }
        return totalOpenPnL
    }
}
