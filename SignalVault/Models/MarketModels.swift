import Foundation

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
