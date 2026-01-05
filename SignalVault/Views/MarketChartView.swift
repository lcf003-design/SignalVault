import SwiftUI
import Charts

struct MarketChartView: View {
    @Bindable var viewModel: MarketChartViewModel
    
    @State private var flashColor: Color?
    
    var body: some View {
        VStack {
            // Header
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
                }
            }
            .padding(.horizontal)
            
            // Chart
            Chart {
                // Price Line
                ForEach(viewModel.ticks, id: \.timestamp) { tick in
                    LineMark(
                        x: .value("Time", tick.timestamp),
                        y: .value("Price", tick.price)
                    )
                    .foregroundStyle(.blue.gradient)
                    .interpolationMethod(.monotone)
                    // Mission 8: Glow Effect on Strong Buy
                    .shadow(color: (viewModel.activeSignal?.isBuy ?? false) ? .green : .clear, radius: 10)
                }
                
                // Mission 13: Oracle Cone (Predictive)
                if let projection = viewModel.projection, let lastDate = viewModel.ticks.last?.timestamp {
                    let interval: TimeInterval = 0.5 // Est. bar duration
                    
                    ForEach(projection.points) { point in
                        let futureDate = lastDate.addingTimeInterval(interval * Double(point.indexOffset))
                        
                        // 2SD Cone (95% Probability)
                        AreaMark(
                            x: .value("Time", futureDate),
                            yStart: .value("Lower 2SD", point.lower2SD),
                            yEnd: .value("Upper 2SD", point.upper2SD)
                        )
                        .foregroundStyle(projection.isReliable ? .blue.opacity(0.1) : .gray.opacity(0.1))
                        
                        // 1SD Cone (68% Probability)
                        AreaMark(
                            x: .value("Time", futureDate),
                            yStart: .value("Lower 1SD", point.lower1SD),
                            yEnd: .value("Upper 1SD", point.upper1SD)
                        )
                        .foregroundStyle(projection.isReliable ? .blue.opacity(0.2) : .gray.opacity(0.2))
                        
                        // Projected Path
                        LineMark(
                            x: .value("Time", futureDate),
                            y: .value("Projected", point.price)
                        )
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                        .foregroundStyle(.white.opacity(0.5))
                    }
                }
                
                // Mission 13: Price Stretched Alert
                if let alert = viewModel.chartAlert {
                    RuleMark(y: .value("Alert", viewModel.currentPrice))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [2]))
                        .foregroundStyle(.red)
                        .annotation(position: .top) {
                            Text(alert) // e.g. "PRICE STRETCHED: 3.1σ"
                                .font(.caption.bold())
                                .foregroundStyle(.white)
                                .padding(6)
                                .background(Color.red.gradient)
                                .cornerRadius(8)
                                .shadow(radius: 2)
                        }
                }
                
                // Mission 8: Flash Alert Overlay
                if let signal = viewModel.activeSignal {
                     RuleMark(y: .value("Flash", 0)) // Hidden Anchor
                         .annotation(position: .overlay) {
                             RoundedRectangle(cornerRadius: 0)
                                 .strokeBorder(signal.color, lineWidth: flashColor != nil ? 4 : 0)
                                 .ignoresSafeArea()
                                 .opacity(flashColor != nil ? 1.0 : 0.0)
                                 .animation(.easeInOut(duration: 0.2), value: flashColor)
                         }
                }
                
                // Signal Annotations
                ForEach(viewModel.signals, id: \.self) { signal in
                    if case .strongBuy(_, let price) = signal {
                        PointMark(
                            x: .value("Time", Date()), // Warning: Needs real timestamp in signal
                            y: .value("Price", price)
                        )
                        .symbol {
                            Image(systemName: "arrowtriangle.up.fill")
                                .foregroundStyle(.green)
                        }
                    }
                    if case .strongSell(_, let price) = signal {
                         PointMark(
                             x: .value("Time", Date()), // Placeholder
                             y: .value("Price", price)
                         )
                         .symbol {
                             Image(systemName: "arrowtriangle.down.fill")
                                 .foregroundStyle(.red)
                         }
                    }
                }
                
                // Scrubbing RuleMark
                if let selectedDate = viewModel.selectedDate, let selectedPrice = viewModel.selectedPrice {
                    RuleMark(x: .value("Selected", selectedDate))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 5]))
                        .foregroundStyle(.secondary)
                    
                    PointMark(
                        x: .value("Selected", selectedDate),
                        y: .value("Price", selectedPrice)
                    )
                    .foregroundStyle(.white)
                }
            }
            .chartYScale(domain: .automatic(includesZero: false))
            .chartOverlay { proxy in
                GeometryReader { geometry in
                    Rectangle().fill(.clear).contentShape(Rectangle())
                        .gesture(
                            DragGesture()
                                .onChanged { value in
                                    let x = value.location.x
                                    if let date: Date = proxy.value(atX: x) {
                                        viewModel.selectedDate = date
                                        // Find closest price
                                        if let closest = viewModel.ticks.min(by: { abs($0.timestamp.timeIntervalSince(date)) < abs($1.timestamp.timeIntervalSince(date)) }) {
                                            viewModel.selectedPrice = closest.price
                                        }
                                    }
                                }
                                .onEnded { _ in
                                    viewModel.selectedDate = nil
                                    viewModel.selectedPrice = nil
                                }
                        )
                }
            }
            .frame(height: 250)
            .onAppear {
                viewModel.start()
            }
            .onChange(of: viewModel.activeSignal) { oldSignal, newSignal in
                if let new = newSignal, new != oldSignal {
                    triggerFlash(signal: new)
                }
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
}

// Helper Extension
extension TradeSignal {
    var isBuy: Bool {
        if case .strongBuy = self { return true }
        return false
    }
    
    var color: Color {
        switch self {
        case .strongBuy: return .green
        case .strongSell: return .red
        case .neutral: return .clear
        }
    }
}

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
