import SwiftData
import Foundation
import SwiftUI

@ModelActor
actor TradeExecutor {
    
    // Execute a trade on a background context
    // Execute a trade with Smart Netting (Close Opposite First)
    func executeTrade(accountID: UUID, symbol: String, price: Double, quantity: Double, isLong: Bool, stopLoss: Double? = nil, takeProfit: Double? = nil, slippage: Double = 0.0005, assetType: AssetType = .stock, strike: Double? = nil, expiry: Date? = nil, optionType: OptionType? = nil) throws {
        
        // 1. Fetch Open Positions for Symbol
        let descriptor = FetchDescriptor<Position>(predicate: #Predicate { $0.symbol == symbol && $0.isOpen == true })
        let existingPositions = try modelContext.fetch(descriptor)
        
        // 2. Identify Opposing Positions
        // If we represent a BUY (Long), we look for Shorts to cover.
        // If we represent a SELL (Short), we look for Longs to sell.
        let opposingPositions = existingPositions.filter { $0.isLong != isLong }
        
        var quantityRemaining = quantity
        
        // 3. Close Opposing Positions (FIFO)
        for position in opposingPositions {
            guard quantityRemaining > 0 else { break }
            
            // For MVP, we assume 1.0 quantity matching or full closure
            // In a real app we'd handle partial closes. Here we just close the whole position if it matches or exceeds.
            // Simplified: Close the opposing position completely.
            try closePosition(positionID: position.id, price: price, reason: "Signal Flip", slippage: slippage)
            
            // Deduct roughly 1.0 (MVP simplification)
            quantityRemaining -= 1.0
        }
        
        // 4. If Quantity Remains, Open New Position
        if quantityRemaining > 0 {
            // Fetch Account to ensure funds (re-fetch to be safe)
            let accDescriptor = FetchDescriptor<Account>(predicate: #Predicate { $0.id == accountID })
            guard let account = try modelContext.fetch(accDescriptor).first else { throw TradeError.accountNotFound }
            
            // Calculate Execution Price
            let executionPrice = isLong ? price * (1 + slippage) : price * (1 - slippage)
            let cost = executionPrice * quantityRemaining
            
            // Validate Funds
            guard account.currentBalance >= cost else { throw TradeError.insufficientFunds }
            
            // Deduct
            account.currentBalance -= cost
            
            // Create
            let position = Position(
                symbol: symbol,
                entryPrice: executionPrice,
                quantity: quantityRemaining,
                isLong: isLong,
                stopLossPrice: stopLoss,
                takeProfitPrice: takeProfit,
                assetType: assetType,
                strikePrice: strike,
                expirationDate: expiry,
                optionType: optionType
            )
            modelContext.insert(position)
            
            print("✅ Trade Executed (New): \(symbol) @ \(executionPrice) (Qty: \(quantityRemaining))")
        } else {
             print("ℹ️ Trade Executed (Netting Only): Closed opposing positions.")
        }
        
        try modelContext.save()
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
