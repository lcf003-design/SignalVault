import Foundation

class LiveMarketService: MarketDataProvider {
    private let actor = PolygonSocketActor.shared
    private let apiKey: String
    
    init(apiKey: String = Secrets.polygonAPIKey) {
        self.apiKey = apiKey
    }
    
    func connect() async throws {
        await actor.connect()
    }
    
    func streamQuotes(for symbols: [String]) async -> AsyncStream<MarketTick> {
        let (stream, continuation) = AsyncStream<MarketTick>.makeStream()
        
        Task {
            await actor.registerContinuation(continuation)
            
            // Wait for connection to stabilize then auth/sub
            try? await Task.sleep(for: .seconds(1))
            await actor.subscribe(symbols: symbols, apiKey: apiKey)
        }
        
        return stream
    }
    
    func fetchOptionChain(for symbol: String) async throws -> [OptionContract] {
        // TODO: Implement Polygon Option Chain API
        // For now, return empty or mock structure to satisfy protocol
        print("⚠️ Live Option Chain not implemented yet. Using Mock fallback logic if needed.")
        return []
    }
}
