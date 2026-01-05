import SwiftUI
import Charts

struct SparklineGraph: View {
    let data: [Double]
    let color: Color
    
    var body: some View {
        Chart {
            ForEach(Array(data.enumerated()), id: \.offset) { index, price in
                LineMark(
                    x: .value("Index", index),
                    y: .value("Price", price)
                )
                .foregroundStyle(color)
                .interpolationMethod(.monotone)
                
                AreaMark(
                    x: .value("Index", index),
                    yStart: .value("Min", data.min() ?? 0),
                    yEnd: .value("Price", price)
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [color.opacity(0.3), .clear],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            }
        }
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .chartYScale(domain: .automatic(includesZero: false))
    }
}
