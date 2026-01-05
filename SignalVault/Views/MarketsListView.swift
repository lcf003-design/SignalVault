import SwiftUI

struct MarketsListView: View {
    @Binding var selectedTab: Int
    @Binding var selectedSymbol: String
    
    // Mock Data Source for list
    let assets = [
        MarketAsset(symbol: "BTC", name: "Bitcoin", price: 96500.0, change: 2.4),
        MarketAsset(symbol: "ETH", name: "Ethereum", price: 3450.0, change: -1.2),
        MarketAsset(symbol: "SOL", name: "Solana", price: 145.0, change: 5.6),
        MarketAsset(symbol: "SPY", name: "S&P 500", price: 540.0, change: 0.5),
        MarketAsset(symbol: "NVDA", name: "NVIDIA", price: 125.0, change: 1.8),
        MarketAsset(symbol: "AAPL", name: "Apple", price: 210.0, change: -0.3)
    ]
    
    // Services
    private let marketService = MockMarketService() // Lightweight instance for sparklines
    private let engine = SignalEngine() // For signal dots
    
    var body: some View {
        NavigationStack {
            List(assets) { asset in
                Button(action: {
                    // Navigation Logic
                    selectedSymbol = asset.symbol
                    selectedTab = 0 // Switch to Trade Tab
                }) {
                    HStack {
                        // 1. Symbol & Name
                        VStack(alignment: .leading) {
                            HStack {
                                Text(asset.symbol)
                                    .font(.headline)
                                    .fontWeight(.bold)
                                
                                // Signal Dot (Mocked logic for demo)
                                if asset.change > 2.0 {
                                    Circle()
                                        .fill(Color.green)
                                        .frame(width: 8, height: 8)
                                } else if asset.change < -1.0 {
                                    Circle()
                                        .fill(Color.red)
                                        .frame(width: 8, height: 8)
                                }
                            }
                            
                            Text(asset.name)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        
                        // 2. Sparkline
                        SparklineGraph(
                            data: marketService.generateStaticHistory(symbol: asset.symbol),
                            color: asset.change >= 0 ? .green : .red
                        )
                        .frame(width: 80, height: 30)
                        .padding(.horizontal)
                        
                        Spacer()
                        
                        // 3. Price & Change
                        VStack(alignment: .trailing) {
                            Text(asset.price, format: .currency(code: "USD"))
                                .font(.subheadline)
                                .fontWeight(.medium)
                            
                            Text("\(asset.change > 0 ? "+" : "")\(String(format: "%.2f", asset.change))%")
                                .font(.caption)
                                .foregroundStyle(asset.change >= 0 ? .green : .red)
                                .padding(4)
                                .background(
                                    (asset.change >= 0 ? Color.green : Color.red).opacity(0.1)
                                )
                                .cornerRadius(4)
                        }
                    }
                    .padding(.vertical, 4)
                }
                .buttonStyle(.plain) // Remove default list button styling
            }
            .navigationTitle("Markets")
            .listStyle(.insetGrouped)
        }
    }
}

struct MarketAsset: Identifiable {
    let id = UUID()
    let symbol: String
    let name: String
    let price: Double
    let change: Double
}
