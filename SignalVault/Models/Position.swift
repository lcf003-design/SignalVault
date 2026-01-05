import SwiftData
import Foundation

enum AssetType: String, Codable {
    case stock
    case option
}

@Model
final class Position {
    var id: UUID = UUID()
    var symbol: String
    var entryPrice: Double
    var quantity: Double
    var isLong: Bool
    var timestamp: Date
    var isOpen: Bool
    var stopLossPrice: Double?
    var takeProfitPrice: Double?
    
    // Option Specifics
    var assetType: AssetType = AssetType.stock
    var strikePrice: Double?
    var expirationDate: Date?
    var optionType: OptionType?
    var impliedVolatilityAtEntry: Double?
    
    // Performance Metrics
    var exitPrice: Double?
    var exitDate: Date?
    var realizedPnL: Double?
    
    init(symbol: String, entryPrice: Double, quantity: Double, isLong: Bool = true, timestamp: Date = Date(), isOpen: Bool = true, stopLossPrice: Double? = nil, takeProfitPrice: Double? = nil, assetType: AssetType = .stock, strikePrice: Double? = nil, expirationDate: Date? = nil, optionType: OptionType? = nil, impliedVolatilityAtEntry: Double? = nil) {
        self.symbol = symbol
        self.entryPrice = entryPrice
        self.quantity = quantity
        self.isLong = isLong
        self.timestamp = timestamp
        self.isOpen = isOpen
        self.stopLossPrice = stopLossPrice
        self.takeProfitPrice = takeProfitPrice
        self.assetType = assetType
        self.strikePrice = strikePrice
        self.expirationDate = expirationDate
        self.optionType = optionType
        self.impliedVolatilityAtEntry = impliedVolatilityAtEntry
    }
}
