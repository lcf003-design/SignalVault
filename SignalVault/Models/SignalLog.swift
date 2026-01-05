import SwiftData
import Foundation

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
