import Foundation
import SwiftUI
import Observation

@MainActor
@Observable
class MarketChartViewModel {
    // Data Buffers
    var ticks: [MarketTick] = []
    var candles: [Candle] = [] // Mission 38
    var signals: [TradeSignal] = [] // Legacy Buffer
    var signalHistory: [SignalEvent] = [] // Mission 39: Persistent History
    
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
    private let sentimentService = SentimentService() // Mission 15
    
    // Mission 13: Oracle State
    var projection: ProjectionResult?
    var chartAlert: String?
    
    // Mission 15: Sentiment State
    var sentiment: SentimentAnalysisResult?
    
    // Mission 34: Sniper Scope State
    var trendAlignment: TimeframeAlignment = .mixed
    var divergenceAlert: Bool = false
    
    // Mission 36: VWAP State
    var vwap: Double?
    var vwapDistance: Double?
    
    // Mission 36 Part 2: ORB & Pivot State
    var openingRangeHigh: Double?
    var openingRangeLow: Double?
    var yesterdayHigh: Double?
    var yesterdayLow: Double?
    var isConsolidating: Bool = false
    
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
            self.signalHistory.removeAll()
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
                
                // Mission 38: Aggregate Candle
                self.processTickIntoCandle(tick)
                
                // 2. Process Signal (Mission 34: Context Aware)
                let context = await self.engine.process(tick: tick)
                
                // Update Cloud
                self.trendAlignment = context.alignment
                self.divergenceAlert = context.isDivergenceDetected
                
                // Mission 36: Update VWAP & ORB
                self.vwap = context.vwap
                self.vwapDistance = context.vwapDistance
                self.openingRangeHigh = context.openingRangeHigh
                self.openingRangeLow = context.openingRangeLow
                self.yesterdayHigh = context.yesterdayHigh
                self.yesterdayLow = context.yesterdayLow
                self.isConsolidating = context.isConsolidating
                
                if let newSignal = context.tradeSignal {
                    self.signals.append(newSignal)
                    self.activeSignal = newSignal
                    
                    // Mission 39: History
                    let event = SignalEvent(signal: newSignal, timestamp: tick.timestamp, price: tick.price)
                    self.signalHistory.append(event)
                    
                    // Audio Announcement (Mission 34)
                    switch newSignal {
                    case .strongBuy, .strongSell:
                        AudioService.shared.announceSignal(symbol: tick.symbol, price: tick.price, signal: newSignal)
                        
                        // Sniper Sound?
                        if context.alignment == .bullish || context.alignment == .bearish {
                             // "SNIPER EXECUTION" sound
                             AudioService.shared.playSniperSound()
                             HapticManager.shared.playImpact()
                        } else {
                            // Standard Haptic
                            let generator = UINotificationFeedbackGenerator()
                            generator.notificationOccurred(.success)
                        }
                        
                    default:
                        break
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
                   let result = await self.projectionEngine.calculateProjection(recentPrices: recentPrices)
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
    
    // Mission 32: Economic Events
    var economicEvents: [EconomicEvent] = []
    private let macroService = MacroService()
    
    // Mission 15: Sentiment Integration
    func fetchSentiment() async {
        let result = await sentimentService.fetchSentiment(for: selectedSymbol)
        self.sentiment = result
        await engine.updateSentiment(result)
    }
    
    // Mission 16 & 32: Macro Integration
    func updateRegime(_ regime: MarketRegime) async {
        await engine.updateRegime(regime)
    }
    
    func fetchEconomicEvents() async {
        let events = await macroService.fetchEconomicEvents()
        self.economicEvents = events
        self.economicEvents = events
        await engine.updateEvents(events)
    }
    
    // Mission 38: Candle Aggregation Logic
    private func processTickIntoCandle(_ tick: MarketTick) {
        let calendar = Calendar.current
        // Round down to nearest minute
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: tick.timestamp)
        guard let candleTime = calendar.date(from: components) else { return }
        
        if var lastCandle = candles.last {
            if lastCandle.timestamp == candleTime {
                // Update existing candle
                lastCandle.high = max(lastCandle.high, tick.price)
                lastCandle.low = min(lastCandle.low, tick.price)
                lastCandle.close = tick.price
                lastCandle.volume += tick.volume
                candles[candles.count - 1] = lastCandle
            } else {
                // Start new candle
                let newCandle = Candle(timestamp: candleTime, open: tick.price, high: tick.price, low: tick.price, close: tick.price, volume: tick.volume)
                candles.append(newCandle)
            }
        } else {
            // First candle
            let newCandle = Candle(timestamp: candleTime, open: tick.price, high: tick.price, low: tick.price, close: tick.price, volume: tick.volume)
            candles.append(newCandle)
        }
        
        // Limit candles buffer
        if candles.count > 100 {
            candles.removeFirst()
        }
    }
}
