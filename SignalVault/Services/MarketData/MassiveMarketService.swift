import Foundation

class MassiveMarketService: MarketDataProvider {
    private let actor = MassiveSocketActor.shared
    private let apiKey: String
    
    init(key: String = Secrets.polygonAPIKey) {
        self.apiKey = key
    }
    
    func connect() async throws {
        // 1. Verify Key Validity via REST first
        let isValid = await verifyAPIKey()
        if !isValid {
            print("🚫 Massive: API Key appears invalid or inactive.")
            // Allow socket to try anyway, but log warning
        }
        
        await actor.connect(apiKey: apiKey)
    }
    
    func connectionStatus() async -> AsyncStream<MassiveSocketActor.SocketStatus> {
        await actor.statusStream()
    }
    
    func streamQuotes(for symbols: [String]) async -> AsyncStream<MarketTick> {
        let (stream, continuation) = AsyncStream<MarketTick>.makeStream()
        
        Task {
            _ = await actor.registerContinuation(continuation)
            
            // Wait for connection/auth before subscribing
            // In a real robust system, we would wait for .authenticated status
            try? await Task.sleep(for: .seconds(2))
            
            await actor.subscribe(symbols: symbols)
        }
        
        return stream
    }
    
    private func verifyAPIKey() async -> Bool {
        // Check a lightweight endpoint to verify credentials
        let urlString = "https://api.polygon.io/v3/reference/tickers?active=true&limit=1&apiKey=\(apiKey)"
        guard let url = URL(string: urlString) else { return false }
        
        do {
            let (_, response) = try await URLSession.shared.data(from: url)
            if let httpResp = response as? HTTPURLResponse {
                if httpResp.statusCode == 200 { return true }
                print("⚠️ Key Verification Failed: HTTP \(httpResp.statusCode)")
            }
        } catch {
            print("⚠️ Key Verification Error: \(error)")
        }
        return false
    }

    // Massive / Polygon Snapshot API
    func fetchStockSnapshots(for symbols: [String]) async -> [MarketTick] {
        guard !apiKey.isEmpty, !symbols.isEmpty else { return [] }
        
        let tickers = symbols.joined(separator: ",")
        // Use v2 snapshot - Note: Failing on Free Tier (403)
        let urlString = "https://api.polygon.io/v2/snapshot/locale/us/markets/stocks/tickers?tickers=\(tickers)&apiKey=\(apiKey)"
        guard let url = URL(string: urlString) else { return [] }
        
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            
            if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode == 403 {
                    print("⚠️ Massive Snapshots: Access Denied (Likely Free Tier limitation). Skipping.")
                    return []
                }
                if httpResponse.statusCode != 200 {
                    // Log but ignore
                    return []
                }
            }
            
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let tickerList = json["tickers"] as? [[String: Any]] {
                
                var ticks: [MarketTick] = []
                for item in tickerList {
                    if let sym = item["ticker"] as? String {
                        // Prefer lastTrade (p), fallback to day close (c)
                        var price = 0.0
                        var size = 0.0
                        
                        if let lastTrade = item["lastTrade"] as? [String: Any],
                           let p = lastTrade["p"] as? Double {
                            price = p
                            size = (lastTrade["s"] as? Double) ?? 0.0
                        } else if let day = item["day"] as? [String: Any],
                                  let c = day["c"] as? Double {
                            price = c
                            size = (day["v"] as? Double) ?? 0.0
                        }
                        
                        if price > 0 {
                            ticks.append(MarketTick(symbol: sym, price: price, volume: size, timestamp: Date()))
                        }
                    }
                }
                return ticks
            }
        } catch {
            print("⚠️ Massive Snapshot Error: \(error)")
        }
        
        return []
    }
    
    func fetchOptionChain(for symbol: String) async throws -> [OptionContract] {
        // Massive has great Options API, can be implemented later
        print("ℹ️ Massive Options API not yet implemented.")
        return []
    }
}
