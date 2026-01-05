import SwiftData
import Foundation

@Model
final class Account {
    var id: UUID = UUID()
    var currentBalance: Double
    var startingCapital: Double
    var totalProfit: Double
    
    init(startingCapital: Double = 100_000.0) {
        self.startingCapital = startingCapital
        self.currentBalance = startingCapital
        self.totalProfit = 0.0
    }
}
