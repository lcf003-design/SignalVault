import SwiftUI

struct MarketsListView: View {
    @Binding var selectedTab: Int
    @Binding var selectedSymbol: String
    
    // Mission 33: Connected to the Scanner
    @StateObject private var scanner = MarketScannerService()
    
    var body: some View {
        NavigationStack {
            VStack {
                // Mission 35: Discovery Carousel
                VStack(alignment: .leading, spacing: 8) {
                    Text("Top AI Picks")
                        .font(.title3.bold())
                        .padding(.horizontal)
                    
                    DiscoveryCarousel(assets: scanner.assets.sorted { $0.kaiScore > $1.kaiScore })
                }
                .padding(.top)

                // Mission 35: Filter Chips
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
                        ForEach(Filter.allCases, id: \.self) { filter in
                            Button(action: { selectedFilter = filter }) {
                                Text(filter.rawValue)
                                    .font(.subheadline.bold())
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(selectedFilter == filter ? Color.blue : Color(uiColor: .secondarySystemBackground))
                                    .foregroundStyle(selectedFilter == filter ? .white : .primary)
                                    .clipShape(Capsule())
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical, 8)

                // The List (Filtered)
                List(filteredAssets) { asset in
                    Button(action: {
                        selectedSymbol = asset.symbol
                        selectedTab = 0
                    }) {
                        HStack {
                            // 1. Symbol & Signal Ring
                            ZStack {
                                Circle()
                                    .strokeBorder(Color.gray.opacity(0.2), lineWidth: 3)
                                    .frame(width: 44, height: 44)
                                
                                // Kai Score Ring
                                Circle()
                                    .trim(from: 0, to: Double(asset.kaiScore) / 100.0)
                                    .stroke(
                                        asset.signalColor,
                                        style: StrokeStyle(lineWidth: 3, lineCap: .round)
                                    )
                                    .rotationEffect(.degrees(-90))
                                    .frame(width: 44, height: 44)
                                    .shadow(color: asset.isGlowing ? (asset.signalType.isBuy ? .green : .red) : .clear, radius: 5)
                                
                                Text("\(asset.kaiScore)")
                                    .font(.caption.bold())
                                    .monospacedDigit()
                            }
                            
                            VStack(alignment: .leading) {
                                Text(asset.symbol)
                                    .font(.headline)
                                Text(asset.name)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            
                            Spacer()
                            
                            VStack(alignment: .trailing) {
                                Text(asset.price, format: .currency(code: "USD"))
                                    .fontWeight(.medium)
                                Text("\(asset.changePercent > 0 ? "+" : "")\(String(format: "%.2f", asset.changePercent))%")
                                    .font(.caption)
                                    .foregroundStyle(asset.changePercent >= 0 ? .green : .red)
                            }
                        }
                        .padding(.vertical, 4)
                        .contentShape(Rectangle()) // Hit testing
                    }
                    .buttonStyle(.plain)
                }
                .listStyle(.insetGrouped)
            }
            .navigationTitle("AI Market Pulse")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(scanner.status == .streaming ? Color.green : (scanner.status == .connecting ? Color.yellow : Color.red))
                            .frame(width: 6, height: 6)
                            .opacity(isBlinking ? 1 : 0.2)
                            .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: isBlinking)
                        
                        Text(statusText)
                            .font(.caption2.bold())
                            .foregroundStyle(.secondary)
                    }
                    .padding(4)
                    .background(statusColor.opacity(0.1))
                    .clipShape(Capsule())
                    .onTapGesture {
                        HapticManager.shared.playToggleHaptic()
                        scanner.stopScanning()
                        scanner.startScanning()
                    }
                    .onAppear {
                        isBlinking = true
                    }
                }
            }
            .onAppear {
                scanner.startScanning()
            }
            .onDisappear {
                scanner.stopScanning()
            }
        }
    }
    
    // Status Helpers
    private var statusText: String {
        switch scanner.status {
        case .streaming: return "LIVE"
        case .connecting: return "CONNECTING"
        case .offline: return "OFFLINE"
        case .disconnected: return "PAUSED"
        }
    }
    
    private var statusColor: Color {
        switch scanner.status {
        case .streaming: return .green
        case .connecting: return .yellow
        case .offline: return .red
        case .disconnected: return .gray
        }
    }
    
    // Mission 35: Filters
    @State private var selectedFilter: Filter = .all
    @State private var isBlinking = false
    
    enum Filter: String, CaseIterable {
        case all = "All Assets"
        case crypto = "Crypto"
        case stocks = "Stocks"
        case highVol = "High Vol"
    }
    
    var filteredAssets: [ScannedAsset] {
        switch selectedFilter {
        case .all: return scanner.assets
        case .crypto: return scanner.assets.filter { $0.assetType == .crypto }
        case .stocks: return scanner.assets.filter { $0.assetType == .stock }
        case .highVol: return scanner.assets.filter { $0.volumeStatus == .high || $0.volumeStatus == .ultra }
        }
    }
}
