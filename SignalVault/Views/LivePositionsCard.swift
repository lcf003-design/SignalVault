import SwiftUI
import SwiftData

struct LivePositionsCard: View {
    @Query(sort: \Position.timestamp, order: .reverse) private var positions: [Position]
    var currentPrice: Double
    
    var body: some View {
        VStack(alignment: .leading) {
            Text("LIVE POSITIONS")
                .font(.caption)
                .foregroundStyle(.secondary)
                .tracking(1)
                .padding(.horizontal)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    if positions.isEmpty {
                        Text("No active positions")
                            .font(.callout)
                            .foregroundStyle(.tertiary)
                            .padding()
                    } else {
                        ForEach(positions) { position in
                            PositionReviewCard(position: position, currentPrice: currentPrice)
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
    }
}

struct PositionReviewCard: View {
    let position: Position
    let currentPrice: Double
    
    private var pnl: Double {
        if position.isLong {
            return (currentPrice - position.entryPrice) * position.quantity
        } else {
            return (position.entryPrice - currentPrice) * position.quantity
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(position.symbol)
                    .font(.headline)
                Spacer()
                Text(position.isLong ? "LONG" : "SHORT")
                    .font(.caption2.bold())
                    .foregroundStyle(position.isLong ? .green : .red)
                    .padding(4)
                    .background(position.isLong ? Color.green.opacity(0.1) : Color.red.opacity(0.1))
                    .cornerRadius(4)
            }
            
            HStack {
                Text(pnl, format: .currency(code: "USD"))
                    .font(.subheadline.bold())
                    .foregroundStyle(pnl >= 0 ? .green : .red)
                
                Spacer()
                
                Text(position.quantity.formatted() + " units")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .frame(width: 160)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(pnl >= 0 ? Color.green.opacity(0.3) : Color.red.opacity(0.3), lineWidth: 1)
        )
    }
}
