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
    
    // Scrubbing State
    var selectedDate: Date?
    var selectedPrice: Double?
    
    // Services
    private let marketService: MarketDataProvider
    private let engine: SignalEngine
    
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
            let stream = await marketService.streamQuotes(for: ["BTC"])
            
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
                        
                        // Log for Mirror/Performance
                        // Note: Using a MainActor isolated context here might be tricky if not passed in.
                        // Ideally we have a 'SignalLoggerService'.
                        // For MVP, we'll dispatch to a ModelActor or assume View context availability if added?
                        // MarketChartViewModel is usually Observale, non-actor.
                        // Let's print for now OR add ModelContext dependency?
                        // "Update MarketChartViewModel to Log Signals" -> Needs ModelContext.
                        // We will defer the actual DB insert to a method we can call safely or inject.
                        
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
            }
        }
    }
    
    func stop() {
        isRunning = false
        dataTask?.cancel()
        dataTask = nil
    }
}
