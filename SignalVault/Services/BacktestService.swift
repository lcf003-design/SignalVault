import Foundation

actor BacktestService {
    
    // Simulate History Generation (since we are in Mock mode)
    // In a real app, this would fetch from Polygon Aggregates API
    func generateHistory(symbol: String, limit: Int = 1000) -> [MarketTick] {
        var ticks: [MarketTick] = []
        var price = 100.0
        if symbol == "BTC" { price = 95000.0 }
        
        // Random Walk with Trend
        let startDate = Date().addingTimeInterval(-TimeInterval(limit * 300)) // 5 min bars?
        
        for i in 0..<limit {
            let date = startDate.addingTimeInterval(TimeInterval(i * 300))
            let change = Double.random(in: -0.005...0.0055) // Slightly bullish bias
            price = price * (1.0 + change)
            
            // Random Volume (Mission 12)
            let vol = Double.random(in: 100...10000)
            
            ticks.append(MarketTick(symbol: symbol, price: price, volume: vol, timestamp: date))
        }
        return ticks
    }
    
    func runBacktest(symbol: String, config: EngineConfig? = nil) async -> BacktestResult {
        let history = generateHistory(symbol: symbol, limit: 1000)
        let engine = SignalEngine()
        if let c = config { await engine.setOverrideConfig(c) }
        
        var trades: [BacktestTrade] = []
        var activeTrade: (entry: Double, isLong: Bool, date: Date, size: Double)?
        
        var balance = 100_000.0
        var equityCurve: [Double] = [balance]
        var peakBalance = balance
        var maxDrawdown = 0.0
        
        // Settings
        let tpPercent = 0.03
        let slPercent = 0.01
        
        for tick in history {
            // Process Tick
            let signal = await engine.process(tick: tick)
            
            // Manage Active Position
            if let trade = activeTrade {
                let currentPrice = tick.price
                
                // Check Exist
                var closeTrade = false
                var pnl = 0.0
                var outcome: TradeOutcome = .open
                
                if trade.isLong {
                    let tpPrice = trade.entry * (1.0 + tpPercent)
                    let slPrice = trade.entry * (1.0 - slPercent)
                    
                    if currentPrice >= tpPrice {
                        pnl = (currentPrice - trade.entry) * trade.size
                        outcome = .hitTP
                        closeTrade = true
                    } else if currentPrice <= slPrice {
                        pnl = (currentPrice - trade.entry) * trade.size
                        outcome = .hitSL
                        closeTrade = true
                    }
                }
                
                if closeTrade {
                    let exitPrice = tick.price
                    let pnlPct = (exitPrice - trade.entry) / trade.entry
                    
                    let finalizedTrade = BacktestTrade(
                        entryDate: trade.date,
                        entryPrice: trade.entry,
                        exitDate: tick.timestamp,
                        exitPrice: exitPrice,
                        isLong: trade.isLong,
                        pnl: pnl,
                        pnlPercent: pnlPct,
                        outcome: outcome
                    )
                    trades.append(finalizedTrade)
                    balance += pnl
                    activeTrade = nil
                }
                
            } else {
                // Check Entry
                if let sig = signal, case .strongBuy = sig {
                    let quantity = balance / tick.price
                    activeTrade = (entry: tick.price, isLong: true, date: tick.timestamp, size: quantity)
                }
            }
            
            // Track Equity
            var currentEquity = balance
            if let t = activeTrade {
                currentEquity = balance + (tick.price - t.entry) * t.size
            }
            equityCurve.append(currentEquity)
            
            // Drawdown Calc
            if currentEquity > peakBalance {
                peakBalance = currentEquity
            }
            let dd = (peakBalance - currentEquity) / peakBalance
            if dd > maxDrawdown {
                maxDrawdown = dd
            }
        }
        
        // Final Stats
        let wins = trades.filter { $0.pnl > 0 }
        let losses = trades.filter { $0.pnl <= 0 }
        let winRate = Double(wins.count) / Double(trades.count > 0 ? trades.count : 1)
        
        let totalWin = wins.reduce(0) { $0 + $1.pnl }
        let totalLoss = losses.reduce(0) { $0 + $1.pnl } // is negative
        
        let avgWin = wins.isEmpty ? 0 : totalWin / Double(wins.count)
        let avgLoss = losses.isEmpty ? 0 : abs(totalLoss) / Double(losses.count)
        
        let expectancy = (winRate * avgWin) - ((1.0 - winRate) * avgLoss)
        
        let totalReturn = (balance - 100_000.0) / 100_000.0
        
        return BacktestResult(
            equityCurve: equityCurve,
            finalBalance: balance,
            totalReturnPercentage: totalReturn,
            winRate: winRate,
            maxDrawdown: maxDrawdown,
            trades: trades,
            totalTrades: trades.count,
            avgWin: avgWin,
            avgLoss: avgLoss,
            expectancyRatio: expectancy,
            configName: config == nil ? "Auto" : "Custom RSI:\(config!.rsiPeriod)"
        )
    }
    
    // Optimization (Mission 14 Part 4)
    func findBestSettings(symbol: String) async -> [BacktestResult] {
        let configs = [
            EngineConfig.stock, // Def stock (14)
            EngineConfig.crypto, // Def crypto (9)
            EngineConfig(rsiPeriod: 7, macdFast: 6, macdSlow: 18, signalPeriod: 9), // Scalper
            EngineConfig(rsiPeriod: 21, macdFast: 12, macdSlow: 26, signalPeriod: 9), // Trend Follower
            EngineConfig(rsiPeriod: 5, macdFast: 5, macdSlow: 35, signalPeriod: 5) // Aggressive
        ]
        
        var results: [BacktestResult] = []
        
        // Parallel Run
        await withTaskGroup(of: BacktestResult.self) { group in
            for cfg in configs {
                group.addTask {
                    await self.runBacktest(symbol: symbol, config: cfg)
                }
            }
            for await result in group {
                results.append(result)
            }
        }
        
        // Sort by PnL
        return results.sorted { $0.totalReturnPercentage > $1.totalReturnPercentage }
    }
}
