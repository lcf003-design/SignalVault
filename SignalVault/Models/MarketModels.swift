import Foundation
import SwiftUI

enum AssetType: String, Codable {
    case stock
    case option
    case crypto // Mission 12
}

struct MarketTick: Sendable {
    let symbol: String
    let price: Double
    let volume: Double // Mission 12: Conviction
    let timestamp: Date
}

enum TradeSignal: Sendable, Hashable {
    case strongBuy(confidence: Double, price: Double)
    case neutral(confidence: Double)
    case strongSell(confidence: Double, price: Double)
    
    var isBuy: Bool {
        switch self {
        case .strongBuy: return true
        default: return false
        }
    }
    
    var isSell: Bool {
        switch self {
        case .strongSell: return true
        default: return false
        }
    }
}

enum OptionType: String, Codable, Sendable {
    case call
    case put
}

struct Greeks: Sendable, Codable {
    var delta: Double
    var theta: Double
    var vega: Double
    var gamma: Double
    var rho: Double
}

struct OptionContract: Sendable, Codable {
    let symbol: String
    let strikePrice: Double
    let expirationDate: Date
    let type: OptionType
    let impliedVolatility: Double // e.g. 0.20 for 20%
}

// Mission 13: The Oracle
struct ProjectionPoint: Identifiable, Sendable {
    let id = UUID()
    let indexOffset: Int // 1, 2, 3... 30
    let price: Double
    let upper1SD: Double
    let lower1SD: Double
    let upper2SD: Double
    let lower2SD: Double
}

struct ProjectionResult: Sendable {
    let points: [ProjectionPoint]
    let rSquared: Double
    let slope: Double
    let isReliable: Bool // Based on R-squared threshold
    let currentDeviationSigma: Double // Z-Score of current price (Mission 13)
}

// Mission 14: Backtest Engine
enum TradeOutcome: String, Codable, Sendable {
    case win = "WIN"
    case loss = "LOSS"
    case hitSL = "SL"
    case hitTP = "TP"
    case open = "OPEN"
}

struct BacktestTrade: Identifiable, Sendable {
    let id = UUID()
    let entryDate: Date
    let entryPrice: Double
    let exitDate: Date
    let exitPrice: Double
    let isLong: Bool
    let pnl: Double // Realized PnL in dollars for fixed size, or percentage
    let pnlPercent: Double
    let outcome: TradeOutcome
}

struct BacktestResult: Sendable, Identifiable {
    let id = UUID()
    let equityCurve: [Double] // For charting
    let finalBalance: Double
    let totalReturnPercentage: Double
    let winRate: Double
    let maxDrawdown: Double
    let trades: [BacktestTrade]
    let totalTrades: Int
    let avgWin: Double
    let avgLoss: Double
    let expectancyRatio: Double
    let configName: String
}

// Mission 15: Sentiment Intelligence
struct NewsItem: Identifiable, Sendable {
    let id = UUID()
    let headline: String
    let source: String
    let url: String?
    let timestamp: Date
    let sentimentScore: Double // -1.0 (Panic) to +1.0 (Euphoria)
}

struct SentimentAnalysisResult: Sendable {
    let aggregateScore: Double // Weighted Average
    let label: String // "Bullish", "Bearish", "Neutral"
    let divergenceDetected: Bool // Technical vs Sentiment Conflict
    let headlines: [NewsItem]
}

// Mission 16: Global Macro Models
enum MarketRegime: String, Sendable, Codable {
    case riskOn = "RISK ON"
    case riskOff = "RISK OFF"
    case neutral = "NEUTRAL"
}

struct MacroData: Sendable {
    let fedRate: Double
    let cpiYearly: Double
    let unemploymentRate: Double
    let treasury10Y: Double
    let treasury2Y: Double
    let nextFedMeeting: Date
    let isYieldCurveInverted: Bool // Stored property
    
    nonisolated init(fedRate: Double, cpiYearly: Double, unemploymentRate: Double, treasury10Y: Double, treasury2Y: Double, nextFedMeeting: Date) {
        self.fedRate = fedRate
        self.cpiYearly = cpiYearly
        self.unemploymentRate = unemploymentRate
        self.treasury10Y = treasury10Y
        self.treasury2Y = treasury2Y
        self.nextFedMeeting = nextFedMeeting
        self.isYieldCurveInverted = treasury2Y > treasury10Y
    }
}

// Mission 34: Multi-Timeframe Consensus
enum TimeframeAlignment: String, Sendable, Codable {
    case bullish = "Bullish" // Green Cloud
    case bearish = "Bearish" // Red Cloud
    case mixed = "Mixed"     // Yellow Cloud
    
    var color: Color {
        switch self {
        case .bullish: return .green
        case .bearish: return .red
        case .mixed: return .yellow
        }
    }
}

struct SignalContext: Sendable {
    let tradeSignal: TradeSignal?
    let alignment: TimeframeAlignment
    let isDivergenceDetected: Bool
    
    // Mission 36: Institutional VWAP
    var vwap: Double? // Current Session VWAP
    var vwapDistance: Double? // % Distance
    
    // Mission 36 Part 2: The ORB Layer
    var openingRangeHigh: Double?
    var openingRangeLow: Double?
    var isConsolidating: Bool = false
    
    var yesterdayHigh: Double? // Session Pivot
    var yesterdayLow: Double?  // Session Pivot
}


// Mission 33: The Alpha Scanner
// Mission 33 & 35: The Alpha Scanner & AI Market Pulse
struct ScannedAsset: Identifiable, Sendable, Hashable {
    let id = UUID()
    let symbol: String
    let name: String
    let price: Double
    let changePercent: Double
    
    // Mission 35: Kai Score Engine
    let kaiScore: Int // 0-100 Score
    let volumeStatus: VolumeStatus
    let aiSummary: String // "NVDA is surging..."
    let assetType: AssetType // For filtering
    
    // AI Conviction (Legacy / Compat)
    let convictionScore: Double // 0.0 to 1.0 (90%+ Glows)
    let signalType: TradeSignal // Stores the exact signal enum
    let isGlowing: Bool // UI Helper
    
    // Helper for List View
    var signalColor: Color {
        if convictionScore >= 0.90 {
            return signalType.isBuy ? .green : .red
        }
        return .gray
    }
}

// Mission 35: Volume Status
enum VolumeStatus: String, Sendable, Codable {
    case low = "Low"
    case normal = "Normal"
    case high = "High"
    case ultra = "Ultra" // "Gamma Squeeze" levels
}





