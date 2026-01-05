import Foundation



actor SignalEngine {
    // MARK: - State
    private var prices: [Double] = []
    private var volumes: [Double] = [] // Mission 12: Volume Tracking
    
    // EMA State (Stored to ensure O(1) updates)
    private var prevEMA12: Double?
    private var prevEMA26: Double?
    private var prevSignalLine: Double? // 9-period EMA of MACD
    
    // RSI State
    private var previousRSI: Double?
    
    // Config (Asset-Aware Defaults)
    private var config: EngineConfig = .stock
    private var overrideConfig: EngineConfig? // Mission 14: Optimization override
    
    func setOverrideConfig(_ config: EngineConfig?) {
        self.overrideConfig = config
        if let cfg = config { self.config = cfg }
    }
    
    func reset() {
        prices.removeAll()
        volumes.removeAll()
        prevEMA12 = nil
        prevEMA26 = nil
        prevSignalLine = nil
        previousRSI = nil
    }
    
    // Mission 15: Sentiment Overlay
    private var currentSentiment: SentimentAnalysisResult?
    // Mission 16: Macro Regime
    private var currentRegime: MarketRegime = .neutral
    
    func updateSentiment(_ sentiment: SentimentAnalysisResult) {
        self.currentSentiment = sentiment
    }
    
    func updateRegime(_ regime: MarketRegime) {
        self.currentRegime = regime
        if regime == .riskOff {
            print("📉 MACRO FILTER: Risk-Off Mode Activated. Reducing Conviction by 15%.")
        }
    }
    
    // MARK: - Processing
    func process(tick: MarketTick) -> TradeSignal? {
        // 0. Auto-Detect Asset Class & Config (Unless Overridden)
        if overrideConfig == nil {
            let isCrypto = ["BTC", "ETH", "SOL"].contains(where: { tick.symbol.contains($0) })
            if isCrypto && config.rsiPeriod != 9 {
                print("🧠 AI ENGINE: Switching to CRYPTO Mode (Faster Volatility)")
                self.config = .crypto
            } else if !isCrypto && config.rsiPeriod != 14 {
                print("🧠 AI ENGINE: Switching to STOCK Mode (Standard)")
                self.config = .stock
            }
        }
        
        let price = tick.price
        prices.append(price)
        volumes.append(tick.volume)
        
        // Maintain buffer
        if prices.count > 100 { prices.removeFirst() }
        if volumes.count > 100 { volumes.removeFirst() }
        
        // 1. Update EMAs & MACD (Using dynamic config)
        let currentEMA12 = updateEMA(currentPrice: price, previousEMA: prevEMA12, period: config.macdFast)
        let currentEMA26 = updateEMA(currentPrice: price, previousEMA: prevEMA26, period: config.macdSlow)
        
        prevEMA12 = currentEMA12
        prevEMA26 = currentEMA26
        
        guard let ema12 = currentEMA12, let ema26 = currentEMA26 else { return nil }
        
        let macdLine = ema12 - ema26
        
        // 2. Update Signal Line
        let currentSignalLine = updateEMA(currentPrice: macdLine, previousEMA: prevSignalLine, period: config.signalPeriod)
        prevSignalLine = currentSignalLine
        
        guard let signalLine = currentSignalLine else { return nil }
        
        // 3. Update RSI
        guard let currentRSI = calculateRSI(period: config.rsiPeriod) else { return nil }
        
        // 4. Logic: Dual-Confirmation + Volume
        var tradeSignal: TradeSignal?
        var rawSignal: TradeSignal?
        
        // Volume Confirmation (Mission 12)
        // Check if current volume > 20% above 10-period average
        let avgVol = calculateAvgVolume()
        let volumeConfirmation = tick.volume > (avgVol * 1.2)
        
        if let prevRSI = previousRSI {
            let isBullishMACD = macdLine > signalLine
            let isBearishMACD = macdLine < signalLine
            
            // BUY: MACD Bullish + RSI crosses 30 + Volume
            if isBullishMACD && prevRSI < 30 && currentRSI >= 30 {
                if volumeConfirmation {
                    rawSignal = .strongBuy(confidence: 0.95, price: price)
                }
            }
            // SELL: MACD Bearish + RSI crosses 70 + Volume
            else if isBearishMACD && prevRSI > 70 && currentRSI <= 70 {
                if volumeConfirmation {
                    rawSignal = .strongSell(confidence: 0.95, price: price)
                }
            }
        }
        
        previousRSI = currentRSI
        
        // 5. Sentiment Divergence Check (Mission 15)
        if let signal = rawSignal, let sentiment = currentSentiment {
            var adjustedConfidence = 0.95
            
            // Mission 16: Macro Regime Filter
            if currentRegime == .riskOff {
                adjustedConfidence *= 0.85 // Reduce by 15% -> ~0.80
            }
            
            switch signal {
            case .strongBuy(_, let price):
                if sentiment.aggregateScore < -0.3 {
                    print("⚠️ DIVERGENCE ALERT: Technical Bullish, but News is Bearish. Possible BULL TRAP.")
                    return nil
                } else {
                    tradeSignal = .strongBuy(confidence: adjustedConfidence, price: price)
                }
            case .strongSell(_, let price):
                if sentiment.aggregateScore > 0.3 {
                    print("⚠️ DIVERGENCE ALERT: Technical Bearish, but News is Bullish. Possible BEAR TRAP.")
                    return nil
                } else {
                    tradeSignal = .strongSell(confidence: adjustedConfidence, price: price)
                }
            case .neutral:
                tradeSignal = .neutral(confidence: 0.5)
            }
        } else {
            // Apply Macro Filter even if no sentiment (or if raw signal exists)
             if let signal = rawSignal {
                var adjustedConfidence = 0.95
                if currentRegime == .riskOff { adjustedConfidence *= 0.85 }
                
                 switch signal {
                 case .strongBuy(_, let price):
                     tradeSignal = .strongBuy(confidence: adjustedConfidence, price: price)
                 case .strongSell(_, let price):
                     tradeSignal = .strongSell(confidence: adjustedConfidence, price: price)
                 default:
                     tradeSignal = signal
                 }
             }
        }
        
        return tradeSignal
    }
    
    private func calculateAvgVolume() -> Double {
        guard !volumes.isEmpty else { return 1.0 }
        let subset = volumes.suffix(10)
        return subset.reduce(0, +) / Double(subset.count)
    }
    
    // MARK: - Math Helpers
    
    /// Stateful EMA Calculation
    private func updateEMA(currentPrice: Double, previousEMA: Double?, period: Int) -> Double? {
        // Multiplier: (2 / (N + 1))
        let k = 2.0 / Double(period + 1)
        
        if let prev = previousEMA {
            // Standard EMA formula
            return (currentPrice * k) + (prev * (1.0 - k))
        } else {
            // First value? Ideally SMA of first N, but for streaming startup we seed with current
            // (or wait for N samples if strict, but seeding allows faster start)
            return currentPrice
        }
    }
    
    private func calculateRSI(period: Int) -> Double? {
        guard prices.count >= period + 1 else { return nil }
        
        // Calculate Changes
        let window = prices.suffix(period + 1)
        let changes = zip(window.dropFirst(), window).map { $0 - $1 }
        
        var gains = 0.0
        var losses = 0.0
        
        for change in changes {
            if change > 0 { gains += change }
            else { losses += abs(change) }
        }
        
        if losses == 0 { return 100.0 }
        
        let avgGain = gains / Double(period)
        let avgLoss = losses / Double(period)
        
        let rs = avgGain / avgLoss
        return 100.0 - (100.0 / (1.0 + rs))
    }
}


