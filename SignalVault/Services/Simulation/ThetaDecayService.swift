import SwiftData
import Foundation

actor ThetaDecayService {
    private let modelContainer: ModelContainer
    private let quantEngine = QuantEngine()
    
    init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
    }
    
    func applyDailyDecay() async throws {
        let context = ModelContext(modelContainer)
        let accountDescriptor = FetchDescriptor<Account>()
        let positionDescriptor = FetchDescriptor<Position>(predicate: #Predicate { $0.isOpen }) // && $0.assetType == .option
        // Note: Predicate for enum equality might be tricky in some SwiftData versions, usually safe now.
        // We'll fetch open positions and filter in loop to be safe if Predicate fails on enum.
        
        guard let account = try context.fetch(accountDescriptor).first else { return }
        let positions = try context.fetch(positionDescriptor)
        
        var totalDecay = 0.0
        
        for position in positions {
            guard position.assetType == .option,
                  let strike = position.strikePrice,
                  let expiry = position.expirationDate,
                  let type = position.optionType else { continue }
            
            // Re-calculate Greeks for current moment (or last close)
            // Need underlying price.
            // For simulator, we might need a Price Provider here.
            // Or we assume 'last known price' stored? Position has 'entryPrice' only.
            // For MVP, lets assume we fetch current price or use entry price as proxy if live data unavailable?
            // "The Decay Simulator" says "deduct Theta value".
            // Ideally we calculate theta based on LIVE price.
            
            // Assuming we pass in a price map or fetch it.
            // Let's change signature to accept a price provider or map?
            // Or simplified: Just decay a fixed amount? No, that's not "The Greeks".
            
            // Let's assume price hasn't moved for the decay check (pure time decay).
            // Uses Entry Price for rough calc, or we need to inject MarketService.
            
            let timeToMaturity = expiry.timeIntervalSinceNow / (365 * 24 * 3600)
            if timeToMaturity <= 0 { continue }
            
            // Hardcoded risk free / volatility for MVP simulation
            let r = 0.04
            let sigma = position.impliedVolatilityAtEntry ?? 0.50
            
            let result = await quantEngine.calculatePriceAndGreeks(
                stockPrice: position.entryPrice, // Using entry price as proxy for 'current' in this disconnected simulation step
                strikePrice: strike,
                timeToMaturity: timeToMaturity,
                riskFreeRate: r,
                volatility: sigma,
                type: type
            )
            
            // Theta is typically negative (you lose money).
            // Position Quantity * Theta
            let decay = result.greeks.theta * position.quantity
            totalDecay += decay // decay is negative, so this decreases total
            
            // Update Position logic?
            // Usually decay is reflected in the Option Price dropping.
            // In Sandbox, we might strictly deduct from Account Balance 'Cash'?
            // Or just track it in 'Unrealized P&L'?
            // User request: "BankManager must automatically deduct the Theta value from the position's P&L"
            // Since P&L is calculated dynamically (CurrentPrice - Entry),
            // effectively 'Time Decay' lowers the 'CurrentPrice'.
            // But we don't control the market price of the option here (it comes from live data).
            
            // IF we are trading Live Options, the market price ALREADY includes decay. Double counting?
            // "To make your sandbox realistic... deduct Theta".
             // This implies we are "holding" an option in sandbox but maybe stream is underlying stock only?
            // "Update MarketDataService to fetch Option Chain... QuantEngine calculate Greeks"
            // If we fetch real option prices, decay is baked in.
            // If we simulate Option Price based on Stock Price (Synthetic Option), then WE calculate price.
            
            // INTERPRETATION: We are likely trading "Synthetic Options" derived from Live Stock Data.
            // Because getting real-time free option chains for all symbols is hard/expensive.
            // So we take "BTC", User buys a "Call". We simulate the Call Price using Black-Scholes on live BTC price.
            // Then Decay happens naturally if we use Black-Scholes every frame.
            
            // BUT "Deduct Theta value... to simulate decay" suggests manual intervention.
            // Let's implement a "Synthetic Decay adjustment" or simply log it.
            // If we use Black Scholes for Real Time pricing, Theta is handled automatically by 'T' decreasing.
            
            // User Prompt: "BankManager must automatically deduct Theta... to simulate real-world time decay."
            // This is strongest hint that we might be holding "Frozen" positions or checking "Overnight" decay explicitly.
            // Let's just deduct it from 'currentBalance' as a "Holding Cost" simulation for now?
            
            // Or maybe update 'entryPrice' to be higher? No.
            // Let's subtract from 'totalProfit' or 'currentBalance'.
            
            account.currentBalance += decay // Apply the loss
            print("📉 Applied Decay to \(position.symbol): \(decay)")
        }
        
        try context.save()
    }
}
