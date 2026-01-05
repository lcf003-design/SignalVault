import SwiftData
import Foundation
import SwiftUI

@ModelActor
actor TradeExecutor {
    
    // Execute a trade on a background context
    func executeTrade(accountID: UUID, symbol: String, price: Double, quantity: Double, isLong: Bool, stopLoss: Double? = nil, takeProfit: Double? = nil, slippage: Double = 0.0005, assetType: AssetType = .stock, strike: Double? = nil, expiry: Date? = nil, optionType: OptionType? = nil) throws {
        // 1. Fetch the Account
        let descriptor = FetchDescriptor<Account>(predicate: #Predicate { $0.id == accountID })
        guard let account = try modelContext.fetch(descriptor).first else {
            throw TradeError.accountNotFound
        }
        
        // 2. Apply Slippage (Simulator)
        let executionPrice: Double
        if isLong {
            executionPrice = price * (1 + slippage)
        } else {
            executionPrice = price * (1 - slippage)
        }
        
        // 3. Calculate Cost
        let cost = executionPrice * quantity
        
        // 4. Validate Funds
        guard account.currentBalance >= cost else {
            throw TradeError.insufficientFunds
        }
        
        // 5. Deduct Funds
        account.currentBalance -= cost
        
        // 6. Create Position
        let position = Position(
            symbol: symbol,
            entryPrice: executionPrice,
            quantity: quantity,
            isLong: isLong,
            stopLossPrice: stopLoss,
            takeProfitPrice: takeProfit,
            assetType: assetType,
            strikePrice: strike,
            expirationDate: expiry,
            optionType: optionType
        )
        modelContext.insert(position)
        
        // 7. Save
        try modelContext.save()
        print("✅ Trade Executed: \(symbol) @ \(executionPrice) (Qty: \(quantity)) [Slippage: \(slippage*100)%]")
    }

    // Close a specific position
    func closePosition(positionID: UUID, price: Double, reason: String = "Manual", slippage: Double = 0.0005) throws {
        // 1. Fetch Position
        let descriptor = FetchDescriptor<Position>(predicate: #Predicate { $0.id == positionID })
        guard let position = try modelContext.fetch(descriptor).first else {
             throw TradeError.positionNotFound
        }
        
        guard position.isOpen else { throw TradeError.positionAlreadyClosed }
        
        // 2. Access Account
        let accountDescriptor = FetchDescriptor<Account>()
        guard let account = try modelContext.fetch(accountDescriptor).first else {
            throw TradeError.accountNotFound
        }
        
        // 3. Apply Slippage to Exit
        let executionPrice: Double
        if position.isLong {
            executionPrice = price * (1 - slippage) // Sell lower
        } else {
            executionPrice = price * (1 + slippage) // Buy higher
        }
        
        // 4. Calculate PnL
        let costBasis = position.quantity * position.entryPrice
        let pnl: Double
        
        if position.isLong {
            pnl = (executionPrice - position.entryPrice) * position.quantity
        } else {
            pnl = (position.entryPrice - executionPrice) * position.quantity
        }
        
        let returnedCapital = costBasis + pnl
        
        // 5. Update State
        account.currentBalance += returnedCapital
        position.isOpen = false
        position.exitPrice = executionPrice
        position.exitDate = Date()
        position.realizedPnL = pnl
        
        try modelContext.save()
        print("✅ Position Closed: \(position.symbol) @ \(executionPrice) [Reason: \(reason), PnL: \(String(format: "%.2f", pnl))]")
    }
}

enum TradeError: Error {
    case accountNotFound
    case insufficientFunds
    case positionNotFound
    case positionAlreadyClosed
}
