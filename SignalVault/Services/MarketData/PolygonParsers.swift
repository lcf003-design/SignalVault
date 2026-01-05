import Foundation

// MARK: - Generic Polygon Message
enum PolygonMessage: Decodable, Sendable {
    case status(PolygonStatus)
    case trade(PolygonTrade)
    case cryptoTrade(PolygonCryptoTrade)
    case unknown
    
    private enum CodingKeys: String, CodingKey {
        case ev // Event Type
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let eventType = try container.decode(String.self, forKey: .ev)
        
        switch eventType {
        case "status":
            let status = try PolygonStatus(from: decoder)
            self = .status(status)
        case "T": // Stocks Trade
            let trade = try PolygonTrade(from: decoder)
            self = .trade(trade)
        case "XT": // Crypto Trade
            let trade = try PolygonCryptoTrade(from: decoder)
            self = .cryptoTrade(trade)
        default:
            self = .unknown
        }
    }
}

// MARK: - Specific Payloads

struct PolygonStatus: Decodable {
    let status: String
    let message: String
}

struct PolygonTrade: Decodable {
    let sym: String
    let p: Double // Price
    let t: Int64  // Timestamp (Unix MS)
}

struct PolygonCryptoTrade: Decodable {
    let pair: String
    let p: Double
    let t: Int64
}

// MARK: - Mapper Implementation
extension PolygonMessage {
    nonisolated func toMarketTick() -> MarketTick? {
        switch self {
        case .trade(let t):
            return MarketTick(
                symbol: t.sym,
                price: t.p,
                timestamp: Date(timeIntervalSince1970: TimeInterval(t.t) / 1000.0)
            )
        case .cryptoTrade(let t):
            return MarketTick(
                symbol: t.pair, // e.g. "BTC-USD"
                price: t.p,
                timestamp: Date(timeIntervalSince1970: TimeInterval(t.t) / 1000.0)
            )
        default:
            return nil
        }
    }
}
