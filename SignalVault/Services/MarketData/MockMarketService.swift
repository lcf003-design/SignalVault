import Foundation

final class MockMarketService: MarketDataProvider {
    private let volatility: Double
    
    init(volatility: Double = 1.0) {
        self.volatility = volatility
    }
    
    func connect() async throws {
        // Mock connection delay
        try await Task.sleep(for: .seconds(0.5))
    }
    
    func streamQuotes(for symbols: [String]) async -> AsyncStream<MarketTick> {
        AsyncStream { continuation in
            let task = Task {
                var tickCount = 0
                var currentPrice = 100.0
                
                while !Task.isCancelled {
                    // Generate a volatile sine wave + noise
                    let sineWave = sin(Double(tickCount) * 0.1) * 5.0 * volatility
                    let noise = Double.random(in: -2.0...2.0) * volatility
                    currentPrice = 100.0 + sineWave + noise
                    
                    let tick = MarketTick(
                        symbol: symbols.first ?? "BTC",
                        price: currentPrice,
                        timestamp: Date()
                    )
                    
                    continuation.yield(tick)
                    
                    // Simulate high-frequency data (100ms)
                    try? await Task.sleep(for: .milliseconds(100))
                    tickCount += 1
                }
            }
            
            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }
    func fetchOptionChain(for symbol: String) async throws -> [OptionContract] {
        // Mock Chain
        let strikes = [94000.0, 95000.0, 96000.0, 97000.0, 98000.0]
        var chain: [OptionContract] = []
        let expiry = Date().addingTimeInterval(30 * 24 * 3600) // +30 days
        
        for k in strikes {
            chain.append(OptionContract(symbol: "\(symbol)260205C\(Int(k))", strikePrice: k, expirationDate: expiry, type: .call, impliedVolatility: 0.65))
            chain.append(OptionContract(symbol: "\(symbol)260205P\(Int(k))", strikePrice: k, expirationDate: expiry, type: .put, impliedVolatility: 0.65))
        }
        return chain
    }
}
