import Foundation
import SwiftData

actor RiskMonitorActor {
    private let marketService: MarketDataProvider
    private let modelContainer: ModelContainer
    private var isMonitoring = false
    
    init(marketService: MarketDataProvider, modelContainer: ModelContainer) {
        self.marketService = marketService
        self.modelContainer = modelContainer
    }
    
    func startMonitoring() {
        guard !isMonitoring else { return }
        isMonitoring = true
        
        Task {
            print("🛡️ Risk Monitor: Activated")
            
            // FIXME: Dynamic subscription to all holdings.
            let symbols = ["BTC", "BTC-USD", "ETH-USD"]
            
            // Calling synchronous protocol method.
            // If LiveMarketService is MainActor isolated, this will fail.
            // Assumption: MarketDataProvider is Sendable and streamQuotes is thread-safe/nonisolated.
            let stream = await marketService.streamQuotes(for: symbols)
            
            for await tick in stream {
                if !isMonitoring { break }
                await checkRisk(tick: tick)
            }
            print("🛡️ Risk Monitor: Stopped")
        }
    }
    
    func stopMonitoring() {
        isMonitoring = false
    }
    
    private func checkRisk(tick: MarketTick) async {
        // Create an executor with the shared container (Actor handles its own context)
        let executor = TradeExecutor(modelContainer: modelContainer)
        let context = ModelContext(modelContainer)
        
        // Extract symbol for Predicate to avoid capture issues
        let tickSymbol = tick.symbol
        
        // Fetch open positions for this symbol
        let descriptor = FetchDescriptor<Position>(
            predicate: #Predicate { $0.isOpen && $0.symbol == tickSymbol }
        )
        
        do {
            let positions = try context.fetch(descriptor)
            
            for position in positions {
                // Check Take Profit
                if let tp = position.takeProfitPrice {
                    if (position.isLong && tick.price >= tp) || (!position.isLong && tick.price <= tp) {
                        // TRIGGER TP
                        try await executor.closePosition(positionID: position.id, price: tick.price, reason: "Take Profit")
                        continue // Position closed
                    }
                }
                
                // Check Stop Loss
                if let sl = position.stopLossPrice {
                    if (position.isLong && tick.price <= sl) || (!position.isLong && tick.price >= sl) {
                        // TRIGGER SL
                        try await executor.closePosition(positionID: position.id, price: tick.price, reason: "Stop Loss")
                        continue
                    }
                }
            }
        } catch {
            print("🛡️ Risk Monitor Error: \(error)")
        }
    }
}
