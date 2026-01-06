import Foundation

@MainActor
class SignalTestHarness {
    private let marketService: MarketDataProvider
    private let engine: SignalEngine
    
    init() {
        self.marketService = MockMarketService(volatility: 2.0) // High volatility
        self.engine = SignalEngine()
    }
    
    func start() {
        Task {
            print("🔬 Starting Harness...")
            try? await marketService.connect()
            
            let stream = await marketService.streamQuotes(for: ["BTC"])
            
            for await tick in stream {
                let context = await engine.process(tick: tick)
                
                if let signal = context.tradeSignal {
                    print("--------------------------------------------------")
                    print("🔭 SNIPER SCOPE ALIGNMENT: \(context.alignment.rawValue.uppercased())")
                    if context.isDivergenceDetected {
                         print("⚠️ DIVERGENCE DETECTED ⚠️")
                    }
                    
                    switch signal {
                    case .strongBuy(let confidence, let price):
                        print("🚨 SIGNAL ENTRY: STRONG BUY @ \(price.formatted(.currency(code: "USD"))) (Score: \(confidence))")
                    case .strongSell(let confidence, let price):
                        print("🚨 SIGNAL ENTRY: STRONG SELL @ \(price.formatted(.currency(code: "USD"))) (Score: \(confidence))")
                    case .neutral:
                        print("⚖️ NEUTRAL")
                    }
                    print("--------------------------------------------------")
                } else {
                    // Heartbeat every 10 ticks so user knows it's alive
                    if Int(tick.timestamp.timeIntervalSince1970 * 10) % 10 == 0 {
                        print("⏳ Buffering/Analyzing... Price: \(tick.price.formatted(.currency(code: "USD"))) | Alignment: \(context.alignment)")
                    }
                }
            }
        }
    }
}
