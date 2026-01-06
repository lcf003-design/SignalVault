import SwiftData
import Foundation

// Mission 9: Schema Versioning
enum SchemaV1: VersionedSchema {
    static var versionIdentifier = Schema.Version(1, 0, 0)
    
    static var models: [any PersistentModel.Type] {
        [Account.self, Position.self, SignalLog.self]
    }
    
    @Model
    final class Account {
        var id: UUID = UUID()
        var currentBalance: Double
        var startingCapital: Double
        var totalProfit: Double
        
        // Mission 42: Safety Lock
        var maxDailyLossPercent: Double // e.g. 0.02 for 2%
        var dailyRealizedPnL: Double
        var lastResetDate: Date?
        var isSafetyLockEnabled: Bool // Mission 42
        
        init(startingCapital: Double = 100_000.0) {
            self.startingCapital = startingCapital
            self.currentBalance = startingCapital
            self.totalProfit = 0.0
            
            // Defaults
            self.maxDailyLossPercent = 0.05 // 5% default
            self.dailyRealizedPnL = 0.0
            self.lastResetDate = Date()
            self.isSafetyLockEnabled = false
        }
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
    
    @Model
    final class SignalLog {
        var id: UUID = UUID()
        var symbol: String
        var signalType: String // "Strong Buy", "Strong Sell"
        var price: Double
        var timestamp: Date
        
        init(symbol: String, signalType: String, price: Double, timestamp: Date = Date()) {
            self.symbol = symbol
            self.signalType = signalType
            self.price = price
            self.timestamp = timestamp
        }
    }
}
