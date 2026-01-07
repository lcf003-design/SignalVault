import Foundation
import SwiftUI
import Observation

@MainActor
@Observable
class MarketChartViewModel {
    // Data Buffers
    var ticks: [MarketTick] = []
    var candles: [Candle] = [] // Mission 38
    var signals: [SignalEvent] = [] // Mission 39: Persistent History
    var volumeProfile: [VolumeProfileBar] = [] // Mission 40: VPVR
    private var rawVolumeBuckets: [Double: Double] = [:] // Aggregator
    
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
            if !Secrets.polygonAPIKey.isEmpty {
                self.marketService = MassiveMarketService()
                print("🚀 LIVE DATA ACTIVATED (Massive/Polygon)")
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
            self.signals.removeAll()
            self.volumeProfile.removeAll()
            self.rawVolumeBuckets.removeAll()
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
            
            // Mission 49/55 Fix: High-Frequency Data Throttling
            // We detach the stream consumption from MainActor to prevent UI freezing
            // when receiving massive amounts of ticks (100+ per sec).
            await consumeStreamOffMainThread(stream)
        }
    }
    
    // Non-isolated stream consumer
    nonisolated private func consumeStreamOffMainThread(_ stream: AsyncStream<MarketTick>) async {
        var tickBuffer: [MarketTick] = []
        var lastUpdate = Date()
        let throttleInterval: TimeInterval = 0.15 // 150ms throttle (approx 6-7 FPS)
        
        for await tick in stream {
            if Task.isCancelled { break }
            
            tickBuffer.append(tick)
            
            // Throttle Logic
            let now = Date()
            if now.timeIntervalSince(lastUpdate) >= throttleInterval || tickBuffer.count > 50 {
                let batch = tickBuffer
                tickBuffer.removeAll()
                lastUpdate = now
                
                // Flush to Main Actor
                await self.processBatch(batch)
            }
        }
    }
    
    // Main Actor Batch Processor
    private func processBatch(_ ticks: [MarketTick]) async {
        guard !ticks.isEmpty else { return }
        
        // 1. Process Signal Engine (Heavy) - Use the last tick for latest state,
        // but maybe process all for OHLC? For efficiency, we process last tick for signals.
        // For candles/volume, we iterate all.
        
        if let lastTick = ticks.last {
            // Update "Live" Price immediately
            self.currentPrice = lastTick.price
            
            // Update Buffers
            self.ticks.append(contentsOf: ticks)
            if self.ticks.count > maxPoints {
                self.ticks.removeFirst(self.ticks.count - maxPoints)
            }
        
            // Batch Process Candles & Volume
            for tick in ticks {
                self.processTickIntoCandle(tick)
                self.updateVolumeProfile(tick: tick)
            }
            
            // 2. Process Signal (Once per batch to save CPU)
            let context = await self.engine.process(tick: lastTick)
            
            // Update Cloud & Signals
            self.trendAlignment = context.alignment
            self.divergenceAlert = context.isDivergenceDetected
            
            self.vwap = context.vwap
            self.vwapDistance = context.vwapDistance
            self.openingRangeHigh = context.openingRangeHigh
            self.openingRangeLow = context.openingRangeLow
            self.yesterdayHigh = context.yesterdayHigh
            self.yesterdayLow = context.yesterdayLow
            self.isConsolidating = context.isConsolidating
            
            if let newSignal = context.tradeSignal {
                self.activeSignal = newSignal
                
                // Mission 39: History
                let event = SignalEvent(timestamp: lastTick.timestamp, type: newSignal, price: lastTick.price)
                self.signals.append(event)
                
                // Audio
                switch newSignal {
                case .strongBuy, .strongSell:
                    AudioService.shared.announceSignal(symbol: lastTick.symbol, price: lastTick.price, signal: newSignal)
                    if context.alignment == .bullish || context.alignment == .bearish {
                         AudioService.shared.playSniperSound()
                         HapticManager.shared.playImpact()
                    } else {
                        let generator = UINotificationFeedbackGenerator()
                        generator.notificationOccurred(.success)
                    }
                default: break
                }
                
                Task {
                    try? await Task.sleep(for: .seconds(3))
                    if self.activeSignal != nil { } // Auto-hide logic placeholder
                }
            }
            
            // 3. Oracle (Check occasionally)
            if self.ticks.count >= 30, Int.random(in: 0...5) == 0 { // 1 in 5 batches
               let recentPrices = self.ticks.suffix(50).map { $0.price }
               let result = await self.projectionEngine.calculateProjection(recentPrices: recentPrices)
               self.projection = result
               
               if let res = result, abs(res.currentDeviationSigma) > 2.5 {
                   self.chartAlert = "PRICE STRETCHED: \(String(format: "%.1f", res.currentDeviationSigma))σ"
               } else {
                   self.chartAlert = nil
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
    
    // Mission 40: Volume Profile Logic
    private func updateVolumeProfile(tick: MarketTick) {
        // Bin size: $1.00 (as requested)
        let bucket = floor(tick.price)
        
        // Accumulate volume
        rawVolumeBuckets[bucket, default: 0] += tick.volume
        
        // Update Published Array (Throttle this in production, but OK for MVP)
        // Find POC (Max Volume)
        let maxVol = rawVolumeBuckets.values.max() ?? 0
        
        self.volumeProfile = rawVolumeBuckets.map { (price, vol) in
            VolumeProfileBar(
                priceLevel: price,
                totalVolume: vol,
                isPOC: vol >= maxVol && maxVol > 0
            )
        }.sorted(by: { $0.priceLevel < $1.priceLevel })
    }
}
