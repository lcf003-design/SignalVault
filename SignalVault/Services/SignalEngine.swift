import Foundation

actor SignalEngine {
    // MARK: - State
    private var prices: [Double] = []
    
    // EMA State (Stored to ensure O(1) updates)
    private var prevEMA12: Double?
    private var prevEMA26: Double?
    private var prevSignalLine: Double? // 9-period EMA of MACD
    
    // RSI State
    private var previousRSI: Double?
    
    // Config
    private let rsiPeriod = 14
    private let macdFast = 12
    private let macdSlow = 26
    private let signalPeriod = 9
    
    // MARK: - Processing
    func process(tick: MarketTick) -> TradeSignal? {
        let price = tick.price
        prices.append(price)
        
        // Mantain buffer just for RSI lookback (need ~14+1 periods)
        if prices.count > 100 { prices.removeFirst() }
        
        // 1. Update EMAs & MACD
        let currentEMA12 = updateEMA(currentPrice: price, previousEMA: prevEMA12, period: macdFast)
        let currentEMA26 = updateEMA(currentPrice: price, previousEMA: prevEMA26, period: macdSlow)
        
        prevEMA12 = currentEMA12
        prevEMA26 = currentEMA26
        
        guard let ema12 = currentEMA12, let ema26 = currentEMA26 else { return nil }
        
        let macdLine = ema12 - ema26
        
        // 2. Update Signal Line (EMA of MACD)
        let currentSignalLine = updateEMA(currentPrice: macdLine, previousEMA: prevSignalLine, period: signalPeriod)
        prevSignalLine = currentSignalLine
        
        guard let signalLine = currentSignalLine else { return nil }
        
        // 3. Update RSI
        guard let currentRSI = calculateRSI(period: rsiPeriod) else { return nil }
        
        // 4. Logic: Dual-Confirmation
        var tradeSignal: TradeSignal?
        
        if let prevRSI = previousRSI {
            let isBullishMACD = macdLine > signalLine
            let isBearishMACD = macdLine < signalLine
            
            // BUY: MACD Bullish + RSI crosses 30 from below
            if isBullishMACD && prevRSI < 30 && currentRSI >= 30 {
                tradeSignal = .strongBuy(confidence: 0.95, price: price)
            }
            // SELL: MACD Bearish + RSI crosses 70 from above
            else if isBearishMACD && prevRSI > 70 && currentRSI <= 70 {
                tradeSignal = .strongSell(confidence: 0.95, price: price)
            }
        }
        
        previousRSI = currentRSI
        return tradeSignal
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
