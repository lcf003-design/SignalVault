import ActivityKit
import Foundation
import SwiftUI

// Attributes: Static data describing the activity
struct TradeActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        // Dynamic state to update
        var currentPrice: Double
        var pnl: Double
        var pnlPercent: Double
    }
    
    // Fixed attributes
    var symbol: String
    var entryPrice: Double
    var isLong: Bool
}

@MainActor
class LiveActivityManager {
    static let shared = LiveActivityManager()
    
    private var activity: Activity<TradeActivityAttributes>?
    
    func startMetricAttributes(symbol: String, entryPrice: Double, isLong: Bool) {
        // Guard against simulator if ActivityKit not supported (Simulator supports it now usually, but safe guard)
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
             print("⚠️ Live Activities not enabled or authorized.")
             return
        }
        
        let attributes = TradeActivityAttributes(symbol: symbol, entryPrice: entryPrice, isLong: isLong)
        let contentState = TradeActivityAttributes.ContentState(currentPrice: entryPrice, pnl: 0.0, pnlPercent: 0.0)
        
        do {
            let activity = try Activity.request(
                attributes: attributes,
                content: .init(state: contentState, staleDate: nil),
                pushType: nil // No remote push for now
            )
            self.activity = activity
            print("🚀 Live Activity Started: \(activity.id)")
        } catch {
            print("❌ Failed to start Live Activity: \(error)")
        }
    }
    
    func updateMetric(currentPrice: Double, entryPrice: Double, isLong: Bool, quantity: Double) {
        guard let activity = self.activity else { return }
        
        let pnl: Double
        if isLong {
            pnl = (currentPrice - entryPrice) * quantity
        } else {
            pnl = (entryPrice - currentPrice) * quantity
        }
        
        let pnlPercent = (pnl / (entryPrice * quantity)) * 100.0
        
        let updatedContentState = TradeActivityAttributes.ContentState(
            currentPrice: currentPrice,
            pnl: pnl,
            pnlPercent: pnlPercent
        )
        
        Task {
            await activity.update(
                ActivityContent(state: updatedContentState, staleDate: nil)
            )
        }
    }
    
    func endActivity() {
        guard let activity = self.activity else { return }
        Task {
            await activity.end(nil, dismissalPolicy: .immediate)
            self.activity = nil
            print("🛑 Live Activity Ended")
        }
    }
}
