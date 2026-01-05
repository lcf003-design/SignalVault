import SwiftUI
import SwiftData

struct TradeConsoleView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var accounts: [Account]
    
    // Observed from parent or VM
    var currentPrice: Double
    var activeSignal: TradeSignal?
    
    var body: some View {
        VStack {
            Divider()
            
            HStack {
                // Status Badge
                if let signal = activeSignal {
                    SignalBadge(signal: signal)
                } else {
                    Text("SCANNING...")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.secondary.opacity(0.1))
                        .clipShape(Capsule())
                }
                
                Spacer()
                
                // Action Button
                if let account = accounts.first {
                    Button(action: {
                        copyTradeToClipboard(currentPrice: currentPrice, symbol: "BTC") // Hardcoded symbol for now or passed
                    }) {
                        Image(systemName: "doc.on.doc")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                            .padding(10)
                            .background(Material.thin)
                            .clipShape(Circle())
                    }
                    .help("Copy Signal to Clipboard")
                    
                    Button(action: {
                        executeShadowTrade(accountID: account.id)
                    }) {
                        Text("PLACE SHADOW TRADE")
                            .font(.headline)
                            .foregroundStyle(.black)
                            .padding(.horizontal)
                            .padding(.vertical, 12)
                            .background(Color.primary)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .disabled(activeSignal == nil)
                    .opacity(activeSignal == nil ? 0.5 : 1.0)
                }
            }
            .padding()
            .background(Material.bar)
        }
    }
    
    private func copyTradeToClipboard(currentPrice: Double, symbol: String) {
        // Format: BUY 1.0 BTC @ $96,500.00 | SL: $95,000 | TP: $98,000
        // We'll calculate mock SL/TP for the clipboard based on signal
        var isLong = false
        if case .strongBuy = activeSignal { isLong = true }
        
        let sl = isLong ? currentPrice * 0.98 : currentPrice * 1.02
        let tp = isLong ? currentPrice * 1.03 : currentPrice * 0.97
        let dir = isLong ? "BUY" : "SELL"
        
        let string = String(format: "%@ 1.0 %@ @ $%.2f | SL: $%.2f | TP: $%.2f", dir, symbol, currentPrice, sl, tp)
        UIPasteboard.general.string = string
        
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }
    
    private func executeShadowTrade(accountID: UUID) {
        // Haptic Feedback
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        
        let isLong: Bool
        if case .strongBuy = activeSignal { isLong = true }
        else { isLong = false } // Simplified for MVP
        
        // Auto-Set Risk for Sandbox (Simulated Smart Risk)
        // 2% Risk, 3% Reward
        let stopLoss = isLong ? currentPrice * 0.98 : currentPrice * 1.02
        let takeProfit = isLong ? currentPrice * 1.03 : currentPrice * 0.97
        
        // Create Executor with the container from the current context
        let container = modelContext.container
        let executor = TradeExecutor(modelContainer: container)
        
        Task {
            // Execute on background actor
            do {
                try await executor.executeTrade(
                    accountID: accountID,
                    symbol: "BTC",
                    price: currentPrice,
                    quantity: 1.0, // Fixed size for MVP
                    isLong: isLong,
                    stopLoss: stopLoss,
                    takeProfit: takeProfit,
                    slippage: 0.0005 // 0.05% Slippage
                )
                
                await MainActor.run {
                    LiveActivityManager.shared.startMetricAttributes(symbol: "BTC", entryPrice: currentPrice, isLong: isLong)
                    HapticManager.shared.playSuccess() // Enhanced haptic confirmation
                }
                
                print("✅ [UI] Trade Request Sent Successfully")
            } catch {
                print("❌ [UI] Trade Failed: \(error)")
            }
        }
    }
}
