import SwiftUI

struct DiscoveryCarousel: View {
    let assets: [ScannedAsset]
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 16) {
                ForEach(assets.prefix(5)) { asset in
                    DiscoveryCard(asset: asset)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
        .frame(height: 220) // Constraint to prevent RBLayer explosion
    }
}

struct DiscoveryCard: View {
    let asset: ScannedAsset
    @State private var pulse: Bool = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                VStack(alignment: .leading) {
                    Text(asset.symbol)
                        .font(.headline)
                        .fontWeight(.heavy)
                    Text(asset.name)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                // Kai Score Badge
                ZStack {
                    Circle()
                        .stroke(scoreColor.opacity(0.3), lineWidth: 4)
                        .frame(width: 44, height: 44)
                    
                    Circle()
                        .trim(from: 0, to: Double(asset.kaiScore) / 100.0)
                        .stroke(scoreColor, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .frame(width: 44, height: 44)
                    
                    Text("\(asset.kaiScore)")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                }
            }
            
            // AI Context
            Text(asset.aiSummary)
                .font(.caption)
                .lineLimit(3)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            Spacer()
            
            // Footer (Price & Vol Status)
            HStack {
                Text(asset.price.formatted(.currency(code: "USD")))
                    .font(.body.monospacedDigit())
                    .fontWeight(.bold)
                
                Spacer()
                
                if asset.volumeStatus == .ultra || asset.volumeStatus == .high {
                    HStack(spacing: 4) {
                        Image(systemName: "flame.fill")
                        Text(asset.volumeStatus.rawValue.uppercased())
                    }
                    .font(.caption2.bold())
                    .foregroundStyle(.orange)
                }
            }
        }
        .padding()
        .frame(width: 240, height: 180)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(uiColor: .secondarySystemBackground))
                .shadow(color: asset.isGlowing ? scoreColor.opacity(0.5) : .clear, radius: pulse ? 15 : 0)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(scoreColor.opacity(asset.isGlowing ? 0.8 : 0.0), lineWidth: 2)
        )
        .onAppear {
            if asset.isGlowing {
                withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                    pulse = true
                }
            }
        }
    }
    
    var scoreColor: Color {
        if asset.kaiScore >= 80 { return .green }
        if asset.kaiScore >= 50 { return .yellow }
        return .red
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        DiscoveryCarousel(assets: [
            ScannedAsset(
                symbol: "NVDA",
                name: "NVIDIA Corp",
                price: 145.20,
                changePercent: 2.5,
                kaiScore: 92,
                volumeStatus: .ultra,
                aiSummary: "NVDA is skyrocketing due to positive earnings sentiment and massive institutional volume flow.",
                assetType: .stock,
                convictionScore: 0.95,
                signalType: .strongBuy(confidence: 0.9, price: 145.0),
                isGlowing: true
            ),
            ScannedAsset(
                symbol: "BTC",
                name: "Bitcoin",
                price: 98500.0,
                changePercent: -1.2,
                kaiScore: 45,
                volumeStatus: .normal,
                aiSummary: "BTC is consolidating following a breakdown across timeframes.",
                assetType: .crypto,
                convictionScore: 0.4,
                signalType: .neutral(confidence: 0.5),
                isGlowing: false
            )
        ])
    }
    .preferredColorScheme(.dark)
}
