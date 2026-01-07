import SwiftUI
import Charts

struct MarketChartView: View {
    @Bindable var viewModel: MarketChartViewModel
    var targetPosition: Position? // Mission 27: Visual Targets
    
    // Mission 28: Interactive State
    @State private var isChartLocked: Bool = true
    @State private var draggingTarget: DragTarget = .none
    @State private var tempTP: Double?
    @State private var tempSL: Double?
    @State private var lastHapticPrice: Double?
    
    enum DragTarget { case none, tp, sl }
    
    @State private var flashColor: Color?
    
    // Mission 34: Trend Cloud Colors
    private var cloudColor: Color {
        switch viewModel.trendAlignment {
        case .bullish: return .green.opacity(0.15)
        case .bearish: return .red.opacity(0.15)
        case .mixed: return .yellow.opacity(0.1)
        }
    }
    
    // Mission 38: Chart Scale
    private let candleWidth: CGFloat = 6.0
    private let wickWidth: CGFloat = 2.0
    
    var body: some View {
        VStack {
            // Header
            VStack {
                 // Mission 34: Divergence Alert Banner
                if viewModel.divergenceAlert {
                    HStack {
                         Image(systemName: "exclamationmark.triangle.fill")
                             .foregroundStyle(.yellow)
                        Text("BEARISH DIVERGENCE: Potential Reversal")
                            .font(.caption2.bold())
                            .foregroundStyle(.yellow)
                    }
                    .padding(4)
                    .background(Color.yellow.opacity(0.1))
                    .cornerRadius(4)
                }
                
                HStack(alignment: .lastTextBaseline) {
                    Text(viewModel.currentPrice, format: .currency(code: "USD"))
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                        .contentTransition(.numericText())
                    
                    if let tick = viewModel.ticks.last {
                       Text(tick.timestamp, style: .time)
                            .foregroundStyle(.secondary)
                            .font(.caption)
                    }
                    
                    Spacer()
                    
                    if let signal = viewModel.activeSignal {
                        SignalBadge(signal: signal)
                    } else {
                        // Show Trend Status if no active signal
                        Text(viewModel.trendAlignment.rawValue.uppercased())
                            .font(.caption2.bold())
                            .foregroundStyle(viewModel.trendAlignment.color)
                    }
                }
            }
            .padding(.horizontal)
            .padding(.top, 4)
            .background(cloudColor.blur(radius: 20)) // Subtle background glow (Trend Cloud)

            
            // Chart Layout
            HStack(spacing: 0) {
                // Main Price Chart
                Chart {
                    MarketChartLayers.priceLineLayer(candles: viewModel.candles, wickWidth: wickWidth, candleWidth: candleWidth)
                    
                    targetMarkersLayer()
                    
                    MarketChartLayers.oracleConeLayer(
                        projection: viewModel.projection,
                        lastDate: viewModel.ticks.last?.timestamp,
                        currentPrice: viewModel.currentPrice,
                        alert: viewModel.chartAlert
                    )
                    
                    MarketChartLayers.institutionalLevelsLayer(
                        vwap: viewModel.vwap,
                        orbHigh: viewModel.openingRangeHigh,
                        orbLow: viewModel.openingRangeLow,
                        startTime: viewModel.ticks.first?.timestamp,
                        yesterdayHigh: viewModel.yesterdayHigh,
                        yesterdayLow: viewModel.yesterdayLow
                    )
                    
                    MarketChartLayers.eventMarkersLayer(events: viewModel.economicEvents)
                    
                    flashOverlayLayer()
                    
                    MarketChartLayers.signalsLayer(signals: viewModel.signals)
                    
                    scrubbingLayer()
                }
                // Mission 27: Adaptive Y-Scale for Targets
                .chartYScale(domain: calculateYDomain())
                .chartOverlay { proxy in
                    GeometryReader { geometry in
                        ZStack(alignment: .topTrailing) {
                            // Mission 28: Safety Lock
                            if targetPosition != nil {
                                Button(action: {
                                    withAnimation { isChartLocked.toggle() }
                                    if isChartLocked {
                                        // Reset any active drag state
                                        draggingTarget = .none
                                    } else {
                                        let generator = UIImpactFeedbackGenerator(style: .medium)
                                        generator.impactOccurred()
                                    }
                                }) {
                                    Image(systemName: isChartLocked ? "lock.fill" : "lock.open.fill")
                                        .font(.title3)
                                        .foregroundStyle(isChartLocked ? .secondary : .primary)
                                        .padding(8)
                                        .background(.ultraThinMaterial)
                                        .clipShape(Circle())
                                }
                                .padding(8)
                            }
                            
                            // Hit Test Layer
                            Rectangle().fill(.clear).contentShape(Rectangle())
                                .gesture(
                                    DragGesture()
                                        .onChanged { value in
                                            let y = value.location.y
                                            let x = value.location.x
                                            
                                            // 1. Identify Drag Target (Hit Testing)
                                            if !isChartLocked, let position = targetPosition, draggingTarget == .none {
                                                if let priceAtTouch: Double = proxy.value(atY: y) {
                                                    // Tolerance: 2% of Price
                                                    let tolerance = priceAtTouch * 0.02
                                                    
                                                    if let tp = position.takeProfitPrice, abs(priceAtTouch - tp) < tolerance {
                                                        draggingTarget = .tp
                                                        tempTP = tp
                                                        HapticManager.shared.playImpact()
                                                    } else if let sl = position.stopLossPrice, abs(priceAtTouch - sl) < tolerance {
                                                        draggingTarget = .sl
                                                        tempSL = sl
                                                        HapticManager.shared.playImpact()
                                                    }
                                                }
                                            }
                                            
                                            // 2. Handle Dragging
                                            if let price: Double = proxy.value(atY: y) {
                                                if draggingTarget == .tp {
                                                    tempTP = snapPrice(price)
                                                    // Haptic Notch
                                                    if let last = lastHapticPrice, abs(price - last) > (price * 0.001) {
                                                        let generator = UIImpactFeedbackGenerator(style: .light)
                                                        generator.impactOccurred(intensity: 0.5)
                                                        lastHapticPrice = price
                                                    } else if lastHapticPrice == nil {
                                                        lastHapticPrice = price
                                                    }
                                                } else if draggingTarget == .sl {
                                                    tempSL = snapPrice(price)
                                                    if let last = lastHapticPrice, abs(price - last) > (price * 0.001) {
                                                        let generator = UIImpactFeedbackGenerator(style: .light)
                                                        generator.impactOccurred(intensity: 0.5)
                                                        lastHapticPrice = price
                                                    } else if lastHapticPrice == nil {
                                                        lastHapticPrice = price
                                                    }
                                                } else {
                                                    // Normal Scrubbing Behavior (if locked or no target hit)
                                                    if isChartLocked {
                                                        if let date: Date = proxy.value(atX: x) {
                                                            viewModel.selectedDate = date
                                                            if let closest = viewModel.ticks.min(by: { abs($0.timestamp.timeIntervalSince(date)) < abs($1.timestamp.timeIntervalSince(date)) }) {
                                                                viewModel.selectedPrice = closest.price
                                                            }
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                        .onEnded { _ in
                                            // Commit Changes
                                            if draggingTarget == .tp, let newTP = tempTP, let position = targetPosition {
                                                position.takeProfitPrice = newTP
                                                HapticManager.shared.playSignalHaptic(type: .neutral(confidence: 1.0)) // Confirmation Thud
                                            } else if draggingTarget == .sl, let newSL = tempSL, let position = targetPosition {
                                                position.stopLossPrice = newSL
                                                HapticManager.shared.playSignalHaptic(type: .neutral(confidence: 1.0))
                                            }
                                            
                                            // Reset State
                                            draggingTarget = .none
                                            tempTP = nil
                                            tempSL = nil
                                            lastHapticPrice = nil
                                            viewModel.selectedDate = nil
                                            viewModel.selectedPrice = nil
                                        }
                                )
                        }
                    }
                }
                
                // Mission 40: Volume Profile (VPVR) Sidebar
                if !viewModel.volumeProfile.isEmpty {
                    Chart {
                        ForEach(viewModel.volumeProfile) { bar in
                            RectangleMark(
                                xStart: .value("Vol", 0),
                                xEnd: .value("Vol", bar.totalVolume),
                                y: .value("Price", bar.priceLevel),
                                height: .fixed(4)
                            )
                            .foregroundStyle(bar.isPOC ? .yellow : .gray.opacity(0.3))
                        }
                    }
                    .frame(width: 60)
                    .chartYScale(domain: calculateYDomain()) // Sync Y-Axis
                    .chartXAxis(.hidden)
                    .chartYAxis(.hidden)
                }
            }
            .frame(height: 250)
            .onAppear {
                // Mission 17: User requested start in PAUSED state
                // viewModel.start()
            }
            .onChange(of: viewModel.activeSignal) { oldSignal, newSignal in
                if let new = newSignal, new != oldSignal {
                    triggerFlash(signal: new)
                }
            }
            // Mission 15: Sentiment Dashboard
            if let sentiment = viewModel.sentiment {
                SentimentDashboardView(sentiment: sentiment)
                    .padding(.horizontal)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
    }
    
    // Mission 8: Visual Flash Trigger
    private func triggerFlash(signal: TradeSignal) {
        // Haptic
        HapticManager.shared.playSignalHaptic(type: signal)
        
        // Color
        if case .strongBuy = signal { flashColor = .green }
        else if case .strongSell = signal { flashColor = .red }
        else { return }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            flashColor = nil
        }
    }
    
    // Mission 27: Adaptive Y-Scaling
    private func calculateYDomain() -> ClosedRange<Double> {
        // Start with current price tick range
        let prices = viewModel.ticks.map { $0.price }
        guard let minPrice = prices.min(), let maxPrice = prices.max() else {
             // Fallback if no ticks
            return 0...100
        }
        
        var lower = minPrice
        var upper = maxPrice
        
        // Include Target Position Levels
        if let position = targetPosition {
            lower = min(lower, position.entryPrice)
            upper = max(upper, position.entryPrice)
            
            if let sl = position.stopLossPrice {
                lower = min(lower, sl)
                upper = max(upper, sl)
            }
            
            if let tp = position.takeProfitPrice {
                lower = min(lower, tp)
                upper = max(upper, tp)
            }
        }
        
        // Add 5% padding
        let range = upper - lower
        // Prevent flat line crash if range is 0
        let effectiveRange = range == 0 ? upper * 0.05 : range
        let padding = effectiveRange * 0.05
        
        return (lower - padding)...(upper + padding)
    }
    
    private func getSignalColor(_ signal: TradeSignal) -> Color {
        switch signal {
        case .strongBuy: return .green
        case .strongSell: return .red
        default: return .gray
        }
    }
    
    private func snapPrice(_ price: Double) -> Double {
         // Snap to 0.05
         return (price * 20).rounded() / 20
    }
    

    
    @ChartContentBuilder
    private func flashOverlayLayer() -> some ChartContent {
        if let signal = viewModel.activeSignal {
            RuleMark(y: .value("Flash", 0))
                .annotation(position: .overlay) {
                    RoundedRectangle(cornerRadius: 0)
                        .strokeBorder(getSignalColor(signal), lineWidth: flashColor != nil ? 4 : 0)
                        .ignoresSafeArea().opacity(flashColor != nil ? 1.0 : 0.0)
                        .animation(.easeInOut(duration: 0.2), value: flashColor)
                }
        }
    }
    
    // MARK: - State-Dependent Layers (Kept Local)
    @ChartContentBuilder
    private func targetMarkersLayer() -> some ChartContent {
        if let position = targetPosition {
            RuleMark(y: .value("Entry", position.entryPrice))
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [2]))
                .foregroundStyle(.white.opacity(0.8))
                .annotation(position: .leading) {
                    Text("ENTRY").font(.caption2.bold()).foregroundStyle(.white).padding(2).background(Color.gray.opacity(0.5)).cornerRadius(4)
                }
            
            if let tp = (draggingTarget == .tp ? tempTP : position.takeProfitPrice) {
                RuleMark(y: .value("TP", tp))
                    .lineStyle(StrokeStyle(lineWidth: draggingTarget == .tp ? 3 : 1, dash: draggingTarget == .tp ? [] : [4, 4]))
                    .foregroundStyle(.green)
                    .shadow(color: draggingTarget == .tp ? .green : .clear, radius: 10)
                    .annotation(position: .trailing) {
                        Text("TP: \(tp.formatted(.currency(code: "USD")))")
                            .font(.caption2.bold()).foregroundStyle(.green).scaleEffect(draggingTarget == .tp ? 1.2 : 1.0)
                    }
            }
            
            if let sl = (draggingTarget == .sl ? tempSL : position.stopLossPrice) {
                RuleMark(y: .value("SL", sl))
                    .lineStyle(StrokeStyle(lineWidth: draggingTarget == .sl ? 3 : 1, dash: draggingTarget == .sl ? [] : [4, 4]))
                    .foregroundStyle(.red)
                    .shadow(color: draggingTarget == .sl ? .red : .clear, radius: 10)
                    .annotation(position: .trailing) {
                        Text("SL: \(sl.formatted(.currency(code: "USD")))")
                            .font(.caption2.bold()).foregroundStyle(.red).scaleEffect(draggingTarget == .sl ? 1.2 : 1.0)
                    }
            }
        }
    }
    
    @ChartContentBuilder
    private func scrubbingLayer() -> some ChartContent {
        if let selectedDate = viewModel.selectedDate, let selectedPrice = viewModel.selectedPrice {
            RuleMark(x: .value("Selected", selectedDate)).lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 5])).foregroundStyle(.secondary)
            PointMark(x: .value("Selected", selectedDate), y: .value("Price", selectedPrice)).foregroundStyle(.white)
        }
    }
}

// Helper Extension
// Removed extension to prevent MainActor isolation leakage to Model
// extension TradeSignal { var color: Color ... }


struct SignalBadge: View {
    let signal: TradeSignal
    
    var body: some View {
        switch signal {
        case .strongBuy(let confidence, _):
            Text("STRONG BUY \(Int(confidence * 100))%")
                .font(.caption.bold())
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.green.opacity(0.2))
                .foregroundStyle(.green)
                .clipShape(Capsule())
        case .strongSell(let confidence, _):
             Text("STRONG SELL \(Int(confidence * 100))%")
                .font(.caption.bold())
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.red.opacity(0.2))
                .foregroundStyle(.red)
                .clipShape(Capsule())
        case .neutral:
            EmptyView()
        }
    }
}


