import SwiftUI
import Charts

struct MarketChartLayers {
    
    // MARK: - Price Action
    @ChartContentBuilder
    static func priceLineLayer(candles: [Candle], wickWidth: CGFloat = 2.0, candleWidth: CGFloat = 6.0) -> some ChartContent {
        ForEach(candles) { candle in
            // Wick
            RectangleMark(
                x: .value("Time", candle.timestamp),
                yStart: .value("Low", candle.low),
                yEnd: .value("High", candle.high),
                width: .fixed(wickWidth)
            )
            .foregroundStyle(candle.isBullish ? .green : .red)
            
            // Body
            RectangleMark(
                x: .value("Time", candle.timestamp),
                yStart: .value("Open", candle.open),
                yEnd: .value("Close", candle.close),
                width: .fixed(candleWidth)
            )
            .foregroundStyle(candle.isBullish ? .green : .red)
        }
    }
    
    // MARK: - Oracle
    @ChartContentBuilder
    static func oracleConeLayer(projection: ProjectionResult?, lastDate: Date?, currentPrice: Double, alert: String?) -> some ChartContent {
        if let projection = projection, let lastDate = lastDate {
            let interval: TimeInterval = 0.5
            ForEach(projection.points) { point in
                let futureDate = lastDate.addingTimeInterval(interval * Double(point.indexOffset))
                AreaMark(x: .value("Time", futureDate), yStart: .value("Lower 2SD", point.lower2SD), yEnd: .value("Upper 2SD", point.upper2SD))
                    .foregroundStyle(projection.isReliable ? .blue.opacity(0.1) : .gray.opacity(0.1))
                AreaMark(x: .value("Time", futureDate), yStart: .value("Lower 1SD", point.lower1SD), yEnd: .value("Upper 1SD", point.upper1SD))
                    .foregroundStyle(projection.isReliable ? .blue.opacity(0.2) : .gray.opacity(0.2))
                LineMark(x: .value("Time", futureDate), y: .value("Projected", point.price))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4])).foregroundStyle(.white.opacity(0.5))
            }
        }
        if let alert = alert {
            RuleMark(y: .value("Alert", currentPrice))
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [2])).foregroundStyle(.red)
                .annotation(position: .top) {
                    Text(alert).font(.caption.bold()).foregroundStyle(.white).padding(6).background(Color.red.gradient).cornerRadius(8).shadow(radius: 2)
                }
        }
    }
    
    // MARK: - Institutional
    @ChartContentBuilder
    static func institutionalLevelsLayer(vwap: Double?, orbHigh: Double?, orbLow: Double?, startTime: Date?, yesterdayHigh: Double?, yesterdayLow: Double?) -> some ChartContent {
        if let vwap = vwap {
            RuleMark(y: .value("VWAP", vwap))
                .lineStyle(StrokeStyle(lineWidth: 2, dash: [5, 5])).foregroundStyle(.cyan.opacity(0.8))
                .annotation(position: .trailing, alignment: .center) {
                    Text("VWAP").font(.caption2.bold()).foregroundStyle(.cyan).padding(4).background(.ultraThinMaterial).cornerRadius(4)
                }
        }
        if let orbH = orbHigh, let orbL = orbLow {
            if let start = startTime {
                RectangleMark(xStart: .value("ORB Start", start), xEnd: .value("ORB End", start.addingTimeInterval(900)), yStart: .value("High", orbH), yEnd: .value("Low", orbL))
                    .foregroundStyle(.gray.opacity(0.1))
            }
            RuleMark(y: .value("ORB High", orbH)).lineStyle(StrokeStyle(lineWidth: 1, dash: [2])).foregroundStyle(.gray).annotation(position: .leading) { Text("ORB H").font(.caption2).foregroundStyle(.secondary) }
            RuleMark(y: .value("ORB Low", orbL)).lineStyle(StrokeStyle(lineWidth: 1, dash: [2])).foregroundStyle(.gray).annotation(position: .leading) { Text("ORB L").font(.caption2).foregroundStyle(.secondary) }
        }
        if let yh = yesterdayHigh {
            RuleMark(y: .value("YH", yh)).lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4])).foregroundStyle(.white.opacity(0.6)).annotation(position: .trailing) { Text("YH").font(.caption2).foregroundStyle(.secondary) }
        }
        if let yl = yesterdayLow {
            RuleMark(y: .value("YL", yl)).lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4])).foregroundStyle(.white.opacity(0.6)).annotation(position: .trailing) { Text("YL").font(.caption2).foregroundStyle(.secondary) }
        }
    }
    
    // MARK: - Events
    @ChartContentBuilder
    static func eventMarkersLayer(events: [EconomicEvent]) -> some ChartContent {
        ForEach(events) { event in
            RuleMark(x: .value("Event", event.date))
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [2])).foregroundStyle(event.impact.color)
                .annotation(position: .top, alignment: .center) {
                    Text(event.title)
                        .font(.system(size: 7, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                        .background(event.impact.color.gradient)
                        .cornerRadius(4)
                        .shadow(radius: 1)
                }
        }
    }
    
    // MARK: - Signals
    @ChartContentBuilder
    static func signalsLayer(signals: [SignalEvent]) -> some ChartContent {
        ForEach(signals) { event in
            // Buy Signals (Up Arrow)
            if case .strongBuy = event.type {
                PointMark(
                    x: .value("Time", event.timestamp),
                    y: .value("Price", event.price * 0.9995)
                )
                .foregroundStyle(.clear)
                .annotation(position: .bottom) {
                    Image(systemName: "arrowtriangle.up.fill")
                        .foregroundStyle(.green)
                        .font(.title3)
                        .shadow(color: .green.opacity(0.5), radius: 2)
                }
            }
            // Sell Signals (Down Arrow)
            else if case .strongSell = event.type {
                PointMark(
                    x: .value("Time", event.timestamp),
                    y: .value("Price", event.price * 1.0005)
                )
                .foregroundStyle(.clear)
                .annotation(position: .top) {
                    Image(systemName: "arrowtriangle.down.fill")
                        .foregroundStyle(.red)
                        .font(.title3)
                        .shadow(color: .red.opacity(0.5), radius: 2)
                }
            }
        }
    }
}
    

