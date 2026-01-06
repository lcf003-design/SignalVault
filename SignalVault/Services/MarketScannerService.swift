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
    private var marketService = MockMarketService() // Lightweight
    
    // The "Universe"
    private let universe: [(symbol: String, name: String, type: AssetType)] = [
        // Crypto (Scalpers)
        ("BTC", "Bitcoin", .crypto),
        ("ETH", "Ethereum", .crypto),
        ("SOL", "Solana", .crypto),
        ("DOGE", "Dogecoin", .crypto),
        
        // Tech (Macro)
        ("NVDA", "NVIDIA", .stock),
        ("AAPL", "Apple", .stock),
        ("TSLA", "Tesla", .stock),
        ("AMD", "AMD", .stock),
        
        // Indices
        ("SPY", "S&P 500", .stock),
        ("QQQ", "Nasdaq", .stock)
    ]
    
    private var isScanning = false
    
    // Start the Infinite Loop
    func startScanning() {
        guard !isScanning else { return }
        isScanning = true
        print("🔭 ALPHA SCANNER: Online. Analyzing Asset Universe...")
        
        // Initialize Engines
        for item in universe {
            let engine = SignalEngine()
            // Config switching logic is inside SignalEngine.process() automatically
            engines[item.symbol] = engine
        }
        
        // Scan Loop
        Task {
            while isScanning {
                var newResults: [ScannedAsset] = []
                
                // Concurrent Analysis
                await withTaskGroup(of: ScannedAsset?.self) { group in
                    for item in universe {
                        group.addTask {
                            return await self.analyze(item: item)
                        }
                    }
                    
                    for await result in group {
                        if let asset = result {
                            newResults.append(asset)
                        }
                    }
                }
                
                // Sort by Conviction (Highest First)
                newResults.sort { $0.convictionScore > $1.convictionScore }
                
                // Update UI
                self.assets = newResults
                
                // Determine Top Pick (Volatility Winner)
                if let best = newResults.first, best.convictionScore > 0.85 {
                    if self.topPick?.symbol != best.symbol {
                        // New Winner!
                        self.topPick = best
                        HapticManager.shared.playImpact() // Discovery Thud
                    }
                } else {
                    self.topPick = nil
                }
                
                // Throttle (Simulate 1-second refresh)
                try? await Task.sleep(for: .seconds(2))
            }
        }
    }
    
    func stopScanning() {
        isScanning = false
    }
    
    // The "Brain" for a single asset
    private func analyze(item: (symbol: String, name: String, type: AssetType)) async -> ScannedAsset? {
        guard let engine = engines[item.symbol] else { return nil }
        
        // 1. Fetch live snapshot (Mocked for speed)
        let currentPrice = Double.random(in: 100...200) 
        let tick = MarketTick(
            symbol: item.symbol,
            price: currentPrice + Double.random(in: -0.5...0.5),
            volume: Double.random(in: 1000...50000), // Should vary for volume status
            timestamp: Date()
        )
        
        // 2. Feed the Engine
        // Mission 34: Receive Context (Signal + Alignment)
        let context = await engine.process(tick: tick)
        
        // 3. Mock External Factors for Kai Score
        // In a real app, you'd fetch 24h Volume and Sentiment API here
        let volumeFactor = Double.random(in: 0.5...2.5) // 1.0 is avg
        let sentimentFactor = Double.random(in: -0.8...0.8) // -1 to 1
        
        // 4. Kai Scorer Logic
        // Formula: (TechnicalScore * 0.5) + (VolumeScore * 0.3) + (SentimentScore * 0.2)
        
        var techScore = 0.0
        if let s = context.tradeSignal {
            switch s {
            case .strongBuy(let conf, _): techScore = conf
            case .strongSell(let conf, _): techScore = conf
            case .neutral(let conf): techScore = conf * 0.2
            }
        }
        // Boost for alignment
        if context.alignment == .bullish && context.tradeSignal?.isBuy == true { techScore += 0.1 }
        if context.alignment == .bearish && context.tradeSignal?.isSell == true { techScore += 0.1 }
        techScore = min(techScore, 1.0)
        
        let volumeScore = min(volumeFactor / 2.0, 1.0) // Cap at 2x volume = 100% score
        let sentimentScore = (sentimentFactor + 1.0) / 2.0 // Normalize -1..1 to 0..1
        
        let rawKai = (techScore * 0.5) + (volumeScore * 0.3) + (sentimentScore * 0.2)
        let kaiScore = Int(rawKai * 100)
        
        // Determine Volume Status
        let volumeStatus: VolumeStatus
        if volumeFactor > 2.0 { volumeStatus = .ultra }
        else if volumeFactor > 1.2 { volumeStatus = .high }
        else if volumeFactor < 0.8 { volumeStatus = .low }
        else { volumeStatus = .normal }
        
        // 5. AI Summary Generator
        let summary = generateAISummary(symbol: item.symbol, context: context, volume: volumeStatus, sentiment: sentimentFactor)
        
        // Legacy Support
        let legacyScore = techScore
        let isPerfectAlignment = context.alignment != .mixed
        let shouldGlow = kaiScore >= 85
        
        let change = Double.random(in: -3.0...3.0)
        
        return ScannedAsset(
            symbol: item.symbol,
            name: item.name,
            price: tick.price,
            changePercent: change,
            kaiScore: kaiScore,
            volumeStatus: volumeStatus,
            aiSummary: summary,
            assetType: item.type,
            convictionScore: legacyScore,
            signalType: context.tradeSignal ?? .neutral(confidence: 0.0),
            isGlowing: shouldGlow
        )
    }
    
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
