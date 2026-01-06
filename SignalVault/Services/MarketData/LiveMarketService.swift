import Foundation

class LiveMarketService: MarketDataProvider {
    private let actor = AlpacaSocketActor.shared
    private let apiKeyID: String
    private let secretKey: String
    
    init(keyID: String = Secrets.alpacaAPIKeyID, secret: String = Secrets.alpacaSecretKey) {
        self.apiKeyID = keyID
        self.secretKey = secret
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
            await actor.subscribe(symbols: symbols, keyID: apiKeyID, secretKey: secretKey)
        }
        
        return stream
    }
    
    func fetchOptionChain(for symbol: String) async throws -> [OptionContract] {
        // TODO: Implement Alpaca Options API (if upgraded to paid tier)
        print("⚠️ Alpaca Options not available on Free Tier.")
        return []
    }
}
