import Foundation
import SwiftUI
import Observation

@MainActor
@Observable
class MarketChartViewModel {
    // Data Buffers
    var ticks: [MarketTick] = []
    var signals: [TradeSignal] = []
    
    // UI State
    var currentPrice: Double = 0.0
    var activeSignal: TradeSignal?
    
    // Mission 11: Multi-Asset Support
    var selectedSymbol: String = "BTC"
    
    // Scrubbing State
    var selectedDate: Date?
    var selectedPrice: Double?
    
    // Services
    private let marketService: MarketDataProvider
    private let engine: SignalEngine
    private let projectionEngine = ProjectionEngine() // Mission 13
    
    // Mission 13: Oracle State
    var projection: ProjectionResult?
    var chartAlert: String?
    
    // Config
    private let maxPoints = 500 // Limit for performance
    
    init(marketService: MarketDataProvider? = nil, engine: SignalEngine? = nil) {
        if let service = marketService {
            self.marketService = service
        } else {
            // Auto-switch to Live if Key is present
            if Secrets.polygonAPIKey != "YOUR_POLYGON_API_KEY" && !Secrets.polygonAPIKey.isEmpty {
                self.marketService = LiveMarketService()
                print("🚀 LIVE DATA ACTIVATED (Polygon.io)")
            } else {
                self.marketService = MockMarketService()
                print("⚠️ No API Key found in Secrets.swift. Using MOCK DATA.")
            }
        }
        self.engine = engine ?? SignalEngine()
    }
    
    private var dataTask: Task<Void, Never>?
    var isRunning: Bool = false
    
    func changeSymbol(to newSymbol: String) {
        stop()
        selectedSymbol = newSymbol
        
        // Reset buffers
        ticks.removeAll()
        signals.removeAll()
        currentPrice = 0.0
        activeSignal = nil
        
        // Mission 12: Reset AI Engine
        Task {
            await engine.reset()
            start()
        }
    }
    
    func toggleSimulation() {
        if isRunning {
            stop()
        } else {
            start()
        }
    }

    func start() {
        guard !isRunning else { return }
        isRunning = true
        
        dataTask = Task {
            try? await marketService.connect()
            let stream = await marketService.streamQuotes(for: [selectedSymbol])
            
            for await tick in stream {
                if Task.isCancelled { break }
                
                // 1. Update Price
                self.currentPrice = tick.price
                self.ticks.append(tick)
                if self.ticks.count > maxPoints {
                    self.ticks.removeFirst()
                }
                
                // 2. Process Signal
                if let newSignal = await engine.process(tick: tick) {
                    self.signals.append(newSignal)
                    self.activeSignal = newSignal
                    
                    // Audio Announcement
                    switch newSignal {
                    case .strongBuy, .strongSell:
                        AudioService.shared.announceSignal(symbol: tick.symbol, price: tick.price, signal: newSignal)
                    default:
                        break
                    }
                    
                    // Trigger Haptics for new signal
                    let generator = UINotificationFeedbackGenerator()
                    switch newSignal {
                    case .strongBuy, .strongSell:
                        generator.notificationOccurred(.success)
                    default: break
                    }
                    
                    // Auto-hide old signals from "Active" badge after 3 seconds
                    Task {
                        try? await Task.sleep(for: .seconds(3))
                        if self.activeSignal != nil {
                            // Only clear if it's still the same one... simplistic logic for MVP
                            // self.activeSignal = nil 
                        }
                    }
                }
                
                // 3. Update Oracle Projection
                // Get last 50 points for regression
                if self.ticks.count >= 30 {
                   let recentPrices = self.ticks.suffix(50).map { $0.price }
                   let result = await projectionEngine.calculateProjection(recentPrices: recentPrices)
                   self.projection = result
                   
                   // Check for Price Stretched (Mean Reversion)
                   if let res = result, abs(res.currentDeviationSigma) > 2.5 {
                       self.chartAlert = "PRICE STRETCHED: \(String(format: "%.1f", res.currentDeviationSigma))σ"
                       // Haptic for danger
                       if abs(res.currentDeviationSigma) > 3.0 { // Extreme
                           let gen = UINotificationFeedbackGenerator()
                           gen.notificationOccurred(.warning)
                       }
                   } else {
                       self.chartAlert = nil
                   }
                }
            }
        }
    }
    
    func stop() {
        isRunning = false
        dataTask?.cancel()
        dataTask = nil
    }
}
