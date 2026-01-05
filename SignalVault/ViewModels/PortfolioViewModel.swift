import SwiftUI
import SwiftData
import Combine

struct AllocationSegment: Identifiable {
    let id = UUID()
    let sector: String
    let value: Double
    let color: Color
}

@MainActor
class PortfolioViewModel: ObservableObject {
    @Published var totalEquity: Double = 0.0
    @Published var totalPnL: Double = 0.0
    @Published var riskScore: Int = 0 // 0-100
    @Published var allocationData: [AllocationSegment] = []
    
    private var modelContext: ModelContext?
    
    init() {}
    
    func setContext(_ context: ModelContext) {
        self.modelContext = context
        calculateMetrics()
    }
    
    func calculateMetrics() {
        guard let context = modelContext else { return }
        
        let accountDescriptor = FetchDescriptor<Account>()
        // Filter for OPEN positions only
        let positionDescriptor = FetchDescriptor<Position>(predicate: #Predicate { $0.isOpen })
        
        do {
            let accounts = try context.fetch(accountDescriptor)
            let positions = try context.fetch(positionDescriptor)
            
            guard let account = accounts.first else { return }
            
            // 1. Calculate Totals
            let cash = account.currentBalance
            // Use entryPrice as reliable cost basis.
            // Note: Without live market connection here, we cannot calculate real-time Equity or Unrealized P&L.
            // Future Upgrade: Inject MarketService to fetch current quotes for held assets.
            let invested = positions.reduce(0.0) { $0 + ($1.quantity * $1.entryPrice) }
            
            let totalValue = cash + invested
            
            self.totalEquity = totalValue
            self.totalPnL = 0.0 // Placeholder until Live Price integration
            
            // 2. Allocation Logic
            var segments: [AllocationSegment] = []
            
            if cash > 0 {
                segments.append(AllocationSegment(sector: "Cash", value: cash, color: .green))
            }
            
            // Use AssetType if available, or fallback to Symbol check
            // SchemaV1.Position has 'assetType: AssetType'
            
            let cryptoValue = positions.filter { $0.assetType == .crypto }.reduce(0.0) { $0 + ($1.quantity * $1.entryPrice) }
            let stockValue = positions.filter { $0.assetType == .stock }.reduce(0.0) { $0 + ($1.quantity * $1.entryPrice) }
            let optionValue = positions.filter { $0.assetType == .option }.reduce(0.0) { $0 + ($1.quantity * $1.entryPrice) }
            
            if cryptoValue > 0 {
                segments.append(AllocationSegment(sector: "Crypto", value: cryptoValue, color: .orange))
            }
            
            if stockValue > 0 {
                segments.append(AllocationSegment(sector: "Equities", value: stockValue, color: .blue))
            }
             
            if optionValue > 0 {
                segments.append(AllocationSegment(sector: "Options", value: optionValue, color: .purple))
            }
            
            self.allocationData = segments
            
            // 3. Risk Score Logic (VaR Proxy)
            // 100% Cash = 0 Risk
            // 100% Crypto = 100 Risk
            // Mixed = Weighted Average
            
            if totalValue == 0 {
                self.riskScore = 0
            } else {
                let cashWeight = cash / totalValue
                let cryptoWeight = cryptoValue / totalValue
                let stockWeight = stockValue / totalValue
                let optionWeight = optionValue / totalValue
                
                // Weights: Cash(0), Equity(40), Crypto(90), Options(100)
                let score = (cashWeight * 0) + (stockWeight * 40) + (cryptoWeight * 90) + (optionWeight * 100)
                self.riskScore = Int(score)
            }
            
        } catch {
            print("Failed to fetch data for Portfolio: \(error)")
        }
    }
}
