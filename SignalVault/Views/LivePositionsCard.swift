import SwiftUI
import SwiftData

struct LivePositionsCard: View {
    @Query(sort: \Position.timestamp, order: .reverse) private var positions: [Position]
    var currentPrice: Double
    
    @Environment(\.modelContext) private var modelContext
    @State private var selectedPosition: Position?
    
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
                                .contentShape(Rectangle()) // Standardize tap area
                                .onTapGesture {
                                    selectedPosition = position
                                }
                                .contextMenu {
                                    // 1. Details
                                    Button {
                                        selectedPosition = position
                                    } label: {
                                        Label("View Details", systemImage: "chart.bar")
                                    }
                                    
                                    // 2. Destructive Close
                                    Button(role: .destructive) {
                                        liquidatePosition(position)
                                    } label: {
                                        Label("Liquidate Position", systemImage: "trash")
                                    }
                                }
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
        .sheet(item: $selectedPosition) { position in
            PositionDetailView(position: position)
        }
    }
    
    private func liquidatePosition(_ position: Position) {
        // Haptic High-Stakes Feedback
        let generator = UIImpactFeedbackGenerator(style: .heavy)
        generator.impactOccurred()
        
        let container = modelContext.container
        let posID = position.id
        // Use approximate price from card if available, or just use current
        let closePrice = currentPrice 
        
        Task {
            let executor = TradeExecutor(modelContainer: container)
            
            do {
                try await executor.closePosition(
                    positionID: posID,
                    price: closePrice, 
                    reason: "Context Menu Close"
                )
                
                await MainActor.run {
                    // Success Haptic
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                    print("✅ LivePositions: Liquidated \(posID)")
                    // Note: SwiftData @Query should auto-update if the context saves.
                    // TradeExecutor handles the save.
                }
            } catch {
                await MainActor.run {
                    UINotificationFeedbackGenerator().notificationOccurred(.error)
                    print("❌ LivePositions: Failed to liquidate: \(error)")
                }
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
