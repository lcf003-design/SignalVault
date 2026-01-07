import Foundation

// MARK: - Core Definitions
// MARK: - Core Definitions
// MARK: - Core Definitions
enum Timeframe: String, CaseIterable, Sendable, Hashable {
    case m1 = "1m"
    case m5 = "5m"
    case m15 = "15m"
}

// State Container for a Single Timeframe
struct TimeframeState: Sendable {
    var candles: [Candle] = []
    var currentCandle: Candle?
    
    // Technicals
    var prevEMA12: Double?
    var prevEMA26: Double?
    var prevSignalLine: Double?
    var prevRSI: Double?
    var prevPriceHigh: Double = 0
    var prevRSIHigh: Double = 0
    
    nonisolated init() {}
    
    // Latest Signal
    var latestSignal: TradeSignal = .neutral(confidence: 0.0)
    
    // Mission 34: Divergence Tracking
    var divergences: [DivergenceEvent] = []
    
    mutating func reset() {
        candles.removeAll()
        currentCandle = nil
        prevEMA12 = nil
        prevEMA26 = nil
        prevSignalLine = nil
        prevRSI = nil
        prevPriceHigh = 0
        prevRSIHigh = 0
        latestSignal = .neutral(confidence: 0.0)
        divergences.removeAll()
    }
}




struct DivergenceEvent {
    let type: DivergenceType
    let timeframe: Timeframe
    let timestamp: Date
}

enum DivergenceType {
    case bullish
    case bearish
}
