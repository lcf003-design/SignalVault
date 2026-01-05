import SwiftUI

struct SentimentDashboardView: View {
    let sentiment: SentimentAnalysisResult
    @State private var animatePulse = false
    
    var body: some View {
        VStack(spacing: 16) {
            // Gauge Section
            HStack {
                VStack(alignment: .leading) {
                    Text("AI Sentiment")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                    
                    HStack(spacing: 4) {
                        Text(sentiment.label.uppercased())
                            .font(.headline.bold())
                            .foregroundStyle(scoreColor)
                        
                        // Score Value
                        Text("(\(String(format: "%.2f", sentiment.aggregateScore)))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                
                // Visual Pulse Gauge
                ZStack {
                    Circle()
                        .stroke(Color.gray.opacity(0.2), lineWidth: 6)
                        .frame(width: 44, height: 44)
                    
                    Circle()
                        .trim(from: 0, to: CGFloat(abs(sentiment.aggregateScore)))
                        .stroke(scoreColor, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .frame(width: 44, height: 44)
                    
                    // Pulse Ring
                    if abs(sentiment.aggregateScore) > 0.5 {
                        Circle()
                            .stroke(scoreColor.opacity(0.5), lineWidth: 2)
                            .frame(width: 60, height: 60)
                            .scaleEffect(animatePulse ? 1.2 : 1.0)
                            .opacity(animatePulse ? 0.0 : 0.5)
                            .onAppear {
                                withAnimation(.easeOut(duration: 1.5).repeatForever(autoreverses: false)) {
                                    animatePulse = true
                                }
                            }
                    }
                }
            }
            .padding(.horizontal)
            
            // Divergence Alert
            if sentiment.aggregateScore < -0.3 {
                 // Bearish Warning
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                    Text("Bearish Divergence")
                }
                .font(.caption.bold())
                .foregroundStyle(.white)
                .padding(8)
                .background(Capsule().fill(Color.orange))
            }
            
            // Ticker (Scroll)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(sentiment.headlines) { item in
                        NewsTickerItem(item: item)
                    }
                }
                .padding(.horizontal)
            }
        }
        .padding(.vertical)
        .background(Color(uiColor: .secondarySystemBackground))
        .cornerRadius(16)
    }
    
    var scoreColor: Color {
        if sentiment.aggregateScore > 0.3 { return .green }
        if sentiment.aggregateScore < -0.3 { return .red }
        return .gray
    }
}

struct NewsTickerItem: View {
    let item: NewsItem
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                // Source Badge
                Text(item.source.uppercased())
                    .font(.system(size: 9, weight: .bold))
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .background(Color.primary.opacity(0.1))
                    .cornerRadius(4)
                
                // Sentiment Dot
                Circle()
                    .fill(item.sentimentScore > 0 ? Color.green : (item.sentimentScore < 0 ? Color.red : Color.gray))
                    .frame(width: 8, height: 8)
            }
            
            Text(item.headline)
                .font(.caption)
                .lineLimit(2)
                .frame(width: 140, alignment: .leading)
                .multilineTextAlignment(.leading)
        }
        .padding(8)
        .background(Color(uiColor: .systemBackground))
        .cornerRadius(8)
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
}
