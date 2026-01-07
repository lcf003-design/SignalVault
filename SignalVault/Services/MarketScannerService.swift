import Foundation
import Combine

// Mission 33: The Alpha Scanner Service
@MainActor
class MarketScannerService: ObservableObject {
    @Published var assets: [ScannedAsset] = []
    @Published var topPick: ScannedAsset?
    
    // Internal Engines (One per asset)
    // In a real app with 1000s of assets, you'd perform this server-side.
    // For this powerful local demonstration, we run concurrent actors.
    private var engines: [String: SignalEngine] = [:]
    private var marketService: MarketDataProvider = MockMarketService() // Lightweight
    
    // The "Universe"
    private let universe: [(symbol: String, name: String, type: AssetType)] = [
        // Crypto (Major)
        ("BTC", "Bitcoin", .crypto),
        ("ETH", "Ethereum", .crypto),
        ("SOL", "Solana", .crypto),
        ("DOGE", "Dogecoin", .crypto),
        ("XRP", "Ripple", .crypto),
        ("ADA", "Cardano", .crypto),
        ("AVAX", "Avalanche", .crypto),
        ("DOT", "Polkadot", .crypto),
        ("LINK", "Chainlink", .crypto),
        ("MATIC", "Polygon", .crypto),
        
        // Tech (Mega Cap)
        ("NVDA", "NVIDIA", .stock),
        ("AAPL", "Apple", .stock),
        ("TSLA", "Tesla", .stock),
        ("AMD", "AMD", .stock),
        ("MSFT", "Microsoft", .stock),
        ("GOOGL", "Alphabet", .stock),
        ("AMZN", "Amazon", .stock),
        ("META", "Meta", .stock),
        ("NFLX", "Netflix", .stock),
        
        // High Beta / Volatile
        ("COIN", "Coinbase", .stock),
        ("MSTR", "MicroStrategy", .stock),
        ("SQ", "Block", .stock),
        ("ROKU", "Roku", .stock),
        ("PLTR", "Palantir", .stock),
        ("SHOP", "Shopify", .stock),
        
        // Indices / ETFs
        ("SPY", "S&P 500", .stock),
        ("QQQ", "Nasdaq 100", .stock),
        ("IWM", "Russell 2000", .stock),
        ("ARKK", "Ark Innovation", .stock),
        ("TLT", "20+ Year Treasury", .stock),
        ("GLD", "Gold Trust", .stock),
        ("SLV", "Silver Trust", .stock),
        ("USO", "United States Oil", .stock),
        
        // Forex (Represented as Crypto/Stock proxies for now within Free Tier)
        ("EUR USD", "Euro", .forex),
        ("GBP USD", "British Pound", .forex),
        ("USD JPY", "Japanese Yen", .forex)
    ]
    
    private var isScanning = false
    
    // Mission 49: Connection Status Logic
    enum ScannerStatus {
        case disconnected
        case connecting
        case streaming
        case offline // No keys or error
    }
    @Published var status: ScannerStatus = .disconnected
    
    // Start the Infinite Loop (Live Data)
    func startScanning() {
        guard !isScanning else { return }
        isScanning = true
        status = .connecting
        print("🔭 ALPHA SCANNER: Online. Connecting to Live Data...")
        
        // Initialize Engines
        for item in universe {
            if engines[item.symbol] == nil {
                engines[item.symbol] = SignalEngine()
            }
        }
        
        // Initialize Assets with placeholders if empty (so the list isn't blank while connecting)
        if assets.isEmpty {
            assets = universe.map { item in
                ScannedAsset(
                    symbol: item.symbol,
                    name: item.name,
                    price: 0.0, // Loading state
                    changePercent: 0.0,
                    kaiScore: 0,
                    volumeStatus: .normal,
                    aiSummary: "Initializing...",
                    assetType: item.type,
                    convictionScore: 0.0,
                    signalType: .neutral(confidence: 0.0),
                    isGlowing: false
                )
            }
        }
        
        // Switch to Live Service
        // Switch to Massive Service
        // Check for Keys first
        if !Secrets.polygonAPIKey.isEmpty {
            self.marketService = MassiveMarketService()
            print("🚀 SCANNER: Using Massive Data Feed")
        } else {
             print("⚠️ SCANNER: No Keys found. Falling back to Mock.")
             status = .offline
             isScanning = false // Allow retry
             return
        }
        
        let symbols = universe.map { $0.symbol }
        
        Task {
            try? await marketService.connect()
            
            // Listen to Status (if supported)
            if let massiveService = marketService as? MassiveMarketService {
                // 1. Fetch Snapshots for Instant Data (Fixes "Initializing" hang)
                print("📸 Fetching Snapshots...")
                let snapshots = await massiveService.fetchStockSnapshots(for: symbols)
                for tick in snapshots {
                     await processLiveTick(tick)
                }
                if !snapshots.isEmpty {
                    print("✅ Snapshots Loaded: \(snapshots.count) assets updated.")
                }
                
                let statusStream = await massiveService.connectionStatus()
                Task {
                    for await socketStatus in statusStream {
                        await MainActor.run {
                            switch socketStatus {
                            case .connected:
                                self.status = .connecting
                            case .authenticated:
                                // If we have snapshots, we can consider ourselves "Live"ish
                                if !snapshots.isEmpty { self.status = .streaming }
                                else { self.status = .connecting }
                            case .disconnected: self.status = .disconnected
                            case .failed(_): self.status = .offline
                            case .connecting: self.status = .connecting
                            }
                        }
                    }
                }
            }
            
            let stream = await marketService.streamQuotes(for: symbols)
            
            // Mission 55 Fix: Throttled Scanner
            await consumeScannerStreamOffMainThread(stream)
        }
    }
    
    // Non-isolated Consumer
    nonisolated private func consumeScannerStreamOffMainThread(_ stream: AsyncStream<MarketTick>) async {
        var tickBuffer: [String: MarketTick] = [:] // Map symbol -> Latest Tick
        var lastUpdate = Date()
        let throttleInterval: TimeInterval = 0.25 // 250ms (4 FPS is plenty for a list)
        
        for await tick in stream {
            if Task.isCancelled { break }
            
            // Keep only latest tick per symbol
            tickBuffer[tick.symbol] = tick
            
            let now = Date()
            if now.timeIntervalSince(lastUpdate) >= throttleInterval {
                let batch = Array(tickBuffer.values)
                tickBuffer.removeAll()
                lastUpdate = now
                
                // Flush batch to Main Actor
                if !batch.isEmpty {
                    await self.processLiveBatch(batch)
                }
            }
        }
    }
    
    @MainActor
    private func processLiveBatch(_ ticks: [MarketTick]) async {
        if status != .streaming { status = .streaming }
        
        for tick in ticks {
             await processLiveTick(tick)
        }
    }
    
    private func processLiveTick(_ tick: MarketTick) async {
        // Find existing asset index
        guard let index = assets.firstIndex(where: { $0.symbol == tick.symbol }) else { return }
        guard let engine = engines[tick.symbol] else { return }
        
        // 1. Process Signal
        let context = await engine.process(tick: tick)
        
        // 2. Mock external factors for now (since we don't have full history for everyone yet)
        let volumeFactor = Double.random(in: 0.8...1.5) // Less random, closer to normal
        let sentimentFactor = Double.random(in: -0.2...0.2)
        
        // 3. Score Logic (Same as before)
        var techScore = 0.0
        if let s = context.tradeSignal {
             switch s {
             case .strongBuy(let conf, _): techScore = conf
             case .strongSell(let conf, _): techScore = conf
             case .neutral(let conf): techScore = conf * 0.2
             }
        }
        if context.alignment == .bullish && context.tradeSignal?.isBuy == true { techScore += 0.1 }
        if context.alignment == .bearish && context.tradeSignal?.isSell == true { techScore += 0.1 }
        techScore = min(techScore, 1.0)
        
        let volumeScore = min(volumeFactor / 2.0, 1.0)
        let sentimentScore = (sentimentFactor + 1.0) / 2.0
        let rawKai = (techScore * 0.5) + (volumeScore * 0.3) + (sentimentScore * 0.2)
        let kaiScore = Int(rawKai * 100)
        
        // 4. Volume Status
        let volumeStatus: VolumeStatus = volumeFactor > 1.5 ? .high : .normal
        
        // 5. Summary
        let summary = generateAISummary(symbol: tick.symbol, context: context, volume: volumeStatus, sentiment: sentimentFactor)
        
        // 6. Calculate Change (Mocked for intraday since we don't have Open price in tick)
        // Ideally we'd store the session open. For now, assume a minor drift.
        // Or if we have previous price, calculate delta.

        // Change logic: specific to demo limitations on free tier (no daily bars API)
        // We'll calculate change based on a fixed "Opening Reference" if we had one.
        // For now, let's keep the random drift for the *Change %*, but use REAL PRICE.
        let change = assets[index].changePercent // Keep stable or drift slightly
        
        let shouldGlow = kaiScore >= 85
        
        // UPDATE THE ASSET
        let updatedAsset = ScannedAsset(
            symbol: tick.symbol,
            name: assets[index].name,
            price: tick.price, // REAL LIVE PRICE
            changePercent: change, 
            kaiScore: kaiScore,
            volumeStatus: volumeStatus,
            aiSummary: summary,
            assetType: assets[index].assetType,
            convictionScore: techScore,
            signalType: context.tradeSignal ?? .neutral(confidence: 0.0),
            isGlowing: shouldGlow
        )
        
        // Update Array
        assets[index] = updatedAsset
        
        // Update Top Pick throttled
        if kaiScore > 85 && (topPick == nil || kaiScore > topPick!.kaiScore) {
             topPick = updatedAsset
        }
    }
    
    func stopScanning() {
        isScanning = false
    }
    
    // Removed legacy analyze() function - Replaced by processLiveTick
    
    // Proactive Context Generator (Mission 35)
    private func generateAISummary(symbol: String, context: SignalContext, volume: VolumeStatus, sentiment: Double) -> String {
        // "NVDA is surging on a bullish 15m MACD crossover and positive earnings sentiment."
        
        var action = "consolidating"
        var reason = "due to mixed signals"
        var sentimentText = ""
        
        // Action
        if let signal = context.tradeSignal {
            if signal.isBuy {
                action = volume == .ultra ? "skyrocketing" : "rallying"
            } else if signal.isSell {
                action = volume == .ultra ? "crashing" : "correcting"
            }
        }
        
        // Reason (Mocked technicals since we don't expose exact crossover details in context yet)
        if context.alignment == .bullish {
            reason = "on high-conviction bullish alignment"
        } else if context.alignment == .bearish {
            reason = "following a breakdown across timeframes"
        } else if context.isDivergenceDetected {
            reason = "warning of a potential reversal (divergence)"
        }
        
        // Sentiment
        if sentiment > 0.5 { sentimentText = " with euphoria building" }
        else if sentiment < -0.5 { sentimentText = " amidst panic selling" }
        
        return "\(symbol) is \(action) \(reason)\(sentimentText)."
    }
}
