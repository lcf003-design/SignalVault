import Foundation

struct MarketTick: Sendable {
    let symbol: String
    let price: Double
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
