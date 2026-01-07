import Foundation



actor SignalEngine {
    // MARK: - Core Definitions

    
    // MARK: - State
    private var states: [Timeframe: TimeframeState] = [
        .m1: TimeframeState(),
        .m5: TimeframeState(),
        .m15: TimeframeState()
    ]
    
    private var config: EngineConfig = .stock
    private var overrideConfig: EngineConfig?
    
    // Metadata
    private var currentSentiment: SentimentAnalysisResult?
    private var currentRegime: MarketRegime = .neutral
    private var upcomingEvents: [EconomicEvent] = []
    
    // MARK: - Public API
    func setOverrideConfig(_ config: EngineConfig?) {
        self.overrideConfig = config
        if let cfg = config { self.config = cfg }
    }
    
    func reset() {
        // Reset by replacing with new empty structs
        for tf in Timeframe.allCases {
            states[tf] = TimeframeState()
        }
        cumulativeTypicalPriceVolume = 0
        cumulativeVolume = 0
        
        // Mission 36 Part 2: Reset ORB
        openingRangeHigh = nil
        openingRangeLow = nil
        sessionStartTime = nil
        isOrbSet = false
        yesterdayHigh = nil
        yesterdayLow = nil
    }
    
    func updateSentiment(_ sentiment: SentimentAnalysisResult) { self.currentSentiment = sentiment }
    func updateEvents(_ events: [EconomicEvent]) { self.upcomingEvents = events }
    
    func updateRegime(_ regime: MarketRegime) {
        self.currentRegime = regime
        if regime == .riskOff {
            print("📉 MACRO FILTER: Risk-Off Mode Activated.")
        }
    }
    
    // Mission 36: VWAP Accumulators
    private var cumulativeTypicalPriceVolume: Double = 0
    private var cumulativeVolume: Double = 0
    
    // MARK: - Main Processor (Mission 34 & 36)
    func process(tick: MarketTick) -> SignalContext {
        // 0. Auto-Config (Crypto vs Stock)
        autoConfigure(symbol: tick.symbol)
        
        // Mission 36: VWAP Calc
        let typicalPrice = tick.price // Using Close for streaming simplicity (H+L+C)/3 is better if we have bar data
        cumulativeVolume += tick.volume
        cumulativeTypicalPriceVolume += (typicalPrice * tick.volume)
        
        // Mission 36 Part 2: Update ORB
        updateORB(tick: tick)
        
        let vwap = cumulativeVolume > 0 ? cumulativeTypicalPriceVolume / cumulativeVolume : tick.price
        let vwapDistance = (tick.price - vwap) / vwap
        
        var divergenceDetected = false
        
        // 1. Update All Timeframes
        // 1. Update All Timeframes
        // Since TimeframeState is a struct, we must mutate and re-assign
        for tf in Timeframe.allCases {
            // Retrieve Copy
            guard var state = states[tf] else { continue }
            
            let interval: TimeInterval = tf == .m1 ? 60 : (tf == .m5 ? 300 : 900)
            
            // Mutate Copy
            let candleClosed = updateTimeframeState(state: &state, price: tick.price, volume: tick.volume, time: tick.timestamp, interval: interval)
            
            // Re-calc technicals on copy
            let analysis = analyzeState(state, config: config)
            state.latestSignal = analysis.signal
            
            // Mission 34.3: Divergence Check (Only on 5m)
            if tf == .m5 && candleClosed {
                // Pass copy to helper
                if checkDivergence(state: &state, currentRSI: analysis.rsi) {
                    print("⚠️ BEARISH DIVERGENCE DETECTED on 5m Chart!")
                    divergenceDetected = true
                }
            }
            
            // Write Back to Dictionary (Value Type Update)
            states[tf] = state
        }
        
        // 2. Consensus Engine
        let m1 = states[.m1]!.latestSignal
        let m5 = states[.m5]!.latestSignal
        let m15 = states[.m15]!.latestSignal
        
        let signals = [m1, m5, m15]
        let buyCount = signals.filter { if case .strongBuy = $0 { return true }; return false }.count
        let sellCount = signals.filter { if case .strongSell = $0 { return true }; return false }.count
        
        // Base Context
        var finalContext = SignalContext(
            tradeSignal: nil,
            alignment: .mixed,
            isDivergenceDetected: divergenceDetected,
            vwap: vwap,
            vwapDistance: vwapDistance,
            openingRangeHigh: openingRangeHigh,
            openingRangeLow: openingRangeLow,
            isConsolidating: !isOrbSet, // Default to true if forming
            yesterdayHigh: yesterdayHigh,
            yesterdayLow: yesterdayLow
        )
        
        // Alignment Logic
        if buyCount == 3 {
             finalContext = SignalContext(tradeSignal: m1, alignment: .bullish, isDivergenceDetected: divergenceDetected, vwap: vwap, vwapDistance: vwapDistance, openingRangeHigh: openingRangeHigh, openingRangeLow: openingRangeLow, isConsolidating: false, yesterdayHigh: yesterdayHigh, yesterdayLow: yesterdayLow)
        } else if sellCount == 3 {
             finalContext = SignalContext(tradeSignal: m1, alignment: .bearish, isDivergenceDetected: divergenceDetected, vwap: vwap, vwapDistance: vwapDistance, openingRangeHigh: openingRangeHigh, openingRangeLow: openingRangeLow, isConsolidating: false, yesterdayHigh: yesterdayHigh, yesterdayLow: yesterdayLow)
        } else if buyCount >= 2 {
             if buyCount == 2 {
                 finalContext = SignalContext(tradeSignal: .strongBuy(confidence: 0.85, price: tick.price), alignment: .mixed, isDivergenceDetected: divergenceDetected, vwap: vwap, vwapDistance: vwapDistance, openingRangeHigh: openingRangeHigh, openingRangeLow: openingRangeLow, isConsolidating: false, yesterdayHigh: yesterdayHigh, yesterdayLow: yesterdayLow)
             }
        } else if sellCount >= 2 {
             if sellCount == 2 {
                 finalContext = SignalContext(tradeSignal: .strongSell(confidence: 0.85, price: tick.price), alignment: .mixed, isDivergenceDetected: divergenceDetected, vwap: vwap, vwapDistance: vwapDistance, openingRangeHigh: openingRangeHigh, openingRangeLow: openingRangeLow, isConsolidating: false, yesterdayHigh: yesterdayHigh, yesterdayLow: yesterdayLow)
             }
        } else {
             finalContext = SignalContext(tradeSignal: .neutral(confidence: 0.0), alignment: .mixed, isDivergenceDetected: divergenceDetected, vwap: vwap, vwapDistance: vwapDistance, openingRangeHigh: openingRangeHigh, openingRangeLow: openingRangeLow, isConsolidating: false, yesterdayHigh: yesterdayHigh, yesterdayLow: yesterdayLow)
        }
        
        // Apply Filters (Macro, Sentiment, Volatility, VWAP Bias, ORB)
        if let rawSig = finalContext.tradeSignal {
             var filteredSig = applyFilters(rawSig, regime: currentRegime, sentiment: currentSentiment)
             filteredSig = applyVolatilityBuffer(to: filteredSig)
             
             // Mission 36.1: VWAP Bias
             filteredSig = applyVWAPBias(to: filteredSig, price: tick.price, vwap: vwap)
             
             // Mission 36.2: ORB Filter
             let (orbSig, isConsolidating) = applyORBFilter(to: filteredSig, price: tick.price)
             filteredSig = orbSig
             
             // Update Context with filtered signal
             return SignalContext(
                 tradeSignal: filteredSig,
                 alignment: finalContext.alignment,
                 isDivergenceDetected: finalContext.isDivergenceDetected,
                 vwap: vwap,
                 vwapDistance: vwapDistance,
                 openingRangeHigh: openingRangeHigh,
                 openingRangeLow: openingRangeLow,
                 isConsolidating: isConsolidating,
                 yesterdayHigh: yesterdayHigh,
                 yesterdayLow: yesterdayLow
             )
        }
        
        // If no signal, we might still be consolidating
        // Only if Orb is set and we maintain the state
        if isOrbSet, let h = openingRangeHigh, let l = openingRangeLow, tick.price <= h && tick.price >= l {
            // Force consolidating state update if we returned early
            var ctx = finalContext
            ctx.isConsolidating = true
            return ctx
        }
        
        return finalContext
    }
    
    // Mission 36: VWAP Logic
    private func applyVWAPBias(to signal: TradeSignal, price: Double, vwap: Double) -> TradeSignal {
        var bias: Double = 0.0
        
        // If Price > VWAP, Bullish Bias
        if price > vwap {
            if case .strongBuy = signal { bias = 0.10 } // Trend following bonus
            if case .strongSell = signal { bias = -0.10 } // Counter-trend penalty
        } else {
            // Price < VWAP, Bearish Bias
            if case .strongSell = signal { bias = 0.10 } // Trend following bonus
            if case .strongBuy = signal { bias = -0.10 } // Counter-trend penalty
        }
        
        switch signal {
        case .strongBuy(let conf, let p): 
            return .strongBuy(confidence: min(conf + bias, 1.0), price: p)
        case .strongSell(let conf, let p):
            return .strongSell(confidence: min(conf + bias, 1.0), price: p)
        default: return signal
        }
    }
    
    // Mission 36 Part 2: The ORB Layer
    private var openingRangeHigh: Double?
    private var openingRangeLow: Double?
    private var sessionStartTime: Date?
    private var isOrbSet: Bool = false
    
    // Session Pivot Markers
    private var yesterdayHigh: Double?
    private var yesterdayLow: Double?
    
    private func updateORB(tick: MarketTick) {
        // 1. Initialize Session
        if sessionStartTime == nil {
            sessionStartTime = tick.timestamp
            // Mock Yesterday's Levels relative to Open
            // In real app, this comes from daily aggregate API
            yesterdayHigh = tick.price * 1.02
            yesterdayLow = tick.price * 0.98
        }
        
        guard let start = sessionStartTime else { return }
        
        // 2. Track first 15 minutes
        let timeElapsed = tick.timestamp.timeIntervalSince(start)
        if timeElapsed < 900 { // 15 mins
            if openingRangeHigh == nil {
                openingRangeHigh = tick.price
                openingRangeLow = tick.price
            } else {
                openingRangeHigh = max(openingRangeHigh!, tick.price)
                openingRangeLow = min(openingRangeLow!, tick.price)
            }
        } else {
            // 3. Lock Range
            isOrbSet = true
        }
    }
    
    private func applyORBFilter(to signal: TradeSignal, price: Double) -> (TradeSignal, Bool) {
        // Returns (Signal, isConsolidating)
        guard isOrbSet, let high = openingRangeHigh, let low = openingRangeLow else {
            // If ORB not set yet, we are "Forming Range" - maybe treat as consolidating or just allow trades?
            // "Awaiting ORB Breakout" implies we shouldn't trade inside?
            // User says: "If the price is inside the range, label status as CONSOLIDATING"
            // Let's allow signals to form but maybe penalize? Or just strictly follow "Breakout" Logic.
            // Prompt: "Strong Buy only if > high. Strong Sell only if < low."
            // This implies strict filtering.
            return (signal, true) // Treating formative minutes as consolidation/wait
        }
        
        // Check if Inside Range
        if price <= high && price >= low {
            // Consolidating
            return (.neutral(confidence: 0), true)
        }
        
        // Check Breakout Conditions
        switch signal {
        case .strongBuy:
            // Must be > High
            if price > high { return (signal, false) }
            else { return (.neutral(confidence: 0), true) } // Failed Breakout or Reversion
            
        case .strongSell:
            // Must be < Low
            if price < low { return (signal, false) }
            else { return (.neutral(confidence: 0), true) }
            
        default:
            return (signal, false)
        }
    }
    
    // MARK: - Analysis Logic
    private func analyzeState(_ state: TimeframeState, config: EngineConfig) -> (signal: TradeSignal, rsi: Double?) {
        guard let current = state.currentCandle else { return (.neutral(confidence: 0), nil) }
        
        // We use state.candles (closed) + current (forming) for calcs
        // Simply appending current currentCandle to a temp array for math
        // Note: For true efficiency we'd update running stats.
        
        let allPrices = state.candles.map { $0.close } + [current.close]
        
        // RSI
        let period = config.rsiPeriod
        guard allPrices.count > period + 1 else { return (.neutral(confidence: 0), nil) }
        
        // Quick Calc Last RSI (Inefficient for high freq, but okay for prototype)
        // Optimized: Uses existing `calculateRSI` helper if we expose price array
        
        // ... Reusing math logic ... 
        let rsi = calculateRSI(prices: allPrices, period: period)
        
        // MACD
        // This requires stateful EMA.
        // We act as if 'current' is the latest tick for the EMA. 
        // CAUTION: Updating EMA on every tick of a forming candle ruins the math.
        // EMA should only update on CLOSE.
        // For real-time 1m, we project the EMA based on current price.
        
        // Simplified for this mission: Use previous closed EMAs + current price projection
        let ema12 = projectEMA(current: current.close, prev: state.prevEMA12, period: config.macdFast)
        let ema26 = projectEMA(current: current.close, prev: state.prevEMA26, period: config.macdSlow)
        
        let macdLine = ema12 - ema26
        let signalLine = projectEMA(current: macdLine, prev: state.prevSignalLine, period: config.signalPeriod)
        
        // Signal Logic
        if let rsiVal = rsi {
             // Basic Strategy (Same as before)
             // BUY
             if macdLine > signalLine && rsiVal < 35 {
                 return (.strongBuy(confidence: 0.9, price: current.close), rsiVal)
             }
             // SELL
             else if macdLine < signalLine && rsiVal > 65 {
                 return (.strongSell(confidence: 0.9, price: current.close), rsiVal)
             }
        }
        
        return (.neutral(confidence: 0.5), rsi)
    }
    
    private func checkDivergence(state: inout TimeframeState, currentRSI: Double?) -> Bool {
        guard let rsi = currentRSI, let currentPrice = state.currentCandle?.close else { return false }
        
        // Simple Bearish Divergence: Price High > Prev Price High AND RSI High < Prev RSI High
        if currentPrice > state.prevPriceHigh && rsi < state.prevRSIHigh {
            // Only Valid if RSI is in Overbought territory (>60)
            if rsi > 60 { return true }
        }
        
        // Update Highs (Tracking local peaks would be better, but this is a simple 'running high' tracker)
        if currentPrice > state.prevPriceHigh { state.prevPriceHigh = currentPrice }
        if rsi > state.prevRSIHigh { state.prevRSIHigh = rsi }
        
        return false
    }
    
    // MARK: - Legacy / Helper Filters
    private func applyFilters(_ signal: TradeSignal, regime: MarketRegime, sentiment: SentimentAnalysisResult?) -> TradeSignal {
        // ... (Same logic as original file, extracted for cleanliness) ...
        var confidence = 0.95
        if regime == .riskOff { confidence *= 0.85 }
        
        // Sentiment
        if let sentiment = sentiment {
            if case .strongBuy = signal, sentiment.aggregateScore < -0.3 { return .neutral(confidence: 0) } // Killed
            if case .strongSell = signal, sentiment.aggregateScore > 0.3 { return .neutral(confidence: 0) } // Killed
        }
        
        // Reconstruct Signal
        switch signal {
        case .strongBuy(_, let p): return .strongBuy(confidence: confidence, price: p)
        case .strongSell(_, let p): return .strongSell(confidence: confidence, price: p)
        default: return signal
        }
    }
    
    private func applyVolatilityBuffer(to signal: TradeSignal) -> TradeSignal {
        let now = Date()
        let riskyEvents = upcomingEvents.filter { event in
            return event.impact == .high && abs(event.date.timeIntervalSince(now)) < 3600
        }
        if !riskyEvents.isEmpty {
            switch signal {
            case .strongBuy(let c, let p): return .strongBuy(confidence: c * 0.5, price: p)
            case .strongSell(let c, let p): return .strongSell(confidence: c * 0.5, price: p)
            default: return signal
            }
        }
        return signal
    }
    
    private func autoConfigure(symbol: String) {
        if overrideConfig == nil {
             let isCrypto = ["BTC", "ETH", "SOL"].contains(where: { symbol.contains($0) })
             if isCrypto && config.rsiPeriod != 9 { self.config = .crypto }
             else if !isCrypto && config.rsiPeriod != 14 { self.config = .stock }
        }
    }
    
    // MARK: - Math
    
    private func projectEMA(current: Double, prev: Double?, period: Int) -> Double {
        let k = 2.0 / Double(period + 1)
        guard let p = prev else { return current }
        return (current * k) + (p * (1.0 - k))
    }
    
    private func calculateRSI(prices: [Double], period: Int) -> Double? {
        guard prices.count >= period + 1 else { return nil }
        let window = prices.suffix(period + 1)
        let changes = zip(window.dropFirst(), window).map { $0 - $1 }
        
        var gains = 0.0, losses = 0.0
        for change in changes {
            if change > 0 { gains += change } else { losses += abs(change) }
        }
        if losses == 0 { return 100.0 }
        let rs = (gains/Double(period)) / (losses/Double(period))
        return 100.0 - (100.0 / (1.0 + rs))
    }
    
    // Mission 48: Local State Update Logic (Moved from Types to Actor to avoid Isolation Issues)
    private func updateTimeframeState(state: inout TimeframeState, price: Double, volume: Double, time: Date, interval: TimeInterval) -> Bool {
        // Check if we need to close current candle
        if let current = state.currentCandle {
            if time.timeIntervalSince(current.timestamp) >= interval {
                // Close Candle
                var closed = current
                closed.close = price // Ensure close price matches tick
                state.candles.append(closed)
                
                // Maintain Buffer (e.g., 200 candles)
                if state.candles.count > 200 { state.candles.removeFirst() }
                
                // Start New
                state.currentCandle = Candle(timestamp: time, open: price, high: price, low: price, close: price, volume: volume)
                return true
            } else {
                // Update Current
                state.currentCandle?.high = max(current.high, price)
                state.currentCandle?.low = min(current.low, price)
                state.currentCandle?.close = price
                state.currentCandle?.volume += volume
                return false
            }
        } else {
            // First Tick
            state.currentCandle = Candle(timestamp: time, open: price, high: price, low: price, close: price, volume: volume)
            return false
        }
    }
}
