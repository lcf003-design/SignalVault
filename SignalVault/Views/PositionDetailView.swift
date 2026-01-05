import SwiftUI
import SwiftData

struct PositionDetailView: View {
    @Bindable var position: Position
    @State private var chartViewModel = MarketChartViewModel()
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    // Alert State
    @State private var showConfirmation = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // 1. Header Metrics
                    VStack(spacing: 8) {
                        Text(position.symbol)
                            .font(.system(size: 40, weight: .black, design: .rounded))
                            .foregroundStyle(.primary)
                        
                        HStack(spacing: 16) {
                            MetricPill(label: "SIZE", value: "\(position.quantity.formatted())")
                            MetricPill(label: "ENTRY", value: position.entryPrice.formatted(.currency(code: "USD")))
                        }
                    }
                    .padding(.top)
                    
                    // 2. Real-Time P&L Pulse
                    VStack {
                        Text("UNREALIZED P&L")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundStyle(.secondary)
                            .tracking(2)
                        
                        Text(currentPnL, format: .currency(code: "USD"))
                            .font(.system(size: 48, weight: .medium, design: .rounded))
                            .foregroundStyle(currentPnL >= 0 ? .green : .red)
                            .animation(.snappy, value: currentPnL) // Pulse effect
                    }
                    
                    // 3. The Chart
                    // Reuse MarketChartView with our local VM
                    MarketChartView(viewModel: chartViewModel)
                        .frame(height: 300)
                        .padding(.horizontal)
                    
                    // 4. Action Deck
                    Spacer()
                        .frame(height: 20)
                    
                    Button(action: {
                        showConfirmation = true
                    }) {
                        Text("CLOSE POSITION")
                            .font(.title3.bold())
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.red.gradient)
                            .cornerRadius(16)
                            .shadow(color: .red.opacity(0.4), radius: 10, y: 5)
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(.white.opacity(0.2), lineWidth: 1)
                            )
                    }
                    .padding(.horizontal)
                    .confirmationDialog("Are you sure?", isPresented: $showConfirmation, titleVisibility: .visible) {
                        Button("Confirm Liquidation", role: .destructive) {
                            executeLiquidation()
                        }
                        Button("Cancel", role: .cancel) {}
                    } message: {
                        Text("This will immediately sell \(position.quantity) units of \(position.symbol) at Market Price.")
                    }
                }
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("Position Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .onAppear {
                // Initialize Chart for this specific symbol
                chartViewModel.changeSymbol(to: position.symbol)
                chartViewModel.start()
            }
            .onDisappear {
                chartViewModel.stop()
            }
        }
    }
    
    // Real-Time P&L Calculation using the Detail VM's Price
    private var currentPnL: Double {
        let current = chartViewModel.currentPrice
        // Avoid flash of 0 PnL at start if price hasn't loaded
        if current == 0 { return 0 }
        
        let diff = position.isLong ? (current - position.entryPrice) : (position.entryPrice - current)
        return diff * position.quantity
    }
    
    private func executeLiquidation() {
        let generator = UIImpactFeedbackGenerator(style: .heavy)
        generator.impactOccurred()
        
        Task {
            let container = modelContext.container
            let executor = TradeExecutor(modelContainer: container)
            
            do {
                // Use the price from our local VM for best accuracy
                try await executor.closePosition(
                    positionID: position.id,
                    price: chartViewModel.currentPrice > 0 ? chartViewModel.currentPrice : position.entryPrice,
                    reason: "Manual Detail Close"
                )
                
                await MainActor.run {
                    dismiss()
                }
            } catch {
                print("Failed to close position: \(error)")
            }
        }
    }
}

struct MetricPill: View {
    let label: String
    let value: String
    
    var body: some View {
        VStack(spacing: 2) {
            Text(label)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline.bold())
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color(uiColor: .secondarySystemBackground))
        .cornerRadius(8)
    }
}
