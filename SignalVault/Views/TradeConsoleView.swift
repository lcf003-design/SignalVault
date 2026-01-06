import SwiftUI
import SwiftData

struct TradeConsoleView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var accounts: [Account]
    @AppStorage("isRealisticSlippageEnabled") private var isRealisticSlippageEnabled = false
    
    // Observed from parent or VM
    var currentPrice: Double
    var activeSignal: TradeSignal?
    var selectedSymbol: String // Mission 11
    
    // Mission 36: VWAP Display
    var vwap: Double?
    var vwapDistance: Double?
    var isConsolidating: Bool = false // Mission 36.2
    
    // Mission 21: Smart Order Entry State
    enum OrderMode: String, CaseIterable {
        case shares = "Shares"
        case dollars = "Dollars"
    }
    
    @State private var orderMode: OrderMode = .shares
    @State private var inputAmount: Double?
    @FocusState private var isInputFocused: Bool
    
    var body: some View {
        VStack(spacing: 12) {
            
            // Mission 36: VWAP Status Line
            if let vwap = vwap, let dist = vwapDistance {
                HStack(spacing: 12) {
                    Text("VWAP: \(vwap, format: .currency(code: "USD"))")
                         .font(.caption2.monospaced())
                         .foregroundStyle(.cyan)
                    
                    // Show warning if extended > 3%
                    if abs(dist) > 0.03 {
                         HStack(spacing: 4) {
                             Image(systemName: "exclamationmark.triangle.fill")
                             Text("OVEREXTENDED: \(dist * 100, format: .number.precision(.fractionLength(1)))%")
                         }
                         .font(.caption2.bold())
                         .foregroundStyle(.orange)
                         // Pulse animation could be here
                    } else if isConsolidating {
                        // Mission 36.2: Consolidation Msg
                         Text("Awaiting ORB Breakout")
                            .font(.caption2.bold())
                            .foregroundStyle(.yellow)
                    } else {
                         Text("OSC: \(dist * 100, format: .number.precision(.fractionLength(2)))%")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.top, 4)
            }
            
            Divider()
            
            // 1. Order Entry Controls
            VStack(spacing: 12) {
                // Mode Toggle
                Picker("Order Mode", selection: $orderMode) {
                    ForEach(OrderMode.allCases, id: \.self) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                
                // Input & Quick Buttons
                HStack(spacing: 12) {
                    HStack {
                        Text(orderMode == .dollars ? "$" : "#")
                            .foregroundStyle(.secondary)
                        
                        TextField("Amount", value: $inputAmount, format: .number)
                            .keyboardType(.decimalPad)
                            .focused($isInputFocused)
                            .multilineTextAlignment(.trailing)
                    }
                    .padding(10)
                    .background(Color(uiColor: .secondarySystemBackground))
                    .cornerRadius(8)
                    
                    // Quick Size Buttons
                    if let account = accounts.first {
                        HStack(spacing: 4) {
                            Button("25%") { setQuickSize(percent: 0.25, account: account) }
                            Button("50%") { setQuickSize(percent: 0.50, account: account) }
                            Button("MAX") { setQuickSize(percent: 0.99, account: account) } // 99% to leave room for slippage
                        }
                        .buttonStyle(.bordered)
                        .font(.caption)
                    }
                }
                .padding(.horizontal)
                
                // Validation Feedback
                if let account = accounts.first, estimatedCost > account.currentBalance {
                    Text("Insufficient Buying Power (Avail: \(account.currentBalance, format: .currency(code: "USD")))")
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
            .padding(.top, 8)
            
            // 2. Status & Execution
            HStack {
                // Status Badge
                if let signal = activeSignal {
                    SignalBadge(signal: signal)
                } else if isConsolidating {
                    // Mission 36.2: Status
                    Text("CONSOLIDATING")
                        .font(.caption.bold())
                        .foregroundStyle(.yellow)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.yellow.opacity(0.1))
                        .clipShape(Capsule())
                } else {
                    Text("SCANNING \(selectedSymbol)...")
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
                        executeShadowTrade(accountID: account.id)
                        isInputFocused = false
                    }) {
                        HStack {
                            if let signal = activeSignal {
                                VStack(spacing: 2) {
                                    Text("\(signal.isBuy ? "BUY" : "SELL") \(selectedSymbol)")
                                        .fontWeight(.bold)
                                    
                                    // Dynamic Quantity Display
                                    if estimatedQuantity > 0 {
                                        Text("\(estimatedQuantity, format: .number.precision(.fractionLength(4))) Qty")
                                            .font(.caption2)
                                            .opacity(0.9)
                                    }
                                }
                            } else if isConsolidating {
                                Text("AWAITING BREAKOUT")
                                    .fontWeight(.bold)
                            } else {
                                Text("AWAITING SIGNAL...")
                                    .fontWeight(.bold)
                            }
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 10) // Slightly smaller vertical to fit extra text
                        .frame(maxWidth: .infinity)
                        .background(isTradeValid(account: account) ? buttonColor : Color.gray)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .disabled(!isTradeValid(account: account) || activeSignal == nil)
                    .opacity((!isTradeValid(account: account) || activeSignal == nil) ? 0.3 : 1.0)
                }
            }
            .padding(.horizontal)
            .padding(.bottom)
        }
        .background(Material.bar)
        .addKeyboardDoneButton()
        .hideKeyboardOnTap()
    }
    
    // Logic Helpers
    private var estimatedQuantity: Double {
        guard let amount = inputAmount, amount > 0 else { return 0 }
        if orderMode == .shares {
            return amount
        } else {
            return amount / currentPrice
        }
    }
    
    private var estimatedCost: Double {
        return estimatedQuantity * currentPrice
    }
    
    private func isTradeValid(account: Account) -> Bool {
        return estimatedQuantity > 0 && estimatedCost <= account.currentBalance
    }
    
    private func setQuickSize(percent: Double, account: Account) {
        let budget = account.currentBalance * percent
        orderMode = .dollars
        inputAmount = budget
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
        
        let qtyToExecute = estimatedQuantity
        
        Task {
            // Execute on background actor
            do {
                try await executor.executeTrade(
                    accountID: accountID,
                    symbol: selectedSymbol,
                    price: currentPrice,
                    quantity: qtyToExecute, // Dynamic Quantity
                    isLong: isLong,
                    stopLoss: stopLoss,
                    takeProfit: takeProfit,
                    slippage: isRealisticSlippageEnabled ? 0.0005 : 0.0 // 0.05% if enabled
                )
                
                await MainActor.run {
                    LiveActivityManager.shared.startMetricAttributes(symbol: selectedSymbol, entryPrice: currentPrice, isLong: isLong)
                    HapticManager.shared.playSuccess() // Enhanced haptic confirmation
                    // Reset Input after trade
                    // inputAmount = nil // Optional: keep it or clear it. Let's keep it for rapid fire.
                }
                
                print("✅ [UI] Trade Request Sent Successfully: \(qtyToExecute) Shares")
            } catch {
                print("❌ [UI] Trade Failed: \(error)")
            }
        }
    }
    
    private var buttonColor: Color {
        guard let signal = activeSignal else { return .gray }
        switch signal {
        case .strongBuy: return .green
        case .strongSell: return .red
        case .neutral: return .gray
        }
    }
}
