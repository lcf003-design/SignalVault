import Foundation
import NaturalLanguage

actor SentimentService {
    
    // Mission 15: The Sentiment Brain
    // Uses Apple's Natural Language Framework to score text.
    
    // MARK: - Source Weighting
    // Bloomberg/Reuters get 3x impact.
    private let sourceWeights: [String: Double] = [
        "Bloomberg": 3.0,
        "Reuters": 3.0,
        "WSJ": 3.0,
        "CNBC": 2.0,
        "Yahoo Finance": 2.0,
        "Twitter": 0.5, // Low quality noise
        "Reddit": 0.8
    ]
    
    func fetchSentiment(for symbol: String) async -> SentimentAnalysisResult {
        // 1. Fetch Headlines (Mocking for Sandbox/Demo)
        let rawNews = generateMockNews(for: symbol)
        
        // 2. Analyze Each
        var analyzedItems: [NewsItem] = []
        var totalWeightedScore = 0.0
        var totalWeight = 0.0
        
        for item in rawNews {
            let score = analyzeText(item.headline)
            let weight = sourceWeights[item.source] ?? 1.0
            
            let newsItem = NewsItem(
                headline: item.headline,
                source: item.source,
                url: nil,
                timestamp: item.timestamp,
                sentimentScore: score
            )
            analyzedItems.append(newsItem)
            
            totalWeightedScore += (score * weight)
            totalWeight += weight
        }
        
        // 3. Aggregate
        let aggregate = totalWeight > 0 ? totalWeightedScore / totalWeight : 0.0
        
        // 4. Label
        let label: String
        if aggregate > 0.3 { label = "Bullish" }
        else if aggregate < -0.3 { label = "Bearish" }
        else { label = "Neutral" }
        
        return SentimentAnalysisResult(
            aggregateScore: aggregate,
            label: label,
            divergenceDetected: false, // Calculated later in context of technicals
            headlines: analyzedItems
        )
    }
    
    private func analyzeText(_ text: String) -> Double {
        let tagger = NLTagger(tagSchemes: [.sentimentScore])
        tagger.string = text
        
        let (sentiment, _) = tagger.tag(at: text.startIndex, unit: .paragraph, scheme: .sentimentScore)
        
        if let scoreStr = sentiment?.rawValue, let score = Double(scoreStr) {
            return score
        }
        return 0.0
    }
    
    // Mock Data Generator
    private func generateMockNews(for symbol: String) -> [(headline: String, source: String, timestamp: Date)] {
        // In a real app, use Polygon Ticker News API
        let now = Date()
        
        if symbol == "BTC" {
             return [
                ("Bitcoin breaks resistance at $96k, eyes $100k", "Bloomberg", now),
                ("Whale accumulation reaches all-time high", "Reuters", now.addingTimeInterval(-300)),
                ("Regulatory concerns linger over crypto markets", "CNBC", now.addingTimeInterval(-1200)),
                ("BTC to the moon!!! 🚀", "Twitter", now.addingTimeInterval(-60))
             ]
        } else if symbol == "AAPL" {
            return [
                ("Apple supply chain issues resolved, iPhone production up", "WSJ", now),
                ("Analysts upgrade AAPL price target to $250", "Yahoo Finance", now.addingTimeInterval(-600)),
                ("New headset reviews are mixed", "The Verge", now.addingTimeInterval(-3600))
            ]
        } else {
            // Random mix
            return [
                ("\(symbol) quarterly earnings beat expectations", "Bloomberg", now),
                ("Market volatility affects \(symbol) stock", "Reuters", now.addingTimeInterval(-900))
            ]
        }
    }
}
